@IsTest
private class AAR_ScholarlyOutputSyncHandlerTest {
  @TestSetup
  static void setup() {
    Account inst = new Account(Name = 'Test Research Institute');
    insert inst;
    Contact pi = new Contact(LastName = 'TestPI', AccountId = inst.Id);
    insert pi;
  }

  private static UHN_AAR__c makeAAR() {
    Account inst = [
      SELECT Id
      FROM Account
      WHERE Name = 'Test Research Institute'
      LIMIT 1
    ];
    Contact pi = [SELECT Id FROM Contact WHERE LastName = 'TestPI' LIMIT 1];
    UHN_AAR__c aar = new UHN_AAR__c(
      Contact__c = pi.Id,
      Account__c = inst.Id,
      Review_Year__c = '2026',
      Institute__c = 'Krembil Research Institute'
    );
    insert aar;
    return aar;
  }

  private static AAR_Scholarly_Output__c makeOutput(
    Id aarId,
    Boolean isVerified,
    String status
  ) {
    Contact pi = [SELECT Id FROM Contact WHERE LastName = 'TestPI' LIMIT 1];
    return new AAR_Scholarly_Output__c(
      AAR_Record__c = aarId,
      Contact__c = pi.Id,
      Title__c = 'Test Output',
      Date__c = Date.today(),
      Is_Verified__c = isVerified,
      Verification_Status__c = status
    );
  }

  // Direction A: Is_Verified__c = true on insert → stamps Verified status + timestamps
  @IsTest
  static void insert_isVerifiedTrue_setsStatusVerifiedAndTimestamps() {
    UHN_AAR__c aar = makeAAR();

    Test.startTest();
    AAR_Scholarly_Output__c rec = makeOutput(aar.Id, true, null);
    insert rec;
    Test.stopTest();

    AAR_Scholarly_Output__c result = [
      SELECT Verification_Status__c, Verified_At__c, Verified_By__c
      FROM AAR_Scholarly_Output__c
      WHERE Id = :rec.Id
    ];
    System.assertEquals(
      'Verified',
      result.Verification_Status__c,
      'Status should be Verified'
    );
    System.assertNotEquals(
      null,
      result.Verified_At__c,
      'Verified_At__c should be stamped'
    );
    System.assertNotEquals(
      null,
      result.Verified_By__c,
      'Verified_By__c should be stamped'
    );
  }

  // Direction B: Verification_Status__c = Verified with Is_Verified__c = false on insert → mirrors Is_Verified__c to true
  @IsTest
  static void insert_statusVerifiedIsVerifiedFalse_mirrorsIsVerifiedTrue() {
    UHN_AAR__c aar = makeAAR();

    Test.startTest();
    AAR_Scholarly_Output__c rec = makeOutput(aar.Id, false, 'Verified');
    insert rec;
    Test.stopTest();

    AAR_Scholarly_Output__c result = [
      SELECT Is_Verified__c
      FROM AAR_Scholarly_Output__c
      WHERE Id = :rec.Id
    ];
    System.assertEquals(
      true,
      result.Is_Verified__c,
      'Is_Verified__c should mirror Verified status'
    );
  }

  // Direction B: Verification_Status__c = Proposed with Is_Verified__c = false on insert → no change
  @IsTest
  static void insert_statusProposedIsVerifiedFalse_noChange() {
    UHN_AAR__c aar = makeAAR();

    Test.startTest();
    AAR_Scholarly_Output__c rec = makeOutput(aar.Id, false, 'Proposed');
    insert rec;
    Test.stopTest();

    AAR_Scholarly_Output__c result = [
      SELECT Verification_Status__c, Is_Verified__c
      FROM AAR_Scholarly_Output__c
      WHERE Id = :rec.Id
    ];
    System.assertEquals(
      'Proposed',
      result.Verification_Status__c,
      'Status should remain Proposed'
    );
    System.assertEquals(
      false,
      result.Is_Verified__c,
      'Is_Verified__c should remain false'
    );
  }

  // Direction A update: Is_Verified__c changes to true → stamps status + timestamps
  @IsTest
  static void update_isVerifiedChangesToTrue_setsStatusAndTimestamps() {
    UHN_AAR__c aar = makeAAR();
    AAR_Scholarly_Output__c rec = makeOutput(aar.Id, false, 'Proposed');
    insert rec;

    Test.startTest();
    rec.Is_Verified__c = true;
    update rec;
    Test.stopTest();

    AAR_Scholarly_Output__c result = [
      SELECT Verification_Status__c, Verified_At__c, Verified_By__c
      FROM AAR_Scholarly_Output__c
      WHERE Id = :rec.Id
    ];
    System.assertEquals(
      'Verified',
      result.Verification_Status__c,
      'Status should be Verified after update'
    );
    System.assertNotEquals(
      null,
      result.Verified_At__c,
      'Verified_At__c should be stamped on update'
    );
    System.assertNotEquals(
      null,
      result.Verified_By__c,
      'Verified_By__c should be stamped on update'
    );
  }

  // Direction A update: Is_Verified__c changes to false → resets status to Proposed, clears timestamps
  @IsTest
  static void update_isVerifiedChangesToFalse_resetsStatusAndClearsTimestamps() {
    UHN_AAR__c aar = makeAAR();
    AAR_Scholarly_Output__c rec = makeOutput(aar.Id, true, null);
    insert rec;

    Test.startTest();
    rec = [
      SELECT Id, Is_Verified__c, Verification_Status__c
      FROM AAR_Scholarly_Output__c
      WHERE Id = :rec.Id
    ];
    rec.Is_Verified__c = false;
    update rec;
    Test.stopTest();

    AAR_Scholarly_Output__c result = [
      SELECT Verification_Status__c, Verified_At__c, Verified_By__c
      FROM AAR_Scholarly_Output__c
      WHERE Id = :rec.Id
    ];
    System.assertEquals(
      'Proposed',
      result.Verification_Status__c,
      'Status should reset to Proposed'
    );
    System.assertEquals(
      null,
      result.Verified_At__c,
      'Verified_At__c should be cleared'
    );
    System.assertEquals(
      null,
      result.Verified_By__c,
      'Verified_By__c should be cleared'
    );
  }

  // Direction B update: Verification_Status__c changes to Verified → Is_Verified__c mirrors to true
  @IsTest
  static void update_statusChangesToVerified_mirrorsIsVerifiedTrue() {
    UHN_AAR__c aar = makeAAR();
    AAR_Scholarly_Output__c rec = makeOutput(aar.Id, false, 'Proposed');
    insert rec;

    Test.startTest();
    rec.Verification_Status__c = 'Verified';
    update rec;
    Test.stopTest();

    AAR_Scholarly_Output__c result = [
      SELECT Is_Verified__c
      FROM AAR_Scholarly_Output__c
      WHERE Id = :rec.Id
    ];
    System.assertEquals(
      true,
      result.Is_Verified__c,
      'Is_Verified__c should mirror Verified status on update'
    );
  }

  // Direction B update: Verification_Status__c changes from Verified → Proposed → Is_Verified__c = false
  @IsTest
  static void update_statusChangesToProposed_clearsIsVerified() {
    UHN_AAR__c aar = makeAAR();
    AAR_Scholarly_Output__c rec = makeOutput(aar.Id, true, null);
    insert rec;

    // Re-query to get database state including trigger-set values
    rec = [
      SELECT Id, Is_Verified__c, Verification_Status__c
      FROM AAR_Scholarly_Output__c
      WHERE Id = :rec.Id
    ];

    Test.startTest();
    rec.Verification_Status__c = 'Proposed';
    update rec;
    Test.stopTest();

    AAR_Scholarly_Output__c result = [
      SELECT Is_Verified__c
      FROM AAR_Scholarly_Output__c
      WHERE Id = :rec.Id
    ];
    System.assertEquals(
      false,
      result.Is_Verified__c,
      'Is_Verified__c should be false when status changes to Proposed'
    );
  }

  // Bulk safety: 200 records, alternating Is_Verified__c
  @IsTest
  static void bulk_200Records_allSyncedCorrectly() {
    UHN_AAR__c aar = makeAAR();

    Contact pi = [SELECT Id FROM Contact WHERE LastName = 'TestPI' LIMIT 1];
    List<AAR_Scholarly_Output__c> batch = new List<AAR_Scholarly_Output__c>();
    for (Integer i = 0; i < 200; i++) {
      batch.add(
        new AAR_Scholarly_Output__c(
          AAR_Record__c = aar.Id,
          Contact__c = pi.Id,
          Title__c = 'Bulk Output ' + i,
          Date__c = Date.today(),
          Is_Verified__c = (Math.mod(i, 2) == 0),
          Verification_Status__c = 'Proposed'
        )
      );
    }

    Test.startTest();
    insert batch;
    Test.stopTest();

    Integer verifiedCount = [
      SELECT COUNT()
      FROM AAR_Scholarly_Output__c
      WHERE AAR_Record__c = :aar.Id AND Verification_Status__c = 'Verified'
    ];
    System.assertEquals(
      100,
      verifiedCount,
      '100 of 200 records should have Verified status'
    );
  }
}
