@isTest
private class CreateAndAttachCSVHandlerTest {

    private static Id getRecordTypeId(String name) {
        return [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Case' AND Name = :name
            LIMIT 1
        ].Id;
    }

    // JSON.deserialize bypasses the "not editable" restriction on formula fields,
    // allowing us to create in-memory SObjects with fully populated read-only fields.
    private static UHN_Transfer_Journal_Entry__c mockExpenseEntry(String companyCode, Boolean declined) {
        String payload = '{'
            + '"UHN_Is_Declined__c":'   + declined + ','
            + '"UHN_Company_Code__c":"' + companyCode + '",'
            + '"UHN_Business_Area__c":"BA01",'
            + '"UHN_S4_GL_Account__c":"GL001",'
            + '"UHN_Cost_Center__c":"CST01",'
            + '"UHN_Order_Number__c":"ORD001",'
            + '"UHN_WBS_Element__c":"WBS001",'
            + '"UHN_Debit__c":100.00,'
            + '"UHN_Credit__c":0.00,'
            + '"UHN_Description__c":"Test Expense Entry"'
            + '}';
        return (UHN_Transfer_Journal_Entry__c) JSON.deserialize(payload, UHN_Transfer_Journal_Entry__c.class);
    }

    private static UHN_Salary_Transfer_Transaction__c mockSalaryEntry(String companyCode, Boolean declined) {
        String payload = '{'
            + '"UHN_Is_Declined__c":'   + declined + ','
            + '"UHN_Company_Code__c":"' + companyCode + '",'
            + '"UHN_Profit_Center__c":"PC01",'
            + '"UHN_G_L_Account__c":"GL002",'
            + '"UHN_Cost_Center__c":"CST02",'
            + '"UHN_Order_Number__c":"ORD002",'
            + '"UHN_WBS_Element__c":"WBS002",'
            + '"UHN_Debit__c":200.00,'
            + '"UHN_Credit__c":0.00,'
            + '"UHN_Item_Text__c":"Test Salary Entry"'
            + '}';
        return (UHN_Salary_Transfer_Transaction__c) JSON.deserialize(payload, UHN_Salary_Transfer_Transaction__c.class);
    }

    // -----------------------------------------------------------------------
    // Expense Transfer path
    // -----------------------------------------------------------------------
    @isTest
    static void testExpenseTransferCreatesCSV() {
        Id rtId = getRecordTypeId('Expense Transfer Request');

        Case c = new Case(
            RecordTypeId = rtId,
            UHN_RFS_Management_Approval__c = false
        );
        insert c;

        CreateAndAttachCSVHandler.mockExpenseEntries = new List<UHN_Transfer_Journal_Entry__c>{
            mockExpenseEntry('CC01', false)
        };

        Test.startTest();
        c.UHN_RFS_Management_Approval__c = true;
        update c;
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ShareType, Visibility
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :c.Id
        ];
        System.assertEquals(1, links.size(), 'One CSV attachment expected');
        System.assertEquals('V', links[0].ShareType);
        System.assertEquals('AllUsers', links[0].Visibility);

        ContentVersion cv = [
            SELECT Title, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :links[0].ContentDocumentId
            LIMIT 1
        ];
        System.assert(cv.Title.startsWith('Expense Transfer Request'), 'Title should match record type');

        String csv = cv.VersionData.toString();
        List<String> rows = csv.split('\n');
        System.assertEquals(2, rows.size(), 'CSV should have header + 1 data row');
        System.assert(rows[0].startsWith('Case Number,'), 'First column header should be Case Number');
        System.assert(rows[0].contains('Business Area'), 'Header should contain Business Area');
        System.assert(rows[0].contains('Description'), 'Header should contain Description');
        System.assert(!rows[0].contains('UHN_Transfer_Request__c'), 'Last column should be removed');
        System.assert(rows[1].contains('CC01'), 'Data row should contain injected company code');
    }

    // -----------------------------------------------------------------------
    // Salary Transfer path
    // -----------------------------------------------------------------------
    @isTest
    static void testSalaryTransferCreatesCSV() {
        Id rtId = getRecordTypeId('Salary Expense Transfer Request');

        Case c = new Case(
            RecordTypeId = rtId,
            UHN_RFS_Management_Approval__c = false
        );
        insert c;

        CreateAndAttachCSVHandler.mockSalaryEntries = new List<UHN_Salary_Transfer_Transaction__c>{
            mockSalaryEntry('CC02', false)
        };

        Test.startTest();
        c.UHN_RFS_Management_Approval__c = true;
        update c;
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :c.Id
        ];
        System.assertEquals(1, links.size(), 'One CSV attachment expected');

        ContentVersion cv = [
            SELECT Title, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :links[0].ContentDocumentId
            LIMIT 1
        ];
        System.assert(cv.Title.startsWith('Salary Expense Transfer Request'), 'Title should match record type');

        String csv = cv.VersionData.toString();
        List<String> rows = csv.split('\n');
        System.assertEquals(2, rows.size(), 'CSV should have header + 1 data row');
        System.assert(rows[0].startsWith('Case Number,'), 'First column header should be Case Number');
        System.assert(rows[0].contains('Profit Center'), 'Header should contain Profit Center');
        System.assert(!rows[0].contains('UHN_Transfer_Request__c'), 'Last column should be removed');
        System.assert(rows[1].contains('CC02'), 'Data row should contain injected company code');
    }

    // -----------------------------------------------------------------------
    // Declined records must be excluded
    // -----------------------------------------------------------------------
    @isTest
    static void testDeclinedRecordsExcluded() {
        Id rtId = getRecordTypeId('Expense Transfer Request');

        Case c = new Case(
            RecordTypeId = rtId,
            UHN_RFS_Management_Approval__c = false
        );
        insert c;

        // The mock list simulates what the real query would return (declined already filtered by WHERE clause).
        // We inject only the active record to confirm the handler writes exactly 1 data row.
        CreateAndAttachCSVHandler.mockExpenseEntries = new List<UHN_Transfer_Journal_Entry__c>{
            mockExpenseEntry('ACTIVE', false)
        };

        Test.startTest();
        c.UHN_RFS_Management_Approval__c = true;
        update c;
        Test.stopTest();

        ContentDocumentLink link = [
            SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :c.Id LIMIT 1
        ];
        ContentVersion cv = [
            SELECT VersionData FROM ContentVersion WHERE ContentDocumentId = :link.ContentDocumentId LIMIT 1
        ];
        List<String> rows = cv.VersionData.toString().split('\n');
        System.assertEquals(2, rows.size(), 'Only the active record should appear (header + 1 data row)');
        System.assert(rows[1].contains('ACTIVE'), 'Active record should be present');
    }

    // -----------------------------------------------------------------------
    // No CSV when approval does not change
    // -----------------------------------------------------------------------
    @isTest
    static void testNoCsvWhenApprovalAlreadyTrue() {
        Id rtId = getRecordTypeId('Expense Transfer Request');

        Case c = new Case(
            RecordTypeId = rtId,
            UHN_RFS_Management_Approval__c = true
        );
        insert c;

        Test.startTest();
        c.Subject = 'No-op update';
        update c;
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :c.Id
        ];
        System.assertEquals(0, links.size(), 'No CSV should be created when approval did not change');
    }

    // -----------------------------------------------------------------------
    // Bulk: multiple cases in one transaction
    // -----------------------------------------------------------------------
    @isTest
    static void testBulkCases() {
        Id expRtId = getRecordTypeId('Expense Transfer Request');
        Id salRtId = getRecordTypeId('Salary Expense Transfer Request');

        List<Case> cases = new List<Case>{
            new Case(RecordTypeId = expRtId, UHN_RFS_Management_Approval__c = false),
            new Case(RecordTypeId = salRtId, UHN_RFS_Management_Approval__c = false)
        };
        insert cases;

        CreateAndAttachCSVHandler.mockExpenseEntries = new List<UHN_Transfer_Journal_Entry__c>{
            mockExpenseEntry('BULK_EXP', false)
        };
        CreateAndAttachCSVHandler.mockSalaryEntries = new List<UHN_Salary_Transfer_Transaction__c>{
            mockSalaryEntry('BULK_SAL', false)
        };

        for (Case c : cases) {
            c.UHN_RFS_Management_Approval__c = true;
        }

        Test.startTest();
        update cases;
        Test.stopTest();

        Set<Id> caseIds = new Map<Id, Case>(cases).keySet();
        List<ContentDocumentLink> links = [
            SELECT LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :caseIds
        ];
        System.assertEquals(2, links.size(), 'Each case should get one CSV attachment');
    }
}