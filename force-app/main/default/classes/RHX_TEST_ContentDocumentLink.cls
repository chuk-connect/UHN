@isTest(SeeAllData=true)
public class RHX_TEST_ContentDocumentLink {
  static testMethod void RHX_Testmethod() {
    List<ContentDocument> cdList = [
      SELECT Id
      FROM ContentDocument
      ORDER BY LastModifiedDate DESC
      LIMIT 1
    ];
    Id contentDocId;
    if (cdList.size() == 0) {
      ContentVersion cv = new ContentVersion();
      cv.Title = 'RHX Test File';
      cv.PathOnClient = 'rhx_test.txt';
      cv.VersionData = Blob.valueOf('test');
      insert cv;
      contentDocId = [
        SELECT ContentDocumentId
        FROM ContentVersion
        WHERE Id = :cv.Id
      ]
      .ContentDocumentId;
    } else {
      contentDocId = cdList[0].Id;
    }
    List<sObject> sourceList = [
      SELECT Id
      FROM ContentDocumentLink
      WHERE ContentDocumentId = :contentDocId
      LIMIT 1
    ];
    if (sourceList.size() == 0) {
      sourceList.add(new ContentDocumentLink());
    }
    rh2.ParentUtil.UpsertRollupTestRecords(sourceList);
  }
}
