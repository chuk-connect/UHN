/**
 * VerificationCardController
 * --------------------------
 * @AuraEnabled surface for the c-verification-card LWC.
 *
 * Design choice (per ADR): the source-vs-override MERGE happens here in Apex.
 * The LWC renders whatever shape this controller returns. That keeps the
 * component dumb, which is what makes it reusable across Business Hub modules.
 *
 * The LWC supplies three things:
 *   - parentRecordId   — the AAR (or whatever the host page is)
 *   - childObjectApiName — e.g. UHN_Publication_Author__c
 *   - fieldSetName     — which fields are shown and editable
 *
 * The relationship from parent -> child is configured via a custom metadata
 * record (Verification_Binding__mdt) keyed on childObjectApiName. That keeps
 * the relationship lookup out of the LWC and out of hardcoded controller logic.
 */
public with sharing class VerificationCardController {

    /**
     * Row DTO returned to the LWC. One per child record.
     *
     * Why a flat DTO instead of returning the SObject directly:
     *   - The LWC doesn't need to know about Source_Payload__c vs Override_Payload__c.
     *     It gets one merged `displayValues` map and a parallel `sourceValues` map for
     *     hover-to-see-source UX.
     *   - We can include computed flags (hasOverride, isOverridden per field) without
     *     polluting the schema.
     *   - JSON over the wire is smaller and more stable across schema changes.
     */
    public class VerificationRow {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String externalId;
        @AuraEnabled public String status;             // Proposed | Verified | Manual | Superseded
        @AuraEnabled public Datetime verifiedAt;
        @AuraEnabled public Id verifiedById;
        @AuraEnabled public String verifiedByName;
        @AuraEnabled public Map<String, Object> displayValues;   // merged: source ?? override
        @AuraEnabled public Map<String, Object> sourceValues;    // raw from source, for hover
        @AuraEnabled public List<String> overriddenFieldNames;    // which keys were overridden
    }

    /**
     * Field metadata returned alongside rows so the LWC can render labels,
     * types, and editability without a second describe call from the client.
     */
    public class FieldMeta {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String type;       // STRING, DATE, REFERENCE, etc.
        @AuraEnabled public Boolean editable;  // false for system-managed fields
    }

    public class CardData {
        @AuraEnabled public List<FieldMeta> fields;
        @AuraEnabled public List<VerificationRow> rows;
    }

    /**
     * Main read endpoint. Returns merged rows + field metadata for the card.
     *
     * Security model:
     *   - `with sharing` on the class enforces row-level access.
     *   - We additionally check object-level read CRUD before querying.
     *   - Fields requested via fieldSet are checked for FLS read.
     */
    @AuraEnabled(cacheable=true)
    public static CardData getCardData(Id parentRecordId, String childObjectApiName, String fieldSetName) {
        if (parentRecordId == null || String.isBlank(childObjectApiName) || String.isBlank(fieldSetName)) {
            throw new VerificationException('parentRecordId, childObjectApiName, and fieldSetName are all required');
        }

        SObjectType childType = Schema.getGlobalDescribe().get(childObjectApiName);
        if (childType == null) {
            throw new VerificationException('Unknown SObject: ' + childObjectApiName);
        }
        Schema.DescribeSObjectResult d = childType.getDescribe();
        if (!d.isAccessible()) {
            throw new VerificationException('No read access to ' + childObjectApiName);
        }

        // Resolve the parent->child relationship via custom metadata.
        // For the AAR case, this maps "UHN_Publication_Author__c" -> "AAR__c".
        String parentLookupField = resolveParentLookupField(childObjectApiName);

        List<Schema.FieldSetMember> fieldSetMembers = resolveFieldSet(d, fieldSetName);

        List<FieldMeta> fieldMetas = new List<FieldMeta>();
        Set<String> fieldsToQuery = new Set<String>{
            'Id', 'External_Id__c', 'Verification_Status__c',
            'Source_Payload__c', 'Override_Payload__c',
            'Verified_At__c', 'Verified_By__c', 'Verified_By__r.Name'
        };
        for (Schema.FieldSetMember m : fieldSetMembers) {
            Schema.DescribeFieldResult f = m.getSObjectField().getDescribe();
            if (!f.isAccessible()) continue;  // FLS — silently skip what they can't read
            fieldsToQuery.add(f.getName());

            // For lookup/master-detail fields, also query the related Name so
            // buildRow can display a human-readable value instead of the raw Id.
            if (f.getType() == Schema.DisplayType.REFERENCE) {
                String relName = f.getRelationshipName();
                if (String.isNotBlank(relName)) {
                    fieldsToQuery.add(relName + '.Name');
                }
            }

            FieldMeta fm = new FieldMeta();
            fm.apiName = f.getName();
            fm.label = f.getLabel();
            fm.type = String.valueOf(f.getType());
            fm.editable = f.isUpdateable();
            fieldMetas.add(fm);
        }

        // Build and execute the query. Sharing rules apply via `with sharing`.
        String soql =
            'SELECT ' + String.join(new List<String>(fieldsToQuery), ', ') +
            ' FROM ' + String.escapeSingleQuotes(childObjectApiName) +
            ' WHERE ' + String.escapeSingleQuotes(parentLookupField) + ' = :parentRecordId' +
            ' AND Verification_Status__c != \'Superseded\'' +  // hide cleanup artefacts
            ' ORDER BY Verification_Status__c, External_Id__c';

        List<SObject> records = Database.query(soql);

        CardData out = new CardData();
        out.fields = fieldMetas;
        out.rows = new List<VerificationRow>();
        for (SObject so : records) {
            out.rows.add(buildRow(so, fieldMetas));
        }
        return out;
    }

    /**
     * Build a single row DTO from an SObject. This is where source + override
     * are merged. The LWC never sees the raw payloads.
     */
    private static VerificationRow buildRow(SObject so, List<FieldMeta> fields) {
        VerificationRow row = new VerificationRow();
        row.recordId = so.Id;
        row.externalId = (String) so.get('External_Id__c');
        row.status = (String) so.get('Verification_Status__c');
        row.verifiedAt = (Datetime) so.get('Verified_At__c');
        row.verifiedById = (Id) so.get('Verified_By__c');

        // Pull verifier name via the relationship if present
        SObject verifier = so.getSObject('Verified_By__r');
        if (verifier != null) row.verifiedByName = (String) verifier.get('Name');

        Map<String, Object> source = parseJsonSafe((String) so.get('Source_Payload__c'));
        Map<String, Object> overrideValues = parseJsonSafe((String) so.get('Override_Payload__c'));

        row.sourceValues = source;
        row.displayValues = new Map<String, Object>();
        row.overriddenFieldNames = new List<String>();

        // Merge rule: override wins where present, otherwise source.
        // We iterate the field set so the LWC gets a stable shape regardless of
        // what the source happens to include.
        for (FieldMeta f : fields) {
            String key = f.apiName;
            if (overrideValues.containsKey(key)) {
                row.displayValues.put(key, overrideValues.get(key));
                row.overriddenFieldNames.add(key);
            } else if (source.containsKey(key)) {
                row.displayValues.put(key, source.get(key));
            } else {
                // For Manual records, the source payload may be empty —
                // fall back to the live field value on the SObject.
                // For REFERENCE fields, resolve the related Name instead of
                // returning the raw Id that so.get(key) would produce.
                Object val = so.get(key);
                if ('REFERENCE'.equals(f.type)) {
                    String relName = key.endsWith('__c')
                        ? key.replace('__c', '__r')
                        : key.removeEnd('Id');
                    try {
                        SObject rel = so.getSObject(relName);
                        if (rel != null) val = (String) rel.get('Name');
                    } catch (SObjectException ignored) {
                        // Relationship wasn't queried (e.g. field added to set
                        // after this deploy) — fall back to the raw Id.
                    }
                }
                row.displayValues.put(key, val);
            }
        }
        return row;
    }

    /**
     * LWC -> server: PI clicked "Verify" on one or more rows.
     */
    @AuraEnabled
    public static void verify(List<Id> recordIds) {
        VerificationReconciliationService.markVerified(recordIds);
    }

    /**
     * LWC -> server: PI corrected a field on a Verified (or Proposed) row.
     * The LWC sends only the changed key/value pairs, not the whole record.
     */
    @AuraEnabled
    public static void overrideRecord(Id recordId, String overrideJson) {
        if (String.isBlank(overrideJson)) {
            throw new VerificationException('overrideJson is required');
        }
        Map<String, Object> delta = (Map<String, Object>) JSON.deserializeUntyped(overrideJson);
        VerificationReconciliationService.applyOverride(recordId, delta);
    }

    // ---------- helpers ----------

    private static Map<String, Object> parseJsonSafe(String s) {
        if (String.isBlank(s)) return new Map<String, Object>();
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(s);
        } catch (Exception e) {
            // A malformed payload is a data-quality bug, not a request bug —
            // we don't want it to take down the whole card.
            return new Map<String, Object>();
        }
    }

    /**
     * Looks up the parent-relationship field for a given child object.
     * Configured via Verification_Binding__mdt records:
     *   { Child_Object__c: 'UHN_Publication_Author__c', Parent_Lookup_Field__c: 'AAR__c' }
     *
     * Falls back to a naming convention ("AAR__c") in dev orgs.
     */
    private static String resolveParentLookupField(String childObjectApiName) {
        // Custom metadata lookup. If the binding doesn't exist, fall back.
        // (We deliberately don't throw — devs need the component to render
        // before they've finished configuring everything.)
        List<Verification_Binding__mdt> bindings = [
            SELECT Parent_Lookup_Field__c
            FROM Verification_Binding__mdt
            WHERE Child_Object__c = :childObjectApiName
            LIMIT 1
        ];
        if (!bindings.isEmpty() && String.isNotBlank(bindings[0].Parent_Lookup_Field__c)) {
            return bindings[0].Parent_Lookup_Field__c;
        }
        return 'AAR__c';
    }

    private static List<Schema.FieldSetMember> resolveFieldSet(Schema.DescribeSObjectResult d, String fieldSetName) {
        Map<String, Schema.FieldSet> fsMap = d.fieldSets.getMap();
        if (fsMap.containsKey(fieldSetName)) {
            return fsMap.get(fieldSetName).getFields();
        }
        throw new VerificationException(
            'Field set "' + fieldSetName + '" not found on ' + d.getName() +
            '. Create the field set or pass an existing one.'
        );
    }
}
