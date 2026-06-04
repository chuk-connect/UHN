trigger RHX_UHN_PMCF_Fund_Summary on UHN_PMCF_Fund_Summary__c(
  after delete,
  after insert,
  after undelete,
  after update,
  before delete
) {
  RHX_PMCF_FundSummaryHandler.execute(Trigger.oldMap, Trigger.newMap);
}
