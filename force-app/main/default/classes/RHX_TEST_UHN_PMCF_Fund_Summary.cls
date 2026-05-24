@isTest(SeeAllData=true)
public class RHX_TEST_UHN_PMCF_Fund_Summary {
	static testMethod void RHX_Testmethod() {
		List<sObject> sourceList = [SELECT Id
			FROM UHN_PMCF_Fund_Summary__c ORDER BY LastModifiedDate DESC LIMIT 1];
		if (sourceList.size() == 0) {
			UHN_PMCF_Fund_Master__c fund = new UHN_PMCF_Fund_Master__c();
			insert fund;
			UHN_PMCF_Fund_Summary__c summary = new UHN_PMCF_Fund_Summary__c(
				UHN_Fund__c = fund.Id
			);
			insert summary;
			sourceList.add(summary);
		}
		rh2.ParentUtil.UpsertRollupTestRecords(sourceList);
	}
}
