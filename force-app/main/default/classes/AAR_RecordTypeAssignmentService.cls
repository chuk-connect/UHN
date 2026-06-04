/**
 * AAR_RecordTypeAssignmentService
 * --------------------------------
 * Before-insert service that assigns the correct Record Type to AAR child
 * object records based on Data_Origin__c.
 *
 * Assignment rule (BH-1159):
 *   Data_Origin__c = 'Manual' (or blank)  → Manual_Entry record type
 *   Data_Origin__c = any source system    → Proposed record type
 *
 * If the target record type doesn't exist on the object (e.g. AAR_Scholarly_Output__c
 * during Phase 1 before its polymorphic design is resolved), the method is a no-op.
 *
 * Record type IDs are cached per transaction in a static map to avoid repeated queries
 * when the trigger fires in bulk.
 */
public with sharing class AAR_RecordTypeAssignmentService {
  @TestVisible
  private static Map<String, Map<String, Id>> rtIdCache = new Map<String, Map<String, Id>>();

  private static final String RT_MANUAL_ENTRY = 'Manual_Entry';
  private static final String RT_PROPOSED = 'Proposed';
  private static final String ORIGIN_MANUAL = 'Manual';

  public static void assign(List<SObject> records, String sObjectType) {
    if (records == null || records.isEmpty()) {
      return;
    }
    Map<String, Id> rtMap = getRecordTypeMap(sObjectType);
    if (rtMap.isEmpty()) {
      return;
    }
    for (SObject rec : records) {
      if (rec.get('RecordTypeId') != null) {
        continue;
      }
      String origin = (String) rec.get('Data_Origin__c');
      Boolean isManual = String.isBlank(origin) || origin == ORIGIN_MANUAL;
      String targetRt = isManual ? RT_MANUAL_ENTRY : RT_PROPOSED;
      Id rtId = rtMap.get(targetRt);
      if (rtId == null) {
        rtId = rtMap.get(RT_MANUAL_ENTRY);
      }
      if (rtId != null) {
        rec.put('RecordTypeId', rtId);
      }
    }
  }

  private static Map<String, Id> getRecordTypeMap(String sObjectType) {
    if (!rtIdCache.containsKey(sObjectType)) {
      Map<String, Id> rtMap = new Map<String, Id>();
      for (RecordType rt : [
        SELECT DeveloperName, Id
        FROM RecordType
        WHERE SObjectType = :sObjectType AND IsActive = TRUE
      ]) {
        rtMap.put(rt.DeveloperName, rt.Id);
      }
      rtIdCache.put(sObjectType, rtMap);
    }
    return rtIdCache.get(sObjectType);
  }
}
