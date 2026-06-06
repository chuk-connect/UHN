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
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
public with sharing class VerificationCardController {
  // Fields that are read-only in the modal regardless of FLS.
  // Id and External_Id__c are identifier keys — PIs must not change them.
  // Verified_By__c and Verified_At__c are audit stamps — the service owns them.
  // Verification_Status__c and Is_Verified__c are intentionally ABSENT so PIs
  // can edit them directly; they two-way-sync with each other in the LWC modal.
  private static final Set<String> SYSTEM_FIELD_NAMES = new Set<String>{
    'Id',
    'External_Id__c',
    'Verified_By__c',
    'Verified_At__c'
  };

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
    @AuraEnabled
    public Id recordId;
    @AuraEnabled
    public String externalId;
    @AuraEnabled
    public String status; // Proposed | Verified | Manual | Superseded
    @AuraEnabled
    public Datetime verifiedAt;
    @AuraEnabled
    public Id verifiedById;
    @AuraEnabled
    public String verifiedByName;
    @AuraEnabled
    public Map<String, Object> displayValues; // merged: source ?? override
    @AuraEnabled
    public Map<String, Object> sourceValues; // raw from source, for hover
    @AuraEnabled
    public List<String> overriddenFieldNames; // which keys were overridden
  }

  /**
   * Field metadata returned alongside rows so the LWC can render labels,
   * types, and editability without a second describe call from the client.
   */
  public class FieldMeta {
    @AuraEnabled
    public String apiName;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String type; // STRING, DATE, REFERENCE, PICKLIST, etc.
    @AuraEnabled
    public Boolean editable; // false for system-managed fields
    @AuraEnabled
    public List<Map<String, String>> picklistValues; // populated for PICKLIST type only
  }

  /** DTO wrapping field metadata and row data for the LWC card. */
  public class CardData {
    @AuraEnabled
    public List<FieldMeta> fields;
    @AuraEnabled
    public List<VerificationRow> rows;
    @AuraEnabled
    public Integer unreviewedCount; // null-status records that predate the framework
  }

  /**
   * Main read endpoint. Returns merged rows + field metadata for the card.
   *
   * Security model:
   *   - `with sharing` on the class enforces row-level access.
   *   - We additionally check object-level read CRUD before querying.
   *   - Fields requested via fieldSet are checked for FLS read.
   *
   * @param parentRecordId the parent record Id (e.g. AAR Id)
   * @param childObjectApiName API name of the child verifiable object
   * @param fieldSetName name of the field set to render
   * @return CardData with field metadata and merged rows
   */
  @SuppressWarnings(
    'PMD.ApexSOQLInjection,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssCount'
  )
  @AuraEnabled(cacheable=true)
  public static CardData getCardData(
    Id parentRecordId,
    String childObjectApiName,
    String fieldSetName
  ) {
    if (
      parentRecordId == null ||
      String.isBlank(childObjectApiName) ||
      String.isBlank(fieldSetName)
    ) {
      throw new VerificationException(
        'parentRecordId, childObjectApiName, and fieldSetName are all required'
      );
    }

    SObjectType childType = Schema.getGlobalDescribe().get(childObjectApiName);
    if (childType == null) {
      throw new VerificationException('Unknown SObject: ' + childObjectApiName);
    }
    Schema.DescribeSObjectResult d = childType.getDescribe();
    if (!d.isAccessible()) {
      throw new VerificationException(
        'No read access to ' + childObjectApiName
      );
    }

    // Resolve the binding: parent lookup field and optional one-hop traversal.
    BindingConfig binding = resolveBinding(childObjectApiName);
    String parentLookupField = binding.parentLookupField;

    // One-hop traversal: if the card is placed on a grandparent record
    // (e.g. AAR page), resolve the actual parent Id via the intermediate field.
    Id effectiveParentId = parentRecordId;
    if (String.isNotBlank(binding.intermediateParentField)) {
      effectiveParentId = resolveIntermediateParent(
        parentRecordId,
        binding.intermediateParentField
      );
    }

    List<Schema.FieldSetMember> fieldSetMembers = resolveFieldSet(
      d,
      fieldSetName
    );

    List<FieldMeta> fieldMetas = new List<FieldMeta>();
    Set<String> fieldsToQuery = new Set<String>{
      'Id',
      'External_Id__c',
      'Verification_Status__c',
      'Source_Payload__c',
      'Override_Payload__c',
      'Verified_At__c',
      'Verified_By__c',
      'Verified_By__r.Name'
    };
    for (Schema.FieldSetMember m : fieldSetMembers) {
      Schema.DescribeFieldResult f = m.getSObjectField().getDescribe();
      if (!f.isAccessible()) {
        continue; // FLS — silently skip what they can't read
      }
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
      // Editability = "can a PI correct this via Override_Payload__c", not direct DML.
      fm.editable = !SYSTEM_FIELD_NAMES.contains(f.getName());
      // Pass picklist options so the LWC can render a combobox.
      // Exclude Superseded — that transition is system-only.
      if (f.getType() == Schema.DisplayType.PICKLIST) {
        fm.picklistValues = new List<Map<String, String>>();
        for (Schema.PicklistEntry pe : f.getPicklistValues()) {
          if (pe.isActive() && pe.getValue() != 'Superseded') {
            fm.picklistValues.add(
              new Map<String, String>{
                'label' => pe.getLabel(),
                'value' => pe.getValue()
              }
            );
          }
        }
      }
      fieldMetas.add(fm);
    }

    // Excluded__c is an optional per-object soft-delete flag (set by rejectRecord).
    // Add the filter dynamically so the query stays safe on objects without the field.
    String excludedFilter = d.fields.getMap().containsKey('excluded__c')
      ? ' AND (Excluded__c = false OR Excluded__c = null)'
      : '';

    // Count null-status records (pre-framework legacy) so the card can surface
    // an informational banner. These are excluded from the main rows query.
    String unreviewedSoql =
      'SELECT COUNT() FROM ' +
      String.escapeSingleQuotes(childObjectApiName) +
      ' WHERE ' +
      String.escapeSingleQuotes(parentLookupField) +
      ' = :effectiveParentId' +
      ' AND Verification_Status__c = null';
    Integer unreviewedCount = Database.countQuery(unreviewedSoql);

    // Build and execute the main rows query. Sharing rules apply via `with sharing`.
    // Null-status records are excluded — they have no source payload and cannot
    // be actioned until the source sync runs. Superseded are hidden as cleanup artefacts.
    String soql =
      'SELECT ' +
      String.join(new List<String>(fieldsToQuery), ', ') +
      ' FROM ' +
      String.escapeSingleQuotes(childObjectApiName) +
      ' WHERE ' +
      String.escapeSingleQuotes(parentLookupField) +
      ' = :effectiveParentId' +
      ' AND Verification_Status__c != null' +
      ' AND Verification_Status__c != \'Superseded\'' +
      excludedFilter +
      ' ORDER BY Verification_Status__c, External_Id__c';

    List<SObject> records = Database.query(soql);

    CardData out = new CardData();
    out.fields = fieldMetas;
    out.unreviewedCount = unreviewedCount;
    out.rows = new List<VerificationRow>();
    for (SObject so : records) {
      out.rows.add(buildRow(so, fieldMetas));
    }
    return out;
  }

  /**
   * Build a single row DTO from an SObject. This is where source + override
   * are merged. The LWC never sees the raw payloads.
   *
   * @param so the SObject record to shape
   * @param fields field metadata list
   * @return shaped VerificationRow DTO
   */
  @SuppressWarnings(
    'PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssCount'
  )
  private static VerificationRow buildRow(SObject so, List<FieldMeta> fields) {
    VerificationRow row = new VerificationRow();
    row.recordId = so.Id;
    row.externalId = (String) so.get('External_Id__c');
    row.status = (String) so.get('Verification_Status__c');
    row.verifiedAt = (Datetime) so.get('Verified_At__c');
    row.verifiedById = (Id) so.get('Verified_By__c');

    // Pull verifier name via the relationship if present
    SObject verifier = so.getSObject('Verified_By__r');
    if (verifier != null) {
      row.verifiedByName = (String) verifier.get('Name');
    }

    Map<String, Object> source = parseJsonSafe(
      (String) so.get('Source_Payload__c')
    );
    Map<String, Object> overrideValues = parseJsonSafe(
      (String) so.get('Override_Payload__c')
    );

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
            if (rel != null) {
              val = (String) rel.get('Name');
            }
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
   *
   * @param recordIds list of record Ids to mark as Verified
   */
  @AuraEnabled
  public static void verify(List<Id> recordIds) {
    VerificationReconciliationService.markVerified(recordIds);
  }

  /**
   * Queries the parent record's status field — reliable fallback for inertness
   * when the App Builder `parentStatus` binding is not configured.
   *
   * @param parentRecordId the parent record
   * @param statusFieldApiName API name of the status field (e.g. Status__c)
   * @return the status value, or null if not accessible / field does not exist
   */
  @AuraEnabled
  public static String getParentStatus(
    Id parentRecordId,
    String statusFieldApiName
  ) {
    if (parentRecordId == null || String.isBlank(statusFieldApiName)) {
      return null;
    }
    SObjectType t = parentRecordId.getSObjectType();
    if (!t.getDescribe().isAccessible()) {
      return null;
    }
    String objName = t.getDescribe().getName();
    try {
      String soql =
        'SELECT ' +
        String.escapeSingleQuotes(statusFieldApiName) +
        ' FROM ' +
        String.escapeSingleQuotes(objName) +
        ' WHERE Id = :parentRecordId WITH USER_MODE LIMIT 1';
      List<SObject> rows = Database.query(soql);
      return rows.isEmpty() ? null : (String) rows[0].get(statusFieldApiName);
    } catch (Exception e) {
      return null; // Field absent or no FLS — degrade silently
    }
  }

  /**
   * LWC -> server: PI confirmed a Manual record is accurate.
   * Transitions Manual -> Verified and writes a Manual Confirmed change event.
   *
   * @param recordId the Manual record to confirm
   */
  @AuraEnabled
  public static void confirmManualRecord(Id recordId) {
    VerificationReconciliationService.confirmManualRecord(recordId);
  }

  /**
   * LWC -> server: PI clicked "Reject" on a Proposed row.
   * Routes through VerificationReconciliationService which sets Excluded__c,
   * Exclusion_Reason__c (when the fields exist), and writes a change event.
   *
   * @param recordId the record to exclude
   * @param reason   optional exclusion reason
   */
  @AuraEnabled
  public static void rejectRecord(Id recordId, String reason) {
    VerificationReconciliationService.rejectRecord(recordId, reason);
  }

  /**
   * Applies PI corrections to a record via the override payload pattern.
   * Called by external write paths (Flows, admin tools) — NOT by the LWC
   * directly. The card is read-display + action-dispatch; data edits route
   * through the workspace modal or record page.
   *
   * @param recordId the record to override
   * @param overrideJson JSON delta of changed fields
   */
  @AuraEnabled
  public static void overrideRecord(Id recordId, String overrideJson) {
    if (String.isBlank(overrideJson)) {
      throw new VerificationException('overrideJson is required');
    }
    Map<String, Object> delta = (Map<String, Object>) JSON.deserializeUntyped(
      overrideJson
    );
    VerificationReconciliationService.applyOverride(recordId, delta);
  }

  /**
   * Returns recent Verification_Change_Event__c records for a given subject record.
   * Used by the LWC to show a per-row audit trail and feeds the EXP-03 bulk export.
   *
   * @param subjectRecordId the child record whose history to retrieve
   * @param limitCount max events to return (default 20)
   * @return list of change events, newest first
   */
  @AuraEnabled(cacheable=true)
  public static List<Verification_Change_Event__c> getRecentChangeEvents(
    Id subjectRecordId,
    Integer limitCount
  ) {
    if (subjectRecordId == null) {
      throw new VerificationException('subjectRecordId is required');
    }
    Integer maxRows = (limitCount != null && limitCount > 0) ? limitCount : 20;
    return [
      SELECT
        Id,
        Name,
        Subject_Record_Id__c,
        External_Id__c,
        Event_Type__c,
        Before_Payload__c,
        After_Payload__c,
        Actor_User_Id__c,
        Occurred_At__c
      FROM Verification_Change_Event__c
      WHERE Subject_Record_Id__c = :subjectRecordId
      WITH USER_MODE
      ORDER BY Occurred_At__c DESC
      LIMIT :maxRows
    ];
  }

  // ---------- helpers ----------

  /**
   * Safely parses a JSON string into an untyped map, returning an empty map on blank input or parse error.
   * @param s JSON string to parse
   * @return deserialized map or empty map on blank/error
   */
  private static Map<String, Object> parseJsonSafe(String s) {
    if (String.isBlank(s)) {
      return new Map<String, Object>();
    }
    try {
      return (Map<String, Object>) JSON.deserializeUntyped(s);
    } catch (Exception e) {
      // A malformed payload is a data-quality bug, not a request bug —
      // we don't want it to take down the whole card.
      return new Map<String, Object>();
    }
  }

  /** Internal DTO bundling everything the controller needs from a binding record. */
  private class BindingConfig {
    String parentLookupField;
    String intermediateParentField;
    String parentStatusField;
  }

  /**
   * Resolves the binding config for a given child object.
   * Falls back to sensible defaults so the card renders before
   * all metadata records have been configured.
   *
   * @param childObjectApiName API name of the child object
   * @return populated BindingConfig
   */
  private static BindingConfig resolveBinding(String childObjectApiName) {
    List<Verification_Binding__mdt> bindings = [
      SELECT
        Parent_Lookup_Field__c,
        Intermediate_Parent_Field__c,
        Parent_Status_Field__c
      FROM Verification_Binding__mdt
      WHERE Child_Object__c = :childObjectApiName
      WITH USER_MODE
      LIMIT 1
    ];
    BindingConfig cfg = new BindingConfig();
    cfg.parentLookupField = 'AAR__c'; // fallback
    if (!bindings.isEmpty()) {
      if (String.isNotBlank(bindings[0].Parent_Lookup_Field__c)) {
        cfg.parentLookupField = bindings[0].Parent_Lookup_Field__c;
      }
      cfg.intermediateParentField = bindings[0].Intermediate_Parent_Field__c;
      cfg.parentStatusField = bindings[0].Parent_Status_Field__c;
    }
    return cfg;
  }

  /**
   * Resolves the effective parent Id for a one-hop traversal.
   * Example: card on AAR page → resolve AAR.UHN_Contact__c → use that Contact Id
   * as the actual parent for the child query.
   *
   * @param parentRecordId the Id of the grandparent record
   * @param intermediateField lookup field on the grandparent pointing to the real parent
   * @return resolved parent Id, or the original parentRecordId if resolution fails
   */
  @SuppressWarnings('PMD.ApexSOQLInjection')
  private static Id resolveIntermediateParent(
    Id parentRecordId,
    String intermediateField
  ) {
    SObjectType t = parentRecordId.getSObjectType();
    String objName = t.getDescribe().getName();
    try {
      String soql =
        'SELECT ' +
        String.escapeSingleQuotes(intermediateField) +
        ' FROM ' +
        String.escapeSingleQuotes(objName) +
        ' WHERE Id = :parentRecordId WITH USER_MODE LIMIT 1';
      List<SObject> rows = Database.query(soql);
      if (!rows.isEmpty()) {
        Id resolved = (Id) rows[0].get(intermediateField);
        if (resolved != null) {
          return resolved;
        }
      }
    } catch (Exception e) {
      // Field doesn't exist or no access — fall back to original parentRecordId
    }
    return parentRecordId;
  }

  /**
   * Resolves the named field set from a describe result, throwing if not found.
   * @param d describe result for the child object
   * @param fieldSetName name of the field set
   * @return list of field set members
   * @throws VerificationException if field set is not found
   */
  private static List<Schema.FieldSetMember> resolveFieldSet(
    Schema.DescribeSObjectResult d,
    String fieldSetName
  ) {
    Map<String, Schema.FieldSet> fsMap = d.fieldSets.getMap();
    if (fsMap.containsKey(fieldSetName)) {
      return fsMap.get(fieldSetName).getFields();
    }
    throw new VerificationException(
      'Field set "' +
        fieldSetName +
        '" not found on ' +
        d.getName() +
        '. Create the field set or pass an existing one.'
    );
  }
}
