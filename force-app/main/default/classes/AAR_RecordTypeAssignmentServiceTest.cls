@isTest
private class AAR_RecordTypeAssignmentServiceTest {
  @isTest
  static void recognitionAssignsManualEntry() {
    Id manualRtId = Schema.SObjectType.AAR_Recognition__c
      .getRecordTypeInfosByDeveloperName()
      .get('Manual_Entry')
      ?.getRecordTypeId();

    AAR_Recognition__c rec = new AAR_Recognition__c();

    Test.startTest();
    AAR_RecordTypeAssignmentService.assign(
      new List<SObject>{ rec },
      'AAR_Recognition__c'
    );
    Test.stopTest();

    System.assertEquals(
      manualRtId,
      rec.RecordTypeId,
      'AAR_Recognition__c should always get Manual_Entry record type'
    );
  }

  @isTest
  static void pubAuthorManualOriginGetsManualEntry() {
    Id manualRtId = Schema.SObjectType.UHN_Publication_Author__c
      .getRecordTypeInfosByDeveloperName()
      .get('Manual_Entry')
      ?.getRecordTypeId();

    UHN_Publication_Author__c rec = new UHN_Publication_Author__c(
      Data_Origin__c = 'Manual'
    );

    Test.startTest();
    AAR_RecordTypeAssignmentService.assign(
      new List<SObject>{ rec },
      'UHN_Publication_Author__c'
    );
    Test.stopTest();

    System.assertEquals(
      manualRtId,
      rec.RecordTypeId,
      'Data_Origin__c = Manual should produce Manual_Entry record type'
    );
  }

  @isTest
  static void pubAuthorBlankOriginGetsManualEntry() {
    Id manualRtId = Schema.SObjectType.UHN_Publication_Author__c
      .getRecordTypeInfosByDeveloperName()
      .get('Manual_Entry')
      ?.getRecordTypeId();

    UHN_Publication_Author__c rec = new UHN_Publication_Author__c();

    Test.startTest();
    AAR_RecordTypeAssignmentService.assign(
      new List<SObject>{ rec },
      'UHN_Publication_Author__c'
    );
    Test.stopTest();

    System.assertEquals(
      manualRtId,
      rec.RecordTypeId,
      'Blank Data_Origin__c should fall through to Manual_Entry record type'
    );
  }

  @isTest
  static void pubAuthorIntegrationOriginGetsProposed() {
    Id proposedRtId = Schema.SObjectType.UHN_Publication_Author__c
      .getRecordTypeInfosByDeveloperName()
      .get('Proposed')
      ?.getRecordTypeId();

    UHN_Publication_Author__c rec = new UHN_Publication_Author__c(
      Data_Origin__c = 'ORCID'
    );

    Test.startTest();
    AAR_RecordTypeAssignmentService.assign(
      new List<SObject>{ rec },
      'UHN_Publication_Author__c'
    );
    Test.stopTest();

    System.assertEquals(
      proposedRtId,
      rec.RecordTypeId,
      'Non-Manual Data_Origin__c should produce Proposed record type'
    );
  }

  @isTest
  static void alreadySetRecordTypeIdIsNotOverridden() {
    Id proposedRtId = Schema.SObjectType.UHN_Publication_Author__c
      .getRecordTypeInfosByDeveloperName()
      .get('Proposed')
      ?.getRecordTypeId();
    Id manualRtId = Schema.SObjectType.UHN_Publication_Author__c
      .getRecordTypeInfosByDeveloperName()
      .get('Manual_Entry')
      ?.getRecordTypeId();

    UHN_Publication_Author__c rec = new UHN_Publication_Author__c(
      Data_Origin__c = 'Manual',
      RecordTypeId = proposedRtId
    );

    Test.startTest();
    AAR_RecordTypeAssignmentService.assign(
      new List<SObject>{ rec },
      'UHN_Publication_Author__c'
    );
    Test.stopTest();

    System.assertNotEquals(
      manualRtId,
      rec.RecordTypeId,
      'Pre-set RecordTypeId must not be overridden by the service'
    );
    System.assertEquals(
      proposedRtId,
      rec.RecordTypeId,
      'Pre-set RecordTypeId should be preserved unchanged'
    );
  }

  @isTest
  static void emptyListIsNoOp() {
    Test.startTest();
    AAR_RecordTypeAssignmentService.assign(
      new List<SObject>(),
      'UHN_Publication_Author__c'
    );
    Test.stopTest();
    System.assertEquals(
      0,
      AAR_RecordTypeAssignmentService.rtIdCache.size(),
      'Empty list should not trigger a RecordType query'
    );
  }

  @isTest
  static void nullListIsNoOp() {
    Test.startTest();
    AAR_RecordTypeAssignmentService.assign(null, 'UHN_Publication_Author__c');
    Test.stopTest();
    System.assertEquals(
      0,
      AAR_RecordTypeAssignmentService.rtIdCache.size(),
      'Null list should be a safe no-op'
    );
  }

  @isTest
  static void fallsBackToManualEntryWhenTargetRtMissing() {
    // AAR_Recognition__c only has Manual_Entry — no Proposed RT.
    // Passing a non-Manual Data_Origin__c forces the Proposed lookup to return
    // null, triggering the Manual_Entry fallback.
    Id manualRtId = Schema.SObjectType.AAR_Recognition__c
      .getRecordTypeInfosByDeveloperName()
      .get('Manual_Entry')
      ?.getRecordTypeId();

    AAR_Recognition__c rec = new AAR_Recognition__c(
      Data_Origin__c = 'Integration'
    );

    Test.startTest();
    AAR_RecordTypeAssignmentService.assign(
      new List<SObject>{ rec },
      'AAR_Recognition__c'
    );
    Test.stopTest();

    System.assertEquals(
      manualRtId,
      rec.RecordTypeId,
      'Should fall back to Manual_Entry when Proposed RT does not exist on the object'
    );
  }

  @isTest
  static void cacheAvoidsDuplicateQueries() {
    AAR_RecordTypeAssignmentService.rtIdCache.clear();

    List<UHN_Publication_Author__c> batch = new List<UHN_Publication_Author__c>();
    for (Integer i = 0; i < 10; i++) {
      batch.add(new UHN_Publication_Author__c(Data_Origin__c = 'ORCID'));
    }

    Test.startTest();
    AAR_RecordTypeAssignmentService.assign(
      (List<SObject>) batch,
      'UHN_Publication_Author__c'
    );
    Test.stopTest();

    System.assertEquals(
      1,
      AAR_RecordTypeAssignmentService.rtIdCache.size(),
      'Cache should be populated after first call and reused for all 10 records'
    );
  }
}
