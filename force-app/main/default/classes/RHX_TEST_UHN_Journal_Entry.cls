@isTest(SeeAllData=true)
public class RHX_TEST_UHN_Journal_Entry {
	static testMethod void RHX_Testmethod() {
		List<sObject> sourceList = [SELECT Id
			FROM UHN_Journal_Entry__c ORDER BY LastModifiedDate DESC LIMIT 1];
		if (sourceList.size() == 0) {
			return;
		}
		rh2.ParentUtil.UpsertRollupTestRecords(sourceList);
	}
}
