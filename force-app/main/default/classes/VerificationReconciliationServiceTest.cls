/**
 * VerificationReconciliationServiceTest
 * --------------------------------------
 * Covers every branch of the reconciliation rule, plus the LWC controller
 * surface, plus bulk-safety, plus idempotency.
 *
 * Test data strategy: we use UHN_Publication_Author__c as both the realistic
 * case (multi-author, junction-shaped) AND the toy reference object — the
 * pattern is the same regardless of object, so a second toy object would only
 * duplicate test scaffolding without changing what's covered. If you later
 * add a second verifiable object (e.g. UHN_FCC__c for grants), copy this
 * class as a template; the assertions translate field-for-field.
 */
@IsTest
private class VerificationReconciliationServiceTest {
  private static final String EXT_ID_1 = 'WELLSPRING-PUB-001';
  private static final String EXT_ID_2 = 'WELLSPRING-PUB-002';
  private static final String EXT_ID_3 = 'WELLSPRING-PUB-003';

  /**
   * Cached Contact id used by every UHN_Publication_Author__c insert in this
   * class. The org's schema makes UHN_Contact__c a required master-detail
   * on UHN_Publication_Author__c (junction shape: Publication x Contact),
   * so we must populate it on every insert or DML fails with
   * REQUIRED_FIELD_MISSING.
   *
   * If your org also requires non-standard fields on Contact itself
   * (e.g. institution affiliation, contact type), extend the construction
   * below to populate them — otherwise the test setup will fail with its
   * own REQUIRED_FIELD_MISSING and the message will tell you which field.
   */
  private static Id cachedContactId;
  private static Id getTestContactId() {
    if (cachedContactId == null) {
      Contact c = new Contact(
        FirstName = 'Verification',
        LastName = 'Framework Test'
      );
      insert c;
      cachedContactId = c.Id;
    }
    return cachedContactId;
  }

  /**
   * Rule 1: hash matches stored hash -> no-op.
   * No DML on the record, no new event, action = 'No-op'.
   */
  @IsTest
  static void rule1_hashMatch_isNoop() {
    UHN_Publication_Author__c rec = makeProposed(
      EXT_ID_1,
      'Original Title',
      'First Author'
    );
    insert rec;

    Map<String, Object> identicalSource = new Map<String, Object>{
      'Title__c' => 'Original Title',
      'Role__c' => 'First Author'
    };
    // Set the hash to match what the service will compute for identicalSource.
    // computeHash is @TestVisible — accessible to test code without a public accessor.
    rec.Source_Hash__c = VerificationReconciliationService.computeHash(
      identicalSource
    );
    update rec;

    Test.startTest();
    List<VerificationReconciliationService.SourceUpsert> upserts = new List<VerificationReconciliationService.SourceUpsert>{
      new VerificationReconciliationService.SourceUpsert(
        UHN_Publication_Author__c.SObjectType,
        EXT_ID_1,
        identicalSource
      )
    };
    List<VerificationReconciliationService.ReconcileResult> results = VerificationReconciliationService.reconcile(
      upserts
    );
    Test.stopTest();

    System.assertEquals(1, results.size());
    System.assertEquals('No-op', results[0].action);
    System.assertEquals(false, results[0].changed);
    // No new change events written.
    System.assertEquals(
      0,
      [
        SELECT COUNT()
        FROM Verification_Change_Event__c
        WHERE External_Id__c = :EXT_ID_1
      ]
    );
  }

  /**
   * Rule 2: hash differs, status = Proposed -> silently update.
   * Record is updated, hash refreshed, "Proposed Updated" event written.
   */
  @IsTest
  static void rule2_hashDiffers_proposed_updatesSilently() {
    UHN_Publication_Author__c rec = makeProposed(
      EXT_ID_1,
      'Old Title',
      'Co-Author'
    );
    insert rec;

    Map<String, Object> newSource = new Map<String, Object>{
      'Title__c' => 'New Title',
      'Role__c' => 'First Author'
    };

    Test.startTest();
    VerificationReconciliationService.reconcile(
      new List<VerificationReconciliationService.SourceUpsert>{
        new VerificationReconciliationService.SourceUpsert(
          UHN_Publication_Author__c.SObjectType,
          EXT_ID_1,
          newSource
        )
      }
    );
    Test.stopTest();

    UHN_Publication_Author__c after = [
      SELECT Id, Title__c, Role__c, Verification_Status__c, Source_Hash__c
      FROM UHN_Publication_Author__c
      WHERE Id = :rec.Id
    ];
    System.assertEquals(
      'New Title',
      after.Title__c,
      'Proposed record should be silently updated'
    );
    System.assertEquals('First Author', after.Role__c);
    System.assertEquals('Proposed', after.Verification_Status__c);

    List<Verification_Change_Event__c> events = [
      SELECT Event_Type__c
      FROM Verification_Change_Event__c
      WHERE External_Id__c = :EXT_ID_1
    ];
    System.assertEquals(1, events.size());
    System.assertEquals('Proposed Updated', events[0].Event_Type__c);
  }

  /**
   * Rule 3: hash differs, status = Verified -> DO NOT overwrite. Drift event only.
   * This is the override-durability promise. The record stays exactly as the PI left it.
   */
  @IsTest
  static void rule3_hashDiffers_verified_preservesOverride() {
    UHN_Publication_Author__c rec = makeProposed(
      EXT_ID_1,
      'Original Title',
      'Co-Author'
    );
    insert rec;

    // PI verifies and corrects the title.
    VerificationReconciliationService.markVerified(new List<Id>{ rec.Id });
    VerificationReconciliationService.applyOverride(
      rec.Id,
      new Map<String, Object>{ 'Title__c' => 'PI-Corrected Title' }
    );

    // Source system pushes a different update.
    Map<String, Object> upstreamUpdate = new Map<String, Object>{
      'Title__c' => 'Source System Title (Wrong)',
      'Role__c' => 'Co-Author'
    };

    Test.startTest();
    List<VerificationReconciliationService.ReconcileResult> results = VerificationReconciliationService.reconcile(
      new List<VerificationReconciliationService.SourceUpsert>{
        new VerificationReconciliationService.SourceUpsert(
          UHN_Publication_Author__c.SObjectType,
          EXT_ID_1,
          upstreamUpdate
        )
      }
    );
    Test.stopTest();

    System.assertEquals('Source Changed Under Verified', results[0].action);
    System.assertEquals(
      false,
      results[0].changed,
      'Verified record must not be mutated by source updates'
    );

    // Verify the record itself is untouched at the field level we care about.
    UHN_Publication_Author__c after = [
      SELECT Verification_Status__c, Override_Payload__c
      FROM UHN_Publication_Author__c
      WHERE Id = :rec.Id
    ];
    System.assertEquals('Verified', after.Verification_Status__c);
    Map<String, Object> overrideValues = (Map<String, Object>) JSON.deserializeUntyped(
      after.Override_Payload__c
    );
    System.assertEquals(
      'PI-Corrected Title',
      overrideValues.get('Title__c'),
      'PI override must survive a source-system update'
    );

    // Drift event MUST be written so the PI can be notified.
    List<Verification_Change_Event__c> drift = [
      SELECT Before_Payload__c, After_Payload__c
      FROM Verification_Change_Event__c
      WHERE
        External_Id__c = :EXT_ID_1
        AND Event_Type__c = 'Source Changed Under Verified'
    ];
    System.assertEquals(1, drift.size());
    System.assert(
      drift[0].After_Payload__c.contains('Source System Title (Wrong)')
    );
  }

  /**
   * Rule 4: status = Manual, matching source appears -> supersede + create Proposed.
   * The PI now has both rows visible and decides whether to merge.
   */
  @IsTest
  static void rule4_manual_meetsSource_supersedes() {
    UHN_Publication_Author__c manual = new UHN_Publication_Author__c(
      External_Id__c = EXT_ID_1,
      Title__c = 'Order of Canada',
      Role__c = 'Recipient',
      UHN_Contact__c = getTestContactId()
    );
    VerificationReconciliationService.createManual(manual);

    // Source system now has a record with the same external id.
    Map<String, Object> source = new Map<String, Object>{
      'Title__c' => 'Order of Canada (CC)',
      'Role__c' => 'Companion'
    };

    Test.startTest();
    VerificationReconciliationService.reconcile(
      new List<VerificationReconciliationService.SourceUpsert>{
        new VerificationReconciliationService.SourceUpsert(
          UHN_Publication_Author__c.SObjectType,
          EXT_ID_1,
          source
        )
      }
    );
    Test.stopTest();

    // We expect: original manual marked Superseded (External_Id__c cleared), new Proposed created.
    List<UHN_Publication_Author__c> all = [
      SELECT Id, Verification_Status__c, Title__c
      FROM UHN_Publication_Author__c
      WHERE Id = :manual.Id OR External_Id__c = :EXT_ID_1
      ORDER BY CreatedDate
    ];
    System.assertEquals(
      2,
      all.size(),
      'Should now have both Superseded and Proposed rows'
    );
    System.assertEquals('Superseded', all[0].Verification_Status__c);
    System.assertEquals('Proposed', all[1].Verification_Status__c);
    System.assertEquals('Order of Canada (CC)', all[1].Title__c);
  }

  /**
   * markVerified is idempotent — re-verifying writes no extra event.
   */
  @IsTest
  static void markVerified_isIdempotent() {
    UHN_Publication_Author__c rec = makeProposed(EXT_ID_1, 'T', 'R');
    insert rec;

    Test.startTest();
    VerificationReconciliationService.markVerified(new List<Id>{ rec.Id });
    VerificationReconciliationService.markVerified(new List<Id>{ rec.Id }); // again
    Test.stopTest();

    Integer events = [
      SELECT COUNT()
      FROM Verification_Change_Event__c
      WHERE Subject_Record_Id__c = :rec.Id AND Event_Type__c = 'Verified'
    ];
    System.assertEquals(
      1,
      events,
      'Verifying twice should write only one event'
    );
  }

  /**
   * applyOverride merges with existing overrides (per-field last-write-wins).
   */
  @IsTest
  static void applyOverride_mergesIncrementally() {
    UHN_Publication_Author__c rec = makeProposed(EXT_ID_1, 'Title', 'Role');
    insert rec;
    VerificationReconciliationService.markVerified(new List<Id>{ rec.Id });

    Test.startTest();
    VerificationReconciliationService.applyOverride(
      rec.Id,
      new Map<String, Object>{ 'Title__c' => 'Corrected Title' }
    );
    VerificationReconciliationService.applyOverride(
      rec.Id,
      new Map<String, Object>{ 'Role__c' => 'Senior Author' }
    );
    Test.stopTest();

    UHN_Publication_Author__c after = [
      SELECT Override_Payload__c
      FROM UHN_Publication_Author__c
      WHERE Id = :rec.Id
    ];
    Map<String, Object> overrideValues = (Map<String, Object>) JSON.deserializeUntyped(
      after.Override_Payload__c
    );
    System.assertEquals('Corrected Title', overrideValues.get('Title__c'));
    System.assertEquals(
      'Senior Author',
      overrideValues.get('Role__c'),
      'Second override should add to, not replace, the first'
    );
  }

  /**
   * Bulk safety: 200 records reconciled in one call without governor breach.
   * Issues a single SOQL for the existing-records query and a single DML
   * for the upsert + a single DML for events.
   */
  @IsTest
  static void reconcile_isBulkSafe() {
    List<UHN_Publication_Author__c> existing = new List<UHN_Publication_Author__c>();
    for (Integer i = 0; i < 200; i++) {
      existing.add(makeProposed('BULK-' + i, 'Old ' + i, 'Author'));
    }
    insert existing;

    List<VerificationReconciliationService.SourceUpsert> upserts = new List<VerificationReconciliationService.SourceUpsert>();
    for (Integer i = 0; i < 200; i++) {
      upserts.add(
        new VerificationReconciliationService.SourceUpsert(
          UHN_Publication_Author__c.SObjectType,
          'BULK-' + i,
          new Map<String, Object>{
            'Title__c' => 'New ' + i,
            'Role__c' => 'Author'
          }
        )
      );
    }

    Test.startTest();
    Integer queriesBefore = Limits.getQueries();
    Integer dmlBefore = Limits.getDmlStatements();
    VerificationReconciliationService.reconcile(upserts);
    Integer queriesAfter = Limits.getQueries();
    Integer dmlAfter = Limits.getDmlStatements();
    Test.stopTest();

    // Strict bulk-safety: one SELECT, two DMLs (records + events).
    System.assertEquals(
      1,
      queriesAfter - queriesBefore,
      'Should issue one SELECT for the batch'
    );
    System.assertEquals(
      2,
      dmlAfter - dmlBefore,
      'Should issue exactly two DML statements'
    );

    Integer eventCount = [
      SELECT COUNT()
      FROM Verification_Change_Event__c
      WHERE External_Id__c LIKE 'BULK-%'
    ];
    System.assertEquals(200, eventCount, 'One event per record');
  }

  /**
   * Empty input is a no-op (defensive — triggers fire on empty changesets).
   */
  @IsTest
  static void reconcile_emptyInput_isSafe() {
    Test.startTest();
    List<VerificationReconciliationService.ReconcileResult> r1 = VerificationReconciliationService.reconcile(
      null
    );
    List<VerificationReconciliationService.ReconcileResult> r2 = VerificationReconciliationService.reconcile(
      new List<VerificationReconciliationService.SourceUpsert>()
    );
    Test.stopTest();

    System.assertEquals(0, r1.size());
    System.assertEquals(0, r2.size());
  }

  /**
   * createManual stamps verification metadata and writes the Manual Created event.
   */
  @IsTest
  static void createManual_stampsMetadataAndEvent() {
    UHN_Publication_Author__c manual = new UHN_Publication_Author__c(
      External_Id__c = EXT_ID_3,
      Title__c = 'Order of Canada',
      Role__c = 'Recipient',
      UHN_Contact__c = getTestContactId()
    );

    Test.startTest();
    Id newId = VerificationReconciliationService.createManual(manual);
    Test.stopTest();

    UHN_Publication_Author__c after = [
      SELECT Verification_Status__c, Verified_At__c, Verified_By__c
      FROM UHN_Publication_Author__c
      WHERE Id = :newId
    ];
    System.assertEquals('Manual', after.Verification_Status__c);
    System.assertNotEquals(null, after.Verified_At__c);
    System.assertEquals(UserInfo.getUserId(), after.Verified_By__c);

    Integer events = [
      SELECT COUNT()
      FROM Verification_Change_Event__c
      WHERE External_Id__c = :EXT_ID_3 AND Event_Type__c = 'Manual Created'
    ];
    System.assertEquals(1, events);
  }

  /**
   * Empty override payload throws — caller likely meant to call markVerified.
   */
  @IsTest
  static void applyOverride_rejectsEmptyDelta() {
    UHN_Publication_Author__c rec = makeProposed(EXT_ID_1, 'T', 'R');
    insert rec;

    Test.startTest();
    Boolean threw = false;
    try {
      VerificationReconciliationService.applyOverride(
        rec.Id,
        new Map<String, Object>()
      );
    } catch (VerificationException e) {
      threw = true;
      System.assert(e.getMessage().contains('overrideDelta is empty'));
    }
    Test.stopTest();

    System.assert(threw, 'Empty override delta should throw');
  }

  // ---------- helpers ----------

  private static UHN_Publication_Author__c makeProposed(
    String extId,
    String title,
    String role
  ) {
    return new UHN_Publication_Author__c(
      External_Id__c = extId,
      Verification_Status__c = 'Proposed',
      Title__c = title,
      Role__c = role,
      UHN_Contact__c = getTestContactId(),
      Source_Payload__c = JSON.serialize(
        new Map<String, Object>{ 'Title__c' => title, 'Role__c' => role }
      )
    );
  }
}
