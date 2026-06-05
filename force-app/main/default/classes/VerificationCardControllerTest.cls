/**
 * VerificationCardControllerTest
 * ------------------------------
 * Coverage tests for VerificationCardController's @AuraEnabled methods.
 *
 * Intent: satisfy the 75% coverage gate while exercising as much real
 * behavior as the test environment permits. A full UI behavioral test
 * suite would belong with the LWC layer in Jest, not in Apex.
 *
 * Notes:
 *   - These tests assume the same UHN_Contact__c master-detail requirement
 *     on UHN_Publication_Author__c as the main service test class.
 *   - getCardData's happy-path coverage requires a Verification_Binding__mdt
 *     record and a field set on the target object. Test-time custom metadata
 *     setup is constrained on the platform, so the test exercises getCardData
 *     up to the point where the missing field set raises an exception. That
 *     still walks most of the method body.
 */
@IsTest
private class VerificationCardControllerTest {
  private static Id cachedContactId;

  private static Id getTestContactId() {
    if (cachedContactId == null) {
      Contact c = new Contact(LastName = 'CardCtrlTestContact');
      insert c;
      cachedContactId = c.Id;
    }
    return cachedContactId;
  }

  /**
   * Smoke test for verify(). Creates a Proposed record, marks it verified,
   * asserts the status transition.
   */
  @IsTest
  static void verify_marksRecordVerified() {
    UHN_Publication_Author__c rec = new UHN_Publication_Author__c(
      External_Id__c = 'CARDCTRL-001',
      Verification_Status__c = 'Proposed',
      UHN_Contact__c = getTestContactId(),
      Source_Payload__c = '{"Title__c":"Test"}'
    );
    insert rec;

    Test.startTest();
    VerificationCardController.verify(new List<Id>{ rec.Id });
    Test.stopTest();

    UHN_Publication_Author__c after = [
      SELECT Verification_Status__c
      FROM UHN_Publication_Author__c
      WHERE Id = :rec.Id
    ];
    System.assertEquals('Verified', after.Verification_Status__c);
  }

  /**
   * Test for overrideRecord(). Applies a JSON delta, asserts the record
   * was verified and the override payload is present.
   */
  @IsTest
  static void overrideRecord_appliesDeltaAndVerifies() {
    UHN_Publication_Author__c rec = new UHN_Publication_Author__c(
      External_Id__c = 'CARDCTRL-002',
      Verification_Status__c = 'Proposed',
      UHN_Contact__c = getTestContactId(),
      Source_Payload__c = '{"Title__c":"Original"}'
    );
    insert rec;

    String deltaJson = '{"Title__c":"PI Corrected"}';

    Test.startTest();
    VerificationCardController.overrideRecord(rec.Id, deltaJson);
    Test.stopTest();

    UHN_Publication_Author__c after = [
      SELECT Verification_Status__c, Override_Payload__c
      FROM UHN_Publication_Author__c
      WHERE Id = :rec.Id
    ];
    System.assertEquals('Verified', after.Verification_Status__c);
    System.assert(
      after.Override_Payload__c != null &&
      after.Override_Payload__c.contains('PI Corrected'),
      'Override payload should contain the corrected value'
    );
  }

  /**
   * overrideRecord rejects blank JSON. Covers the validation guard.
   */
  @IsTest
  static void overrideRecord_rejectsBlankJson() {
    UHN_Publication_Author__c rec = new UHN_Publication_Author__c(
      External_Id__c = 'CARDCTRL-003',
      Verification_Status__c = 'Proposed',
      UHN_Contact__c = getTestContactId()
    );
    insert rec;

    Boolean threw = false;
    try {
      VerificationCardController.overrideRecord(rec.Id, '');
    } catch (VerificationException e) {
      threw = true;
    }
    System.assert(
      threw,
      'Blank overrideJson should raise VerificationException'
    );
  }

  /**
   * overrideRecord with malformed JSON — exercises the JSON parsing path
   * indirectly. Whether the service rejects or accepts an empty-map result
   * doesn't matter for coverage; the line that does the parse is reached.
   */
  @IsTest
  static void overrideRecord_handlesMalformedJson() {
    UHN_Publication_Author__c rec = new UHN_Publication_Author__c(
      External_Id__c = 'CARDCTRL-004',
      Verification_Status__c = 'Proposed',
      UHN_Contact__c = getTestContactId()
    );
    insert rec;

    // Malformed but non-blank JSON. The controller's JSON parse will throw.
    Boolean threw = false;
    try {
      VerificationCardController.overrideRecord(rec.Id, '{not json}');
    } catch (Exception e) {
      threw = true;
    }
    System.assert(threw, 'Malformed JSON should raise');
  }

  /**
   * rejectRecord — happy path. Creates a Proposed record, rejects it with a
   * reason, asserts a Verification_Change_Event__c of type 'Rejected' was written.
   * Excluded__c is not asserted here because the field is optional (framework
   * degrades gracefully on objects that haven't added it yet).
   */
  @IsTest
  static void rejectRecord_writesChangeEvent() {
    UHN_Publication_Author__c rec = new UHN_Publication_Author__c(
      External_Id__c = 'CARDCTRL-REJ-001',
      Verification_Status__c = 'Proposed',
      UHN_Contact__c = getTestContactId(),
      Source_Payload__c = '{"Title__c":"To Reject"}'
    );
    insert rec;

    Test.startTest();
    VerificationCardController.rejectRecord(rec.Id, 'Duplicate');
    Test.stopTest();

    List<Verification_Change_Event__c> events = [
      SELECT Event_Type__c
      FROM Verification_Change_Event__c
      WHERE External_Id__c = 'CARDCTRL-REJ-001'
      ORDER BY Occurred_At__c DESC
      LIMIT 1
    ];
    System.assertEquals(1, events.size(), 'Expected one Rejected change event');
    System.assertEquals(
      'Rejected',
      events[0].Event_Type__c,
      'Event type should be Rejected'
    );
  }

  /**
   * rejectRecord with null recordId — covers the null-guard.
   */
  @IsTest
  static void rejectRecord_nullIdRaises() {
    Boolean threw = false;
    try {
      VerificationCardController.rejectRecord(null, 'No reason');
    } catch (VerificationException e) {
      threw = true;
    }
    System.assert(threw, 'null recordId should raise VerificationException');
  }

  /**
   * getCardData with null parentRecordId — covers the input validation guard.
   */
  @IsTest
  static void getCardData_nullParentRaises() {
    Boolean threw = false;
    try {
      VerificationCardController.getCardData(
        null,
        'UHN_Publication_Author__c',
        'AAR_Verification'
      );
    } catch (VerificationException e) {
      threw = true;
    }
    System.assert(threw, 'null parent should raise VerificationException');
  }

  /**
   * getCardData with blank childObjectApiName — covers the input validation.
   */
  @IsTest
  static void getCardData_blankChildObjectRaises() {
    Boolean threw = false;
    try {
      VerificationCardController.getCardData(
        getTestContactId(),
        '',
        'AAR_Verification'
      );
    } catch (VerificationException e) {
      threw = true;
    }
    System.assert(
      threw,
      'blank child object should raise VerificationException'
    );
  }

  /**
   * getCardData with a real object and field set name that doesn't exist —
   * exercises the type resolution, accessibility check, binding lookup,
   * and falls through to the field set "not found" exception. Covers most
   * of the method body without needing test-time custom metadata setup.
   */
  @IsTest
  static void getCardData_walksMethodBodyUntilMissingFieldSet() {
    Boolean threw = false;
    try {
      VerificationCardController.getCardData(
        getTestContactId(),
        'UHN_Publication_Author__c',
        'NonExistentFieldSet_For_Testing_Only'
      );
    } catch (Exception e) {
      // Expected — the field set won't exist in the test context.
      // The exception path covers resolveFieldSet's "throw with useful
      // message" branch as well.
      threw = true;
    }
    System.assert(threw, 'Missing field set should raise');
  }

  /**
   * getCardData happy path. Uses the AAR_Verification field set and
   * Verification_Binding.Publication_Author binding record that ship with
   * the package, so the controller can resolve the parent lookup field
   * (UHN_Contact__c), build the SOQL, query rows, and return CardData.
   *
   * This covers buildRow, parseJsonSafe, and the success branches of
   * resolveFieldSet and resolveParentLookupField.
   */
  @IsTest
  static void getCardData_happyPathReturnsRows() {
    Id contactId = getTestContactId();

    // Seed two rows on the object — one Proposed, one Verified — both
    // children of the same Contact.
    UHN_Publication_Author__c proposed = new UHN_Publication_Author__c(
      External_Id__c = 'CARDCTRL-HAPPY-001',
      Verification_Status__c = 'Proposed',
      UHN_Contact__c = contactId,
      Source_Payload__c = '{"Title__c":"Some Title"}'
    );
    UHN_Publication_Author__c verified = new UHN_Publication_Author__c(
      External_Id__c = 'CARDCTRL-HAPPY-002',
      Verification_Status__c = 'Verified',
      UHN_Contact__c = contactId,
      Source_Payload__c = '{"Title__c":"Verified Title"}',
      Override_Payload__c = '{"Title__c":"PI Override"}',
      Verified_At__c = System.now(),
      Verified_By__c = UserInfo.getUserId()
    );
    insert new List<UHN_Publication_Author__c>{ proposed, verified };

    Test.startTest();
    VerificationCardController.CardData data = VerificationCardController.getCardData(
      contactId,
      'UHN_Publication_Author__c',
      'AAR_Verification'
    );
    Test.stopTest();

    System.assertNotEquals(null, data, 'CardData should be returned');
    System.assertNotEquals(null, data.fields, 'fields list should be present');
    System.assertNotEquals(null, data.rows, 'rows list should be present');
    System.assertEquals(2, data.rows.size(), 'Should return both seeded rows');
  }
}
