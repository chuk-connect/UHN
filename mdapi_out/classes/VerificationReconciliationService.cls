/**
 * VerificationReconciliationService
 * ----------------------------------
 * Encodes the reconciliation rule from the Business Hub Verification Framework.
 * Every verifiable object's trigger calls this. Not per-object logic.
 *
 * The rule, applied per-record:
 *   1. Hash matches stored hash                   -> no-op
 *   2. Hash differs, status = Proposed            -> silently update (PI not yet engaged)
 *   3. Hash differs, status = Verified            -> do NOT overwrite; emit change event
 *   4. Status = Manual, matching source appears   -> mark Manual as Superseded; create Proposed
 *   5. Every transition writes to Verification_Change_Event__c
 *
 * Override durability is enforced here. After a record reaches Verified,
 * source-system values flow into the change event log, never back into the record.
 *
 * Bulk-safe: all DML is collected and executed once per call. Designed to be
 * invoked from triggers handling up to 200-record batches.
 */
public with sharing class VerificationReconciliationService {

    // Status values stored on Verification_Status__c picklist.
    // Kept as constants so callers don't pass raw strings around.
    public static final String STATUS_PROPOSED   = 'Proposed';
    public static final String STATUS_VERIFIED   = 'Verified';
    public static final String STATUS_MANUAL     = 'Manual';
    public static final String STATUS_SUPERSEDED = 'Superseded';

    // Event types written to Verification_Change_Event__c.Event_Type__c.
    public static final String EVENT_PROPOSED_CREATED   = 'Proposed Created';
    public static final String EVENT_PROPOSED_UPDATED   = 'Proposed Updated';
    public static final String EVENT_VERIFIED           = 'Verified';
    public static final String EVENT_OVERRIDE_APPLIED   = 'Override Applied';
    public static final String EVENT_SOURCE_DRIFT       = 'Source Changed Under Verified';
    public static final String EVENT_MANUAL_CREATED     = 'Manual Created';
    public static final String EVENT_MANUAL_SUPERSEDED  = 'Manual Superseded';

    /**
     * Input DTO for an incoming source-system payload.
     *
     * The caller (typically an integration trigger or platform event handler)
     * builds one of these per inbound record. The service decides what to do
     * with each based on the matching record's current state.
     *
     * sourceFields is the canonical projection of the source record. Hash is
     * computed deterministically from this map — caller does NOT compute the
     * hash, so all callers stay consistent.
     */
    public class SourceUpsert {
        public Id existingRecordId;            // null if no match in Salesforce yet
        public SObjectType targetType;         // e.g. UHN_Publication_Author__c.SObjectType
        public String externalId;              // stable id from source system
        public Map<String, Object> sourceFields; // canonical projection from source

        public SourceUpsert(SObjectType targetType, String externalId, Map<String, Object> sourceFields) {
            this.targetType = targetType;
            this.externalId = externalId;
            this.sourceFields = sourceFields;
        }
    }

    /**
     * Per-record outcome from a reconcile() call. Useful for telemetry and
     * for trigger handlers that want to short-circuit downstream automation.
     */
    public class ReconcileResult {
        public Id recordId;
        public String action;          // matches one of the EVENT_* constants
        public Boolean changed;        // false on no-ops
    }

    /**
     * Main entry point. Bulk-safe.
     *
     * Strategy:
     *   - Query all matching existing records once (by externalId or recordId).
     *   - Walk the rule table in memory, building DML batches.
     *   - Execute one insert/update of records and one insert of events.
     *
     * On partial failure: throws. Caller is responsible for transaction
     * boundaries. We do not silently drop records — research integrity demands
     * loud failures.
     */
    public static List<ReconcileResult> reconcile(List<SourceUpsert> upserts) {
        if (upserts == null || upserts.isEmpty()) {
            return new List<ReconcileResult>();
        }

        // Group by SObjectType so we can issue typed queries. In practice
        // most callers will pass a single type; we don't assume that.
        Map<SObjectType, List<SourceUpsert>> byType = new Map<SObjectType, List<SourceUpsert>>();
        for (SourceUpsert u : upserts) {
            if (u.targetType == null) {
                throw new VerificationException('SourceUpsert.targetType is required');
            }
            if (!byType.containsKey(u.targetType)) {
                byType.put(u.targetType, new List<SourceUpsert>());
            }
            byType.get(u.targetType).add(u);
        }

        List<ReconcileResult> results = new List<ReconcileResult>();
        List<SObject> recordsToUpsert = new List<SObject>();
        List<Verification_Change_Event__c> eventsToInsert = new List<Verification_Change_Event__c>();

        for (SObjectType t : byType.keySet()) {
            processType(t, byType.get(t), results, recordsToUpsert, eventsToInsert);
        }

        // Updates must run before inserts. Rule 4 sets External_Id__c = null on the
        // superseded record and then inserts a fresh record claiming that same value.
        // A single upsert batch evaluates the unique constraint across all rows before
        // committing any of them, so the "release" and the "claim" collide. Executing
        // the update first commits the null, freeing the slot before the insert runs.
        if (!recordsToUpsert.isEmpty()) {
            List<SObject> toUpdate = new List<SObject>();
            List<SObject> toInsert = new List<SObject>();
            for (SObject so : recordsToUpsert) {
                if (so.Id != null) toUpdate.add(so);
                else toInsert.add(so);
            }
            if (!toUpdate.isEmpty()) update toUpdate;
            if (!toInsert.isEmpty()) insert toInsert;
        }
        if (!eventsToInsert.isEmpty()) {
            insert eventsToInsert;
        }

        return results;
    }

    // ---------- internals ----------

    private static void processType(
        SObjectType targetType,
        List<SourceUpsert> upserts,
        List<ReconcileResult> results,
        List<SObject> recordsToUpsert,
        List<Verification_Change_Event__c> eventsToInsert
    ) {
        // Resolve current state for every external id we're about to act on.
        // Callers can pass existingRecordId to skip the lookup; otherwise we
        // query by external id. Both paths converge into existingByExternalId.
        Set<String> externalIds = new Set<String>();
        Set<Id> recordIds = new Set<Id>();
        for (SourceUpsert u : upserts) {
            if (u.existingRecordId != null) recordIds.add(u.existingRecordId);
            if (String.isNotBlank(u.externalId)) externalIds.add(u.externalId);
        }

        Map<String, SObject> existingByExternalId = queryExisting(targetType, externalIds, recordIds);

        for (SourceUpsert u : upserts) {
            SObject existing = (u.existingRecordId != null && existingByExternalId.containsKey(String.valueOf(u.existingRecordId)))
                ? existingByExternalId.get(String.valueOf(u.existingRecordId))
                : existingByExternalId.get(u.externalId);

            ReconcileResult r = applyRule(targetType, u, existing, recordsToUpsert, eventsToInsert);
            results.add(r);
        }
    }

    /**
     * The rule engine itself. Reads the existing record's state, decides the
     * action, mutates the record-to-upsert and the change event in place.
     */
    private static ReconcileResult applyRule(
        SObjectType targetType,
        SourceUpsert u,
        SObject existing,
        List<SObject> recordsToUpsert,
        List<Verification_Change_Event__c> eventsToInsert
    ) {
        ReconcileResult r = new ReconcileResult();
        String incomingHash = computeHash(u.sourceFields);
        String sourcePayload = JSON.serialize(u.sourceFields);

        // Case A: no existing record. Create as Proposed.
        if (existing == null) {
            SObject fresh = targetType.newSObject();
            // Caller is responsible for any required fields beyond verification metadata
            // — they pass them in sourceFields and we copy them through.
            applySourceFieldsToRecord(fresh, u.sourceFields);
            fresh.put('External_Id__c', u.externalId);
            fresh.put('Verification_Status__c', STATUS_PROPOSED);
            fresh.put('Source_Hash__c', incomingHash);
            fresh.put('Source_Payload__c', sourcePayload);

            recordsToUpsert.add(fresh);
            eventsToInsert.add(buildEvent(null, u.externalId, EVENT_PROPOSED_CREATED, null, sourcePayload));
            r.action = EVENT_PROPOSED_CREATED;
            r.changed = true;
            return r;
        }

        r.recordId = existing.Id;
        String existingStatus = (String) existing.get('Verification_Status__c');
        String existingHash   = (String) existing.get('Source_Hash__c');

        // Case 1: hash matches. No-op.
        if (incomingHash == existingHash) {
            r.action = 'No-op';
            r.changed = false;
            return r;
        }

        // Case 4: existing is Manual and a matching source record now exists.
        // Supersede the manual entry and create a fresh Proposed alongside it.
        // The PI gets to decide whether to merge — we do not auto-merge.
        if (STATUS_MANUAL.equals(existingStatus)) {
            existing.put('Verification_Status__c', STATUS_SUPERSEDED);
            existing.put('External_Id__c', null);  // relinquish unique external ID to the incoming Proposed record
            recordsToUpsert.add(existing);

            SObject fresh = targetType.newSObject();
            applySourceFieldsToRecord(fresh, u.sourceFields);
            fresh.put('External_Id__c', u.externalId);
            fresh.put('Verification_Status__c', STATUS_PROPOSED);
            fresh.put('Source_Hash__c', incomingHash);
            fresh.put('Source_Payload__c', sourcePayload);
            // Preserve relationships from the superseded manual record so any
            // org-specific required lookups (e.g. UHN_Contact__c on a junction
            // object) are carried over to the new Proposed twin. The source
            // system has no way to know about these — they're a schema
            // property of the target org, not of the upstream feed.
            copyLookupFields(existing, fresh);
            recordsToUpsert.add(fresh);

            eventsToInsert.add(buildEvent(existing.Id, u.externalId, EVENT_MANUAL_SUPERSEDED, null, sourcePayload));
            r.action = EVENT_MANUAL_SUPERSEDED;
            r.changed = true;
            return r;
        }

        // Case 3: hash differs, record is Verified.
        // This is the critical one: do NOT mutate the record. Emit drift event.
        if (STATUS_VERIFIED.equals(existingStatus)) {
            eventsToInsert.add(buildEvent(
                existing.Id,
                u.externalId,
                EVENT_SOURCE_DRIFT,
                (String) existing.get('Source_Payload__c'),
                sourcePayload
            ));
            r.action = EVENT_SOURCE_DRIFT;
            r.changed = false;  // record itself unchanged — this is the whole point
            return r;
        }

        // Case 2: hash differs, status is Proposed (or Superseded — treat the same).
        // PI hasn't engaged. Safe to overwrite.
        applySourceFieldsToRecord(existing, u.sourceFields);
        existing.put('Source_Hash__c', incomingHash);
        existing.put('Source_Payload__c', sourcePayload);
        recordsToUpsert.add(existing);
        eventsToInsert.add(buildEvent(existing.Id, u.externalId, EVENT_PROPOSED_UPDATED, null, sourcePayload));
        r.action = EVENT_PROPOSED_UPDATED;
        r.changed = true;
        return r;
    }

    /**
     * Called from the LWC controller when a PI clicks Verify.
     * Transitions Proposed -> Verified and writes the attestation event.
     * Idempotent: re-verifying an already-Verified record is a no-op (no event).
     */
    public static void markVerified(List<Id> recordIds) {
        if (recordIds == null || recordIds.isEmpty()) return;

        // Query in a type-agnostic way. The caller may mix types in one call,
        // though in practice the LWC sends one type at a time.
        Map<Id, SObject> byId = queryByIds(recordIds);

        List<SObject> toUpdate = new List<SObject>();
        List<Verification_Change_Event__c> events = new List<Verification_Change_Event__c>();

        for (Id rid : recordIds) {
            SObject rec = byId.get(rid);
            if (rec == null) {
                throw new VerificationException('Record not found or not accessible: ' + rid);
            }
            String status = (String) rec.get('Verification_Status__c');
            if (STATUS_VERIFIED.equals(status)) continue;  // idempotent

            rec.put('Verification_Status__c', STATUS_VERIFIED);
            rec.put('Verified_At__c', System.now());
            rec.put('Verified_By__c', UserInfo.getUserId());
            toUpdate.add(rec);
            events.add(buildEvent(rid, (String) rec.get('External_Id__c'), EVENT_VERIFIED, null, null));
        }

        if (!toUpdate.isEmpty()) update toUpdate;
        if (!events.isEmpty()) insert events;
    }

    /**
     * Apply a PI override to a verified record. Stored as a JSON delta against
     * the source payload, NOT by mutating the source-projected fields. This is
     * the schema trick from the deck: new overrideable fields require zero
     * schema migration.
     *
     * If the record is currently Proposed, verifying-with-override is one step:
     * we transition to Verified AND store the delta atomically.
     */
    public static void applyOverride(Id recordId, Map<String, Object> overrideDelta) {
        if (recordId == null) {
            throw new VerificationException('recordId is required');
        }
        if (overrideDelta == null || overrideDelta.isEmpty()) {
            throw new VerificationException('overrideDelta is empty — call markVerified instead');
        }

        Map<Id, SObject> byId = queryByIds(new List<Id>{ recordId });
        SObject rec = byId.get(recordId);
        if (rec == null) {
            throw new VerificationException('Record not found or not accessible: ' + recordId);
        }

        // Merge with any existing override. Last-write-wins per key.
        // We keep the merge here so two PIs editing different fields don't clobber each other
        // at the field level (though they will clobber at the JSON level if simultaneous —
        // optimistic locking via LastModifiedDate is the caller's responsibility).
        String existingPayload = (String) rec.get('Override_Payload__c');
        Map<String, Object> merged = new Map<String, Object>();
        if (String.isNotBlank(existingPayload)) {
            merged = (Map<String, Object>) JSON.deserializeUntyped(existingPayload);
        }
        merged.putAll(overrideDelta);

        rec.put('Override_Payload__c', JSON.serialize(merged));
        rec.put('Verification_Status__c', STATUS_VERIFIED);
        rec.put('Verified_At__c', System.now());
        rec.put('Verified_By__c', UserInfo.getUserId());
        update rec;

        insert buildEvent(
            recordId,
            (String) rec.get('External_Id__c'),
            EVENT_OVERRIDE_APPLIED,
            null,
            JSON.serialize(overrideDelta)
        );
    }

    /**
     * Manual entry — PI added something the source doesn't know about.
     * Caller passes an SObject with the user-entered fields populated.
     * We stamp the verification metadata and write a Manual Created event.
     */
    public static Id createManual(SObject manualRecord) {
        if (manualRecord == null) {
            throw new VerificationException('manualRecord is required');
        }
        manualRecord.put('Verification_Status__c', STATUS_MANUAL);
        manualRecord.put('Verified_At__c', System.now());
        manualRecord.put('Verified_By__c', UserInfo.getUserId());
        insert manualRecord;

        insert buildEvent(
            manualRecord.Id,
            (String) manualRecord.get('External_Id__c'),
            EVENT_MANUAL_CREATED,
            null,
            null
        );
        return manualRecord.Id;
    }

    // ---------- helpers ----------

    /**
     * Deterministic hash of the source projection. Order-independent so that
     * a source system reordering its JSON keys doesn't trigger spurious drift.
     */
    @TestVisible
    private static String computeHash(Map<String, Object> sourceFields) {
        if (sourceFields == null || sourceFields.isEmpty()) return '';
        // Sort keys for determinism.
        List<String> keys = new List<String>(sourceFields.keySet());
        keys.sort();
        List<String> parts = new List<String>();
        for (String k : keys) {
            Object v = sourceFields.get(k);
            parts.add(k + '=' + (v == null ? '' : String.valueOf(v)));
        }
        Blob input = Blob.valueOf(String.join(parts, '|'));
        return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', input));
    }

    private static void applySourceFieldsToRecord(SObject rec, Map<String, Object> sourceFields) {
        if (sourceFields == null) return;
        Map<String, Schema.SObjectField> fieldMap = rec.getSObjectType().getDescribe().fields.getMap();
        for (String key : sourceFields.keySet()) {
            if (fieldMap.containsKey(key.toLowerCase())) {
                rec.put(key, sourceFields.get(key));
            }
            // Unknown keys are silently ignored — the source projection is allowed
            // to be wider than the Salesforce object. Whatever is mapped, gets set.
        }
    }

    /**
     * Copy lookup/reference fields from a source record to a target record.
     * Used when the framework generates a new record that needs to inherit
     * relationships from a related record (e.g. Rule 4 supersede flow), so
     * org-specific required lookups don't fail required-field validation.
     *
     * Only fields populated on the source record are considered — we don't
     * call source.get(apiName) blindly, because reading an un-queried field
     * throws SObjectException. This means the caller's SOQL determines which
     * fields are eligible for copy. If the caller wants UHN_Contact__c carried
     * over, the existing-record query must SELECT it.
     */
    private static void copyLookupFields(SObject source, SObject target) {
        Map<String, Object> populated = source.getPopulatedFieldsAsMap();
        Map<String, Schema.SObjectField> fieldMap = source.getSObjectType().getDescribe().fields.getMap();
        for (String apiName : populated.keySet()) {
            Schema.SObjectField f = fieldMap.get(apiName.toLowerCase());
            if (f == null) continue;
            Schema.DescribeFieldResult d = f.getDescribe();
            // Only copy reference fields (lookups, master-details) that are
            // creatable. We skip the framework's own fields to avoid clobbering
            // metadata we've just set on the new record.
            if (d.getType() == Schema.DisplayType.REFERENCE && d.isCreateable()) {
                String lower = apiName.toLowerCase();
                if (lower == 'verified_by__c') continue; // framework owns this
                Object value = populated.get(apiName);
                if (value != null) {
                    target.put(apiName, value);
                }
            }
        }
    }

    private static Verification_Change_Event__c buildEvent(
        Id recordId,
        String externalId,
        String eventType,
        String beforePayload,
        String afterPayload
    ) {
        return new Verification_Change_Event__c(
            Subject_Record_Id__c = recordId,
            External_Id__c       = externalId,
            Event_Type__c        = eventType,
            Before_Payload__c    = beforePayload,
            After_Payload__c     = afterPayload,
            Actor_User_Id__c     = UserInfo.getUserId(),
            Occurred_At__c       = System.now()
        );
    }

    private static Map<String, SObject> queryExisting(SObjectType targetType, Set<String> externalIds, Set<Id> recordIds) {
        Map<String, SObject> out = new Map<String, SObject>();
        if (externalIds.isEmpty() && recordIds.isEmpty()) return out;

        String objName = targetType.getDescribe().getName();
        // We select the verification metadata fields plus every reference
        // (lookup/master-detail) field on the object. The reference fields are
        // needed by copyLookupFields in the Rule 4 supersede flow so the
        // generated Proposed twin inherits relationships from the superseded
        // manual record. Including them here keeps the framework schema-aware
        // without hardcoding any specific org's lookups.
        String fieldList = buildFieldList(targetType);
        String soql =
            'SELECT ' + fieldList + ' ' +
            'FROM ' + String.escapeSingleQuotes(objName) + ' ' +
            'WHERE External_Id__c IN :externalIds OR Id IN :recordIds';

        for (SObject so : Database.query(soql)) {
            String ext = (String) so.get('External_Id__c');
            if (ext != null) out.put(ext, so);
            out.put(String.valueOf(so.Id), so);
        }
        return out;
    }

    private static Map<Id, SObject> queryByIds(List<Id> recordIds) {
        Map<Id, SObject> out = new Map<Id, SObject>();
        if (recordIds.isEmpty()) return out;

        // Group by SObjectType — Apex queries are typed.
        Map<SObjectType, List<Id>> idsByType = new Map<SObjectType, List<Id>>();
        for (Id rid : recordIds) {
            SObjectType t = rid.getSObjectType();
            if (!idsByType.containsKey(t)) idsByType.put(t, new List<Id>());
            idsByType.get(t).add(rid);
        }

        for (SObjectType t : idsByType.keySet()) {
            String objName = t.getDescribe().getName();
            List<Id> ids = idsByType.get(t);
            String fieldList = buildFieldList(t);
            String soql =
                'SELECT ' + fieldList + ' ' +
                'FROM ' + String.escapeSingleQuotes(objName) + ' WHERE Id IN :ids';
            for (SObject so : Database.query(soql)) {
                out.put(so.Id, so);
            }
        }
        return out;
    }

    /**
     * Build the SELECT field list for a verifiable object. Includes the
     * framework's own metadata fields plus all reference fields, so the
     * Rule 4 supersede flow can carry over relationships from the original
     * record without the caller needing to enumerate per-org schema.
     */
    private static String buildFieldList(SObjectType t) {
        Set<String> fields = new Set<String>{
            'Id', 'External_Id__c', 'Verification_Status__c', 'Source_Hash__c',
            'Source_Payload__c', 'Override_Payload__c', 'Verified_At__c', 'Verified_By__c'
        };
        Map<String, Schema.SObjectField> fieldMap = t.getDescribe().fields.getMap();
        for (String apiName : fieldMap.keySet()) {
            Schema.DescribeFieldResult d = fieldMap.get(apiName).getDescribe();
            if (d.getType() == Schema.DisplayType.REFERENCE && d.isAccessible()) {
                fields.add(d.getName());
            }
        }
        return String.join(new List<String>(fields), ', ');
    }
}