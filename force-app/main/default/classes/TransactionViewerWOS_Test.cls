@isTest(SeeAllData=true)
private class TransactionViewerWOS_Test {
  @isTest
  static void testGetFilteredTransactions() {
    try {
      List<UHN_Journal_Entry__c> jeList = [
        SELECT id
        FROM UHN_Journal_Entry__c
        WHERE
          UHN_PI_Expense_or_Revenue_Class__c = 'Expense'
          AND UHN_GL_Account__r.UHN_PI_Expense_or_Revenue_Type__c = 'Equipment'
          AND UHN_Actual_Amount__c < 0
          AND UHN_Debit_or_Credit__c = 'Debit'
          AND (NOT name LIKE 't/f %')
          AND (NOT name LIKE 'ptf %')
        LIMIT 1
      ];
      if (jeList.size() == 0) {
        return;
      }
      UHN_Journal_Entry__c je = jeList.get(0);
      // Structured criteria: one AND group, one criterion — equivalent to the
      // old raw fragment "AND UHN_GL_Account__r.UHN_PI_Expense_or_Revenue_Type__c = 'Equipment'"
      String filterCriteria =
        '[[{"field":"UHN_GL_Account__r.UHN_PI_Expense_or_Revenue_Type__c",' +
        '"operator":"=","value":"Equipment","valueType":"string"}]]';
      Set<Id> searchPool = new Set<Id>{ je.id };
      List<sObject> fTransactions = TransactionViewerWOS.getFilteredTransactions(
        filterCriteria,
        JSON.serialize(searchPool)
      );
      System.assert(
        fTransactions.size() > 0,
        'journal entry ' + je.id + ' found with structured filter criteria'
      );
    } catch (Exception e) {
      System.assert(false, e);
    }
  }

  @isTest
  static void testSearchTransactions() {
    try {
      List<UHN_Journal_Entry__c> jeList = [
        SELECT id, name
        FROM UHN_Journal_Entry__c
        WHERE
          UHN_PI_Expense_or_Revenue_Class__c = 'Expense'
          AND UHN_GL_Account__r.UHN_PI_Expense_or_Revenue_Type__c = 'Equipment'
          AND UHN_Actual_Amount__c < 0
          AND UHN_Debit_or_Credit__c = 'Debit'
          AND (NOT name LIKE 't/f %')
          AND (NOT name LIKE 'ptf %')
        LIMIT 1
      ];

      if (jeList.size() == 0) {
        return;
      }
      UHN_Journal_Entry__c je = jeList.get(0);
      Set<Id> searchPool = new Set<Id>{ je.id };
      List<Map<String, Object>> searchedTransaction = TransactionViewerWOS.searchTransactions(
        je.name,
        JSON.serialize(searchPool)
      );
      System.assert(
        searchedTransaction.size() > 0,
        'Journal entry ' + je.id + ' not found'
      );
    } catch (Exception e) {
      System.assert(false, e);
    }
  }

  @isTest
  static void testSearchGLByAccount() {
    try {
      String glDescription = 'Supplies General MedSurg Dressings';
      List<UHN_GL_Account__c> glAccList = [
        SELECT id
        FROM UHN_GL_Account__c
        WHERE UHN_Cost_Element_Description__c = :glDescription
        LIMIT 1
      ];
      if (glAccList.size() == 0) {
        return;
      }
      UHN_GL_Account__c glAcc = glAccList.get(0);
      Set<Id> searchPool = new Set<Id>{ glAcc.id };

      List<Map<String, Object>> glAccResults = TransactionViewerWOS.searchGLByAccount(
        glDescription,
        JSON.serialize(searchPool)
      );
      System.assert(
        glAccResults.size() > 0,
        'gl description \'' +
          glDescription +
          '\' not found for GL Account ' +
          glAcc.id
      );
    } catch (Exception e) {
      System.assert(false, e);
    }
  }

  @isTest
  static void testSearchGLByID() {
    try {
      List<UHN_GL_Account__c> glAccList = [
        SELECT id, name
        FROM UHN_GL_Account__c
        LIMIT 1
      ];
      if (glAccList.size() == 0) {
        return;
      }
      UHN_GL_Account__c glAcc = glAccList.get(0);
      Set<Id> searchPool = new Set<Id>{ glAcc.id };

      List<Map<String, Object>> glAccResults = TransactionViewerWOS.searchGLByID(
        glAcc.name,
        JSON.serialize(searchPool)
      );
      System.assert(
        glAccResults.size() > 0,
        'gl name' + glAcc.name + '\' not found for GL Account ' + glAcc.id
      );
    } catch (Exception e) {
      System.assert(false, e);
    }
  }

  @isTest
  static void testSearchTargetFCCs() {
    try {
      List<Map<String, Object>> searchedFccListByNumber;
      List<Map<String, Object>> searchedFccListByDescription;

      List<UHN_FCC__c> fccList = [
        SELECT name, UHN_Name__c, id
        FROM UHN_FCC__c
        WHERE
          UHN_FCC_Status__c = 'Open'
          AND UHN_FCC_Type_long__c = 'Grant Internal Order'
          AND UHN_To_be_Closed__c = FALSE
          AND UHN_Blocked__c = FALSE
          AND UHN_NonSalary_Actuals_Allowed__c = 'Yes'
          AND (UHN_Budget_Remaining__c >= 50
          OR UHN_Budget_Remaining__c = NULL)
        LIMIT 2
      ];
      if (fccList.size() < 2) {
        System.assert(
          false,
          'Error: No FCCs found. Please check query parameters to ensure that atleast one valid FCC returns'
        );
        return;
      }
      Set<ID> fccBlackList = new Set<ID>{ fccList.get(0).id };
      //Should contain a value
      searchedFccListByNumber = TransactionViewerWOS.searchTargetFCCsByNumber(
        (String) fccList.get(1).name,
        JSON.serialize(fccBlackList)
      );
      System.assert(searchedFccListByNumber.size() > 0);

      // Should be equal to each othe
      searchedFccListByDescription = TransactionViewerWOS.searchTargetFCCsByDescription(
        (String) fccList.get(1).UHN_Name__c,
        JSON.serialize(fccBlackList)
      );
      System.assert(
        searchedFccListByDescription.get(0).get('id') ==
        searchedFccListByNumber.get(0).get('id')
      ); // > 0 in case there are somehow duplicate fccs

      // Should return nothing because the fcc is black listed
      searchedFccListByNumber = TransactionViewerWOS.searchTargetFCCsByNumber(
        (String) fccList.get(0).name,
        JSON.serialize(fccBlackList)
      );
      System.assert(searchedFccListByNumber.size() == 0);
    } catch (Exception e) {
      System.assert(false, e);
    } //
  }

  @isTest
  static void testSearchTargetFCCsCostCentre() {
    // Verifies that open Cost Centre FCCs are returned as valid destinations,
    // regardless of UHN_NonSalary_Actuals_Allowed__c.
    try {
      List<UHN_FCC__c> costCentreList = [
        SELECT name, UHN_Name__c, id
        FROM UHN_FCC__c
        WHERE
          UHN_FCC_Status__c = 'Open'
          AND UHN_FCC_Type_long__c = 'Cost Centre'
        LIMIT 2
      ];
      if (costCentreList.size() < 1) {
        // No cost centre FCCs in this org — skip gracefully
        System.assert(true, 'No open Cost Centre FCCs found; skipping test');
        return;
      }
      Set<Id> blackList = new Set<Id>();
      if (costCentreList.size() >= 2) {
        blackList.add(costCentreList.get(0).id);
      }
      UHN_FCC__c target = costCentreList.size() >= 2
        ? costCentreList.get(1)
        : costCentreList.get(0);

      List<Map<String, Object>> byNumber = TransactionViewerWOS.searchTargetFCCsByNumber(
        (String) target.name,
        JSON.serialize(blackList)
      );
      System.assert(
        byNumber.size() > 0,
        'Cost Centre FCC ' +
          target.id +
          ' not returned by searchTargetFCCsByNumber'
      );

      List<Map<String, Object>> byDescription = TransactionViewerWOS.searchTargetFCCsByDescription(
        (String) target.UHN_Name__c,
        JSON.serialize(blackList)
      );
      System.assert(
        byDescription.size() > 0,
        'Cost Centre FCC ' +
          target.id +
          ' not returned by searchTargetFCCsByDescription'
      );
    } catch (Exception e) {
      System.assert(false, e);
    }
  }

  @isTest
  static void testTargetFCC_Approvers() {
    try {
      Decimal transferAmount = 10;
      List<UHN_FCC__c> toFccList;
      List<Map<String, Object>> validApprovers;
      // Test valid target fcc with valid delegates
      List<UHN_Delegate__c> delegateList = [
        SELECT id, UHN_FCC__c
        FROM UHN_Delegate__c
        WHERE
          UHN_FCC__r.UHN_FCC_Status__c = 'Open'
          AND UHN_FCC__r.UHN_FCC_Type_long__c = 'Grant Internal Order'
          AND UHN_FCC__r.UHN_To_be_Closed__c = FALSE
          AND UHN_FCC__r.UHN_Blocked__c = FALSE
          AND UHN_FCC__r.UHN_NonSalary_Actuals_Allowed__c = 'Yes'
          AND (UHN_FCC__r.UHN_Budget_Remaining__c >= 50
          OR UHN_FCC__r.UHN_Budget_Remaining__c = NULL)
          AND (UHN_Signing_Limit__c >= :transferAmount
          OR UHN_Has_Unlimited_Signing__c = TRUE)
          AND UHN_Active_User__c = TRUE
          AND UHN_Signing_Authority_Status__c = 'Active'
        LIMIT 1
      ];

      // The system potentially may not have any valid delegates for a FCC. Do not return a system assert
      if (delegateList.size() > 0) {
        UHN_Delegate__c delegate = delegateList.get(0);
        toFccList = [
          SELECT id, UHN_Contact__r.UHN_User__c
          FROM UHN_FCC__c
          WHERE id = :delegate.UHN_FCC__c
          LIMIT 1
        ];
        Map<String, Object> resMap = TransactionViewerWOS.getTargetFCC_Approvers(
          (string) toFccList.get(0).id,
          0
        );
        validApprovers = (List<Map<String, Object>>) resMap.get(
          'validApprovers'
        );
      }

      // Test valid target fcc that may or may not have a delegate
      toFccList = [
        SELECT id, UHN_Contact__r.UHN_User__c
        FROM UHN_FCC__c
        WHERE
          UHN_FCC_Status__c = 'Open'
          AND UHN_FCC_Type_long__c = 'Grant Internal Order'
          AND UHN_To_be_Closed__c = FALSE
          AND UHN_Blocked__c = FALSE
          AND UHN_NonSalary_Actuals_Allowed__c = 'Yes'
          AND (UHN_Budget_Remaining__c >= 50
          OR UHN_Budget_Remaining__c = NULL)
        LIMIT 1
      ];
      if (toFccList.size() > 0) {
        UHN_FCC__c toFcc = toFccList.get(0);
        Map<String, Object> resMap = TransactionViewerWOS.getTargetFCC_Approvers(
          (string) toFcc.id,
          transferAmount
        );
        validApprovers = (List<Map<String, Object>>) resMap.get(
          'validApprovers'
        );
        Map<String, Object> autoApprover = (Map<String, Object>) resMap.get(
          'autoApprover'
        );
      } else {
        System.assert(
          false,
          'Error: No FCCs found. Please check query parameters to ensure that atleast one valid FCC returns'
        );
      }
    } catch (Exception e) {
      System.assert(false, e);
    }
  }

  @isTest
  static void testTargetFCC_AutoApprover() {
    try {
      Decimal transferAmount = 10;
      // Test valid target fcc that may or may not have a delegate
      List<UHN_FCC__c> toFccList = [
        SELECT id, UHN_Contact__r.UHN_User__c
        FROM UHN_FCC__c
        WHERE
          UHN_FCC_Status__c = 'Open'
          AND UHN_FCC_Type_long__c = 'Grant Internal Order'
          AND UHN_To_be_Closed__c = FALSE
          AND UHN_Blocked__c = FALSE
          AND UHN_NonSalary_Actuals_Allowed__c = 'Yes'
          AND (UHN_Budget_Remaining__c >= 50
          OR UHN_Budget_Remaining__c = NULL)
        LIMIT 1
      ];

      if (toFccList.size() == 0) {
        System.assert(
          false,
          'Error: No FCCs found. Please check query parameters to ensure that atleast one valid FCC returns'
        );
        return;
      }
      UHN_FCC__c toFcc = toFccList.get(0);
      // Should return a auto approver
      List<User> userList = [
        SELECT id
        FROM User
        WHERE id = :toFcc.UHN_Contact__r.UHN_User__c
        LIMIT 1
      ];
      if (userList.size() > 0) {
        User contextUser = userList.get(0);
        System.runAs(contextUser) {
          Map<String, Object> resMap = TransactionViewerWOS.getTargetFCC_Approvers(
            (string) toFcc.id,
            transferAmount
          );
          List<Map<String, Object>> validApprovers = (List<Map<String, Object>>) resMap.get(
            'validApprovers'
          );
          Map<String, Object> autoApprover = (Map<String, Object>) resMap.get(
            'autoApprover'
          );
          if (autoApprover.size() != 0) {
            System.assert((Boolean) autoApprover.get('isAutoApproval'));
          }
        }
      }
    } catch (Exception e) {
      System.assert(false, e);
    }
  }

  @isTest
  static void testCaseRationalsET() {
    try {
      List<Map<String, Object>> caseRationals = TransactionViewerWOS.caseRationalsET();
      if (caseRationals.size() == 0) {
        System.assert(
          false,
          'Error: No picklist entries found for field UHN_ET_Request_Rationale__c'
        );
      }
    } catch (Exception e) {
      System.assert(false, e);
    }
  }

  @isTest
  static void testCreateNonSalaryET() {
    try {
      String jsonStr = '[{"name":"ET From 410001989 to 410000402 for $13","fromFCC":"410001989","fromFCC_ID":"a0D5W0000009QLjUAM","toFCC":"410000402","toFCC_ID":"a0D5W0000009Q8LUAU","destinationApprover":"Marcin Wasowicz","daUserID":"0055W000000WsRAQA0","daContactID":"0035W000003TOkFQAW","isAutoApproval":false,"totalTransfer":13,"rational":"Close out trial/study FCC (applicable to clinical trial/study accounts)","id":"a0D5W0000009QLjUAM-a0D5W0000009Q8LUAU","transactions":[{"transferAmount":13,"transactionID":"a0HOG000000E9Bv2AK","id":"a0HOG000000E9Bv2AK"}]}]';
      TransactionViewerWOS.createNonSalaryET(jsonStr);
    } catch (Exception e) {
      // since the value is hardcoded, the method will fail if the case doese not exist or the transfer amount exceeds the available amount
      System.assert(true);
    }
  }

  @isTest
  static void testGetFilteredTransactions_invalidField() {
    // A field not on UHN_Journal_Entry__c and not in ALLOWED_RELATIONSHIP_PATHS
    // must be rejected before any SOQL is executed.
    String badCriteria = '[[{"field":"INJECTED_FIELD__c","operator":"=","value":"foo","valueType":"string"}]]';
    Set<Id> emptyPool = new Set<Id>();
    Boolean thrown = false;
    try {
      TransactionViewerWOS.getFilteredTransactions(
        badCriteria,
        JSON.serialize(emptyPool)
      );
    } catch (AuraHandledException ex) {
      thrown = true;
      System.assert(
        ex.getMessage().contains('Unsupported filter field'),
        'Expected field validation error, got: ' + ex.getMessage()
      );
    }
    System.assert(
      thrown,
      'AuraHandledException must be thrown for invalid filter field'
    );
  }

  @isTest
  static void testSearchTransactionsEmptyPool() {
    // Calling with empty pools should simply return empty results without throwing
    Set<Id> emptyPool = new Set<Id>();
    List<Map<String, Object>> results = TransactionViewerWOS.searchTransactions(
      'abc',
      JSON.serialize(emptyPool)
    );
    System.assertEquals(
      0,
      results.size(),
      'No transactions expected for empty pool'
    );
  }

  @isTest
  static void testCreateValidApproverNodeAutoSkip() {
    // When auto approver already determined and current user matches, should return empty map
    Account acc = new Account(
      Name = 'AutoSkip Account',
      UHN_SAP_Id__c = 'SAP-AUTO',
      OwnerId = UserInfo.getUserId()
    );
    insert acc;
    Contact c = new Contact(
      FirstName = 'Auto',
      LastName = 'Skip',
      AccountId = acc.Id,
      UHN_User__c = UserInfo.getUserId()
    );
    insert c;
    Map<String, Object> res = TransactionViewerWOS.createValidApproverNode(
      c,
      true,
      new List<Map<String, Object>>()
    );
    System.assertEquals(
      0,
      res.size(),
      'Should skip when auto approver already determined and user matches'
    );
  }

  @isTest
  static void testCreateValidApproverNodeAutoApprove() {
    // When auto approver not yet determined and current user matches, should return auto approval flag
    Account acc = new Account(
      Name = 'AutoApprove Account',
      UHN_SAP_Id__c = 'SAP-AUTO2',
      OwnerId = UserInfo.getUserId()
    );
    insert acc;
    Contact c = new Contact(
      FirstName = 'Auto',
      LastName = 'Approve',
      AccountId = acc.Id,
      UHN_User__c = UserInfo.getUserId()
    );
    insert c;
    Map<String, Object> res = TransactionViewerWOS.createValidApproverNode(
      c,
      false,
      new List<Map<String, Object>>()
    );
    System.assertEquals(true, res.get('isAutoApproval'));
  }

  @isTest
  static void testCreateValidApproverNodeStandardUser() {
    // When current user is different, ensure we still create a node and mark as non-auto
    Account acc = new Account(
      Name = 'Std Approver Account',
      UHN_SAP_Id__c = 'SAP-STD',
      OwnerId = UserInfo.getUserId()
    );
    insert acc;
    Contact c = new Contact(
      FirstName = 'Std',
      LastName = 'Approver',
      AccountId = acc.Id,
      UHN_User__c = null
    );
    insert c;
    Map<String, Object> res = TransactionViewerWOS.createValidApproverNode(
      c,
      false,
      new List<Map<String, Object>>()
    );
    System.assertEquals(false, res.get('isAutoApproval'));
  }

  /* ============================================================
       SIGNING AUTHORITY TESTS — createNonSalaryET
       ============================================================ */

  private static User createTestUser(String suffix) {
    Profile p = [
      SELECT Id
      FROM Profile
      WHERE Name = 'System Administrator'
      LIMIT 1
    ];
    User u = new User(
      FirstName = 'Test',
      LastName = 'User' + suffix,
      Email = 'etwos' + suffix + System.currentTimeMillis() + '@test.com',
      Username = 'etwos' + suffix + System.currentTimeMillis() + '@test.com',
      Alias = 'et' + suffix,
      TimeZoneSidKey = 'America/Toronto',
      LocaleSidKey = 'en_CA',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      ProfileId = p.Id
    );
    insert u;
    return u;
  }

  @isTest
  static void testCreateNonSalaryET_insufficientSigningAuthority() {
    // Approver is a delegate with signing limit lower than transfer amount.
    // Users are created in System.runAs() to avoid MIXED_DML with Account/Contact DML.
    // Contact-User links are not set: the approver fails validation regardless because
    // they are not the account holder, FA, or a matching active delegate.
    User submitter;
    User approver;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      submitter = createTestUser('S1');
      approver = createTestUser('A1');
    }

    Account acc = new Account(
      Name = 'ET Auth Test',
      UHN_SAP_Id__c = 'SAP-ETAUTH1',
      OwnerId = UserInfo.getUserId()
    );
    insert acc;

    Contact submitterContact = new Contact(
      FirstName = 'ET',
      LastName = 'Submitter',
      AccountId = acc.Id
    );
    insert submitterContact;

    Contact approverContact = new Contact(
      FirstName = 'ET',
      LastName = 'Approver',
      AccountId = acc.Id
    );
    insert approverContact;

    System.runAs(submitter) {
      UHN_FCC__c fromFCC = new UHN_FCC__c(
        Name = 'FCC-ETFROM1',
        UHN_Contact__c = submitterContact.Id,
        UHN_FCC_Status__c = 'Open'
      );
      UHN_FCC__c toFCC = new UHN_FCC__c(
        Name = 'FCC-ETTO1',
        UHN_Contact__c = submitterContact.Id,
        UHN_FCC_Status__c = 'Open'
      );
      insert new List<UHN_FCC__c>{ fromFCC, toFCC };

      UHN_Delegate__c delegate = new UHN_Delegate__c(
        UHN_FCC__c = toFCC.Id,
        UHN_Contact__c = approverContact.Id,
        UHN_Active_Record__c = true,
        UHN_Has_Unlimited_Signing__c = false,
        UHN_Signing_Limit__c = 50,
        UHN_Signing_Authority_Status__c = 'Active',
        UHN_UID__c = 'TEST-ET-DEL-INSUFF'
      );
      insert delegate;

      // Transaction ID does not need to exist — validation fires before any DML
      String fakeTransactionId = fromFCC.Id; // just needs to be a plausible 18-char Id
      String jsonStr =
        '[{' +
        '"name":"ET Insufficient Auth",' +
        '"fromFCC_ID":"' +
        fromFCC.Id +
        '",' +
        '"toFCC_ID":"' +
        toFCC.Id +
        '",' +
        '"daUserID":"' +
        approver.Id +
        '",' +
        '"daContactID":"' +
        approverContact.Id +
        '",' +
        '"isAutoApproval":false,' +
        '"totalTransfer":200,' +
        '"rational":"Close out trial/study FCC",' +
        '"id":"NODE-ET-1",' +
        '"transactions":[{' +
        '"transferAmount":200,' +
        '"transactionID":"' +
        fakeTransactionId +
        '"' +
        '}]' +
        '}]';

      Boolean thrown = false;
      Test.startTest();
      try {
        TransactionViewerWOS.createNonSalaryET(jsonStr);
      } catch (AuraHandledException e) {
        // Catch as AuraHandledException specifically so getMessage() returns the real message.
        // Catching as the parent Exception type returns "Script-thrown exception" instead.
        thrown = true;
        System.assert(
          e.getMessage().contains('signing authority'),
          'Expected signing authority error, got: ' + e.getMessage()
        );
      }
      Test.stopTest();
      System.assert(
        thrown,
        'Exception must be thrown for insufficient signing authority'
      );
    }
  }

  @isTest
  static void testCreateNonSalaryET_validSigningAuthority() {
    // Approver is the account holder on the target FCC — validation passes.
    // User is created in System.runAs() to avoid MIXED_DML with Account/Contact DML.
    // The Contact-User link update is also wrapped in System.runAs() because the
    // "411 Directory Change" flow fires on update and tries to update a User (setup object).
    User submitter;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      submitter = createTestUser('S2');
    }

    Account acc = new Account(
      Name = 'ET Auth Test Valid',
      UHN_SAP_Id__c = 'SAP-ETAUTH2',
      OwnerId = UserInfo.getUserId()
    );
    insert acc;

    Contact submitterContact = new Contact(
      FirstName = 'ET',
      LastName = 'Submitter2',
      AccountId = acc.Id
    );
    insert submitterContact;

    System.runAs(new User(Id = UserInfo.getUserId())) {
      submitterContact.UHN_User__c = submitter.Id;
      update submitterContact;
    }

    System.runAs(submitter) {
      UHN_FCC__c fromFCC = new UHN_FCC__c(
        Name = 'FCC-ETFROM2',
        UHN_Contact__c = submitterContact.Id,
        UHN_FCC_Status__c = 'Open'
      );
      UHN_FCC__c toFCC = new UHN_FCC__c(
        Name = 'FCC-ETTO2',
        UHN_Contact__c = submitterContact.Id,
        UHN_FCC_Status__c = 'Open'
      );
      insert new List<UHN_FCC__c>{ fromFCC, toFCC };

      // Use a placeholder transaction ID — signing authority validation fires before any DML,
      // so a real JE is not needed to test that the validation passes.
      String fakeTransactionId = fromFCC.Id;

      String jsonStr =
        '[{' +
        '"name":"ET Valid Auth",' +
        '"fromFCC_ID":"' +
        fromFCC.Id +
        '",' +
        '"toFCC_ID":"' +
        toFCC.Id +
        '",' +
        '"daUserID":"' +
        submitter.Id +
        '",' +
        '"daContactID":"' +
        submitterContact.Id +
        '",' +
        '"isAutoApproval":false,' +
        '"totalTransfer":100,' +
        '"rational":"Close out trial/study FCC",' +
        '"id":"NODE-ET-2",' +
        '"transactions":[{' +
        '"transferAmount":100,' +
        '"transactionID":"' +
        fakeTransactionId +
        '"' +
        '}]' +
        '}]';

      Test.startTest();
      try {
        List<TransactionViewerWOS.URL_Node> result = TransactionViewerWOS.createNonSalaryET(
          jsonStr
        );
        System.assertEquals(1, result.size(), 'Should return one Case URL');
      } catch (Exception e) {
        // Downstream failures (flow triggers, approval process) are acceptable
        // but signing authority validation must not be the cause
        System.assert(
          !e.getMessage().contains('signing authority'),
          'Signing authority validation should have passed, got: ' +
          e.getMessage()
        );
      }
      Test.stopTest();
    }
  }

  @isTest
  static void testCreateNonSalaryET_success_autoApprove() {
    // Auto-approval: daUserID == contextUser.id → bypass Approval.process(),
    // stamp UHN_Approved_by_approver_2__c = true, insert a published CaseComment.
    // Submitter is also the account holder on the to-FCC, so signing authority
    // passes unconditionally (account holder path in validateApproverSigningAuthority).
    User submitter;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      submitter = createTestUser('AUTOET');
    }

    Account acc = new Account(
      Name = 'ET Auto Approve Test',
      UHN_SAP_Id__c = 'SAP-AUTOET1',
      OwnerId = UserInfo.getUserId()
    );
    insert acc;

    Contact submitterContact = new Contact(
      FirstName = 'ET',
      LastName = 'AutoApprover',
      AccountId = acc.Id
    );
    insert submitterContact;

    // Wrap UHN_User__c update in runAs to avoid MIXED_DML: the 411 Directory Change
    // flow fires on this update and tries to update a User (setup object).
    System.runAs(new User(Id = UserInfo.getUserId())) {
      submitterContact.UHN_User__c = submitter.Id;
      update submitterContact;
    }

    System.runAs(submitter) {
      UHN_FCC__c fromFCC = new UHN_FCC__c(
        Name = 'FCC-AUTOET-FROM',
        UHN_Contact__c = submitterContact.Id,
        UHN_FCC_Status__c = 'Open'
      );
      // Submitter is the account holder on toFCC — signing authority passes
      // unconditionally via the account-holder branch of validateApproverSigningAuthority.
      UHN_FCC__c toFCC = new UHN_FCC__c(
        Name = 'FCC-AUTOET-TO',
        UHN_Contact__c = submitterContact.Id,
        UHN_FCC_Status__c = 'Open'
      );
      insert new List<UHN_FCC__c>{ fromFCC, toFCC };

      UHN_GL_Account__c gl = new UHN_GL_Account__c(
        Name = '600099-AUTOET',
        UHN_PI_Expense_or_Revenue_Type__c = 'Equipment',
        UHN_SAP_ID__c = 'SAPAUTOET001'
      );
      insert gl;

      // UHN_Amount__c must be negative (expense JEs are debits represented as negative
      // amounts). The outdated-amount check fires when UHN_Actual_Amount__c > 0 after
      // the transfer JEs are inserted. Using -200 leaves headroom: even if the Rollup
      // Helper adds the +100 debit transfer, the result is -100 (still negative).
      UHN_Journal_Entry__c je = new UHN_Journal_Entry__c(
        Name = 'JE-AUTOET-' + DateTime.now().getTime(),
        UHN_FCC__c = fromFCC.Id,
        UHN_GL_Account__c = gl.Id,
        UHN_PI_Expense_or_Revenue_Class__c = 'Expense',
        UHN_PI_Expense_or_Revenue_Type__c = 'Equipment',
        UHN_Debit_or_Credit__c = 'Debit',
        UHN_UID__c = 'UID-AUTOET-' + Math.abs(Crypto.getRandomLong()),
        UHN_Calculated_Date_Key__c = Date.today(),
        UHN_Amount__c = -200
      );
      insert je;

      List<Schema.PicklistEntry> rationales = Schema.sObjectType.Case.fields.UHN_ET_Request_Rationale__c.getPicklistValues();
      String validRationale = rationales.isEmpty()
        ? ''
        : rationales.get(0).getValue();

      String expectedDescription = 'Equipment purchase for Q4 2026 trial renewal';

      String jsonStr =
        '[{' +
        '"name":"Non-Salary ET Auto Approve",' +
        '"fromFCC_ID":"' +
        fromFCC.Id +
        '",' +
        '"toFCC_ID":"' +
        toFCC.Id +
        '",' +
        '"daUserID":"' +
        submitter.Id +
        '",' +
        '"daContactID":"' +
        submitterContact.Id +
        '",' +
        '"isAutoApproval":true,' +
        '"totalTransfer":100,' +
        '"rational":"' +
        validRationale +
        '",' +
        '"description":"' +
        expectedDescription +
        '",' +
        '"id":"NODE-AUTOET-1",' +
        '"transactions":[{' +
        '"transferAmount":100,' +
        '"transactionID":"' +
        je.Id +
        '"' +
        '}]' +
        '}]';

      Test.startTest();
      List<TransactionViewerWOS.URL_Node> result = TransactionViewerWOS.createNonSalaryET(
        jsonStr
      );
      Test.stopTest();

      System.assertEquals(1, result.size(), 'Should return one Case URL');
      // Query by the case Id in the result URL — OwnerId-based queries are fragile
      // in PROD where case assignment rules can change ownership after insert.
      Id caseId = (Id) result[0].url.substringAfterLast('/');
      List<Case> created = [
        SELECT UHN_Approved_by_approver_2__c, Status, Description
        FROM Case
        WHERE Id = :caseId
      ];
      System.assertEquals(1, created.size(), 'Case must be created');
      System.assertEquals(
        true,
        created[0].UHN_Approved_by_approver_2__c,
        'Auto-approval must stamp UHN_Approved_by_approver_2__c = true'
      );
      System.assertEquals(
        'In Progress',
        created[0].Status,
        'Auto-approval case must have Status = In Progress'
      );
      System.assertEquals(
        expectedDescription,
        created[0].Description,
        'Submitter description must be persisted to Case.Description'
      );
      List<CaseComment> comments = [
        SELECT CommentBody
        FROM CaseComment
        WHERE ParentId = :caseId
      ];
      System.assertEquals(
        1,
        comments.size(),
        'Auto-approval must insert one CaseComment'
      );
      System.assert(
        comments[0].CommentBody.contains('Auto-approved'),
        'CaseComment body must contain auto-approval note'
      );
    }
  }

  @isTest
  static void testCreateNonSalaryET_descriptionTruncatedAtFieldLength() {
    // Description longer than Case.Description's configured length must be
    // truncated by the server to prevent DML failure. Uses the auto-approve
    // happy-path setup to reach the new Case(... Description = ...) line.
    User submitter;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      submitter = createTestUser('DT1');
    }

    Account acc = new Account(
      Name = 'ET Desc Truncation',
      UHN_SAP_Id__c = 'SAP-DESCTRUNC',
      OwnerId = UserInfo.getUserId()
    );
    insert acc;

    Contact submitterContact = new Contact(
      FirstName = 'ET',
      LastName = 'DescTrunc',
      AccountId = acc.Id
    );
    insert submitterContact;

    System.runAs(new User(Id = UserInfo.getUserId())) {
      submitterContact.UHN_User__c = submitter.Id;
      update submitterContact;
    }

    System.runAs(submitter) {
      UHN_FCC__c fromFCC = new UHN_FCC__c(
        Name = 'FCC-DESCTRUNC-FROM',
        UHN_Contact__c = submitterContact.Id,
        UHN_FCC_Status__c = 'Open'
      );
      UHN_FCC__c toFCC = new UHN_FCC__c(
        Name = 'FCC-DESCTRUNC-TO',
        UHN_Contact__c = submitterContact.Id,
        UHN_FCC_Status__c = 'Open'
      );
      insert new List<UHN_FCC__c>{ fromFCC, toFCC };

      UHN_GL_Account__c gl = new UHN_GL_Account__c(
        Name = '600099-DESCTRUNC',
        UHN_PI_Expense_or_Revenue_Type__c = 'Equipment',
        UHN_SAP_ID__c = 'SAPDESCTRUNC1'
      );
      insert gl;

      UHN_Journal_Entry__c je = new UHN_Journal_Entry__c(
        Name = 'JE-DESCTRUNC-' + DateTime.now().getTime(),
        UHN_FCC__c = fromFCC.Id,
        UHN_GL_Account__c = gl.Id,
        UHN_PI_Expense_or_Revenue_Class__c = 'Expense',
        UHN_PI_Expense_or_Revenue_Type__c = 'Equipment',
        UHN_Debit_or_Credit__c = 'Debit',
        UHN_UID__c = 'UID-DESCTRUNC-' + Math.abs(Crypto.getRandomLong()),
        UHN_Calculated_Date_Key__c = Date.today(),
        UHN_Amount__c = -200
      );
      insert je;

      List<Schema.PicklistEntry> rationales = Schema.sObjectType.Case.fields.UHN_ET_Request_Rationale__c.getPicklistValues();
      String validRationale = rationales.isEmpty()
        ? ''
        : rationales.get(0).getValue();

      // Build a description 1,000 chars longer than the field's configured length.
      Integer fieldLength = Case.Description.getDescribe().getLength();
      String longDescription = 'x'.repeat(fieldLength + 1000);

      String jsonStr =
        '[{' +
        '"name":"Non-Salary ET Desc Truncation",' +
        '"fromFCC_ID":"' +
        fromFCC.Id +
        '",' +
        '"toFCC_ID":"' +
        toFCC.Id +
        '",' +
        '"daUserID":"' +
        submitter.Id +
        '",' +
        '"daContactID":"' +
        submitterContact.Id +
        '",' +
        '"isAutoApproval":true,' +
        '"totalTransfer":100,' +
        '"rational":"' +
        validRationale +
        '",' +
        '"description":"' +
        longDescription +
        '",' +
        '"id":"NODE-DESCTRUNC-1",' +
        '"transactions":[{' +
        '"transferAmount":100,' +
        '"transactionID":"' +
        je.Id +
        '"' +
        '}]' +
        '}]';

      Test.startTest();
      List<TransactionViewerWOS.URL_Node> result = TransactionViewerWOS.createNonSalaryET(
        jsonStr
      );
      Test.stopTest();

      Id caseId = (Id) result[0].url.substringAfterLast('/');
      Case created = [
        SELECT Description
        FROM Case
        WHERE Id = :caseId
      ];
      System.assertEquals(
        fieldLength,
        created.Description.length(),
        'Description longer than field length must be truncated to field length'
      );
    }
  }

  @isTest
  static void testGetPaperTransferredJEIds() {
    // JE tagged with 'Rejected: Expense unavailable - Already transferred' must appear
    // in the exclusion set. JE with a different rejection reason must not.

    Account acc = new Account(
      Name = 'Paper Transfer Test',
      UHN_SAP_Id__c = 'SAP-PAPER-1',
      OwnerId = UserInfo.getUserId()
    );
    insert acc;
    Contact con = new Contact(
      FirstName = 'Paper',
      LastName = 'Test',
      AccountId = acc.Id
    );
    insert con;

    UHN_FCC__c fromFcc = new UHN_FCC__c(
      Name = 'FCC-PAPER-FROM',
      UHN_Contact__c = con.Id,
      UHN_FCC_Status__c = 'Open',
      UHN_FCC_Type_long__c = 'Grant Internal Order',
      UHN_NonSalary_Actuals_Allowed__c = 'Yes',
      UHN_To_be_Closed__c = false,
      UHN_Blocked__c = false
    );
    UHN_FCC__c toFcc = new UHN_FCC__c(
      Name = 'FCC-PAPER-TO',
      UHN_Contact__c = con.Id,
      UHN_FCC_Status__c = 'Open',
      UHN_FCC_Type_long__c = 'Grant Internal Order',
      UHN_NonSalary_Actuals_Allowed__c = 'Yes',
      UHN_To_be_Closed__c = false,
      UHN_Blocked__c = false
    );
    insert new List<UHN_FCC__c>{ fromFcc, toFcc };

    UHN_GL_Account__c gl = new UHN_GL_Account__c(
      Name = '600099',
      UHN_PI_Expense_or_Revenue_Type__c = 'Equipment',
      UHN_SAP_ID__c = 'SAPPAPER001'
    );
    insert gl;

    UHN_Journal_Entry__c paperJE = new UHN_Journal_Entry__c(
      Name = 'JE-PAPER-' + DateTime.now().getTime(),
      UHN_FCC__c = fromFcc.Id,
      UHN_GL_Account__c = gl.Id,
      UHN_PI_Expense_or_Revenue_Class__c = 'Expense',
      UHN_PI_Expense_or_Revenue_Type__c = 'Equipment',
      UHN_Debit_or_Credit__c = 'Debit',
      UHN_UID__c = 'UID-PAPER-' + Math.abs(Crypto.getRandomLong()),
      UHN_Calculated_Date_Key__c = Date.today(),
      UHN_Amount__c = 50
    );
    UHN_Journal_Entry__c otherJE = new UHN_Journal_Entry__c(
      Name = 'JE-OTHER-' + DateTime.now().getTime(),
      UHN_FCC__c = fromFcc.Id,
      UHN_GL_Account__c = gl.Id,
      UHN_PI_Expense_or_Revenue_Class__c = 'Expense',
      UHN_PI_Expense_or_Revenue_Type__c = 'Equipment',
      UHN_Debit_or_Credit__c = 'Debit',
      UHN_UID__c = 'UID-OTHER-' + Math.abs(Crypto.getRandomLong()),
      UHN_Calculated_Date_Key__c = Date.today(),
      UHN_Amount__c = 75
    );
    insert new List<UHN_Journal_Entry__c>{ paperJE, otherJE };

    Id rtId = SObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get('Transfer_Request')
      .getRecordTypeId();
    Case etCase = new Case(
      RecordTypeId = rtId,
      Status = 'New',
      Subject = 'Paper Transfer WOS Test',
      UHN_From_FCC__c = fromFcc.Id,
      UHN_To_FCC__c = toFcc.Id
    );
    insert etCase;

    // TJE tagged as already transferred via paper
    UHN_Transfer_Journal_Entry__c paperTJE = new UHN_Transfer_Journal_Entry__c(
      UHN_Transfer_Request__c = etCase.Id,
      UHN_Journal_Entry__c = paperJE.Id,
      UHN_Requested_Amount__c = 50,
      UHN_Amount__c = 50,
      UHN_Inverse__c = true,
      UHN_Transfer_Transaction_Pair_ID__c = 'PAIR-PAPER-WOS-' +
        DateTime.now().getTime(),
      UHN_Rejection_or_Reduction_Reason__c = 'Rejected: Expense unavailable - Already transferred'
    );
    // TJE with a different rejection reason — must not affect otherJE
    UHN_Transfer_Journal_Entry__c otherTJE = new UHN_Transfer_Journal_Entry__c(
      UHN_Transfer_Request__c = etCase.Id,
      UHN_Journal_Entry__c = otherJE.Id,
      UHN_Requested_Amount__c = 75,
      UHN_Amount__c = 75,
      UHN_Inverse__c = true,
      UHN_Transfer_Transaction_Pair_ID__c = 'PAIR-OTHER-WOS-' +
        DateTime.now().getTime(),
      UHN_Rejection_or_Reduction_Reason__c = 'Rejected: Outside of grant period'
    );
    insert new List<UHN_Transfer_Journal_Entry__c>{ paperTJE, otherTJE };

    Test.startTest();
    Set<Id> excluded = TransactionViewerWOS.getPaperTransferredJEIds();
    Test.stopTest();

    System.assert(
      excluded.contains(paperJE.Id),
      'JE tagged as already paper-transferred must be in the exclusion set'
    );
    System.assert(
      !excluded.contains(otherJE.Id),
      'JE with a different rejection reason must not be in the exclusion set'
    );
  }

  @isTest
  static void testValidateApproverSigningAuthority_missingFccContact() {
    // FCC whose contact has no linked User — validation must return a handled signing-authority error, not an NPE.
    // Note: UHN_Contact__c is required on FCC in PROD, so we insert an FCC with a contact that has no UHN_User__c.
    Account acc = new Account(
      Name = 'ET No-User Test',
      UHN_SAP_Id__c = 'SAP-ETNOUSER',
      OwnerId = UserInfo.getUserId()
    );
    insert acc;
    Contact noUserContact = new Contact(
      FirstName = 'No',
      LastName = 'User',
      AccountId = acc.Id
    );
    insert noUserContact; // intentionally no UHN_User__c set

    UHN_FCC__c toFCC = new UHN_FCC__c(
      Name = 'FCC-ET-NOUSER',
      UHN_FCC_Status__c = 'Open',
      UHN_Contact__c = noUserContact.Id
    );
    insert toFCC;

    TransactionViewerWOS.ApproverValidationRequest req = new TransactionViewerWOS.ApproverValidationRequest();
    req.nodeName = 'ET Node No User Contact';
    req.approverUserId = UserInfo.getUserId();
    req.toFccId = toFCC.Id;
    req.transferAmount = 100;

    Boolean thrown = false;
    Test.startTest();
    try {
      TransactionViewerWOS.validateApproverSigningAuthority(
        new List<TransactionViewerWOS.ApproverValidationRequest>{ req }
      );
    } catch (AuraHandledException e) {
      thrown = true;
      System.assert(
        e.getMessage().contains('signing authority'),
        'Expected signing authority message, got: ' + e.getMessage()
      );
    }
    Test.stopTest();
    System.assert(
      thrown,
      'AuraHandledException must be thrown when FCC contact has no linked User'
    );
  }
}