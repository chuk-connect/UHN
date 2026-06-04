/** Trigger handler for RHX rollup on UHN_PMCF_Fund_Summary__c. */
public without sharing class RHX_PMCF_FundSummaryHandler {
  /**
   * Executes the rh2 rollup for UHN_PMCF_Fund_Summary__c records.
   * @param oldMap old record map
   * @param newMap new record map
   */
  public static void execute(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
    Type rollClass = System.Type.forName('rh2', 'ParentUtil');
    if (rollClass != null) {
      rh2.ParentUtil pu = (rh2.ParentUtil) rollClass.newInstance();
      if (Trigger.isAfter) {
        pu.performTriggerRollups(
          oldMap,
          newMap,
          new List<String>{ 'UHN_PMCF_Fund_Summary__c' },
          null
        );
      }
    }
  }
}
