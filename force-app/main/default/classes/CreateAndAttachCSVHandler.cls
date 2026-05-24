public with sharing class CreateAndAttachCSVHandler {

    @TestVisible
    private static List<UHN_Transfer_Journal_Entry__c> mockExpenseEntries;

    @TestVisible
    private static List<UHN_Salary_Transfer_Transaction__c> mockSalaryEntries;

    public static void handleAfterUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        // Formula fields (e.g. UHN_RecordType_Name__c) are not populated in Trigger.new.
        // Build a fallback lookup from RecordTypeId to label via Schema describe.
        Map<Id, String> rtIdToLabel = new Map<Id, String>();
        for (Schema.RecordTypeInfo rti : Case.SObjectType.getDescribe().getRecordTypeInfosById().values()) {
            rtIdToLabel.put(rti.getRecordTypeId(), rti.getName());
        }

        List<Case> eligibleCases = new List<Case>();
        Map<Id, String> caseToRtName = new Map<Id, String>();

        for (Case c : newCases) {
            String rtName = c.UHN_RecordType_Name__c != null
                ? c.UHN_RecordType_Name__c
                : rtIdToLabel.get(c.RecordTypeId);
            Boolean isEligibleRT = rtName == 'Expense Transfer Request'
                || rtName == 'Salary Expense Transfer Request';
            Boolean approvalJustSet = c.UHN_RFS_Management_Approval__c == true
                && oldMap.get(c.Id).UHN_RFS_Management_Approval__c != true;

            if (isEligibleRT && approvalJustSet) {
                eligibleCases.add(c);
                caseToRtName.put(c.Id, rtName);
            }
        }

        if (eligibleCases.isEmpty()) {
            return;
        }

        List<ContentVersion> versionsToInsert = new List<ContentVersion>();
        Map<Integer, Id> indexToCaseId = new Map<Integer, Id>();

        for (Case c : eligibleCases) {
            String rtName = caseToRtName.get(c.Id);
            String docTitle = rtName + ' csv';
            String csvContent;

            if (rtName == 'Expense Transfer Request') {
                csvContent = buildExpenseCSV(c);
            } else {
                csvContent = buildSalaryCSV(c);
            }

            ContentVersion cv = new ContentVersion(
                Title          = docTitle,
                PathOnClient   = docTitle + '.csv',
                VersionData    = Blob.valueOf(csvContent),
                IsMajorVersion = true
            );
            versionsToInsert.add(cv);
            indexToCaseId.put(versionsToInsert.size() - 1, c.Id);
        }

        insert versionsToInsert;

        Set<Id> insertedIds = new Map<Id, ContentVersion>(versionsToInsert).keySet();
        Map<Id, Id> cvIdToDocId = new Map<Id, Id>();
        for (ContentVersion cv : [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :insertedIds]) {
            cvIdToDocId.put(cv.Id, cv.ContentDocumentId);
        }

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Integer i = 0; i < versionsToInsert.size(); i++) {
            links.add(new ContentDocumentLink(
                ContentDocumentId = cvIdToDocId.get(versionsToInsert[i].Id),
                LinkedEntityId    = indexToCaseId.get(i),
                ShareType         = 'V',
                Visibility        = 'AllUsers'
            ));
        }

        insert links;
    }

    // --- Expense Transfer (UHN_Transfer_Journal_Entry__c) ---
    // Columns: Case Number, Company Code, Business Area, GL Account, Cost Center,
    //          Order Number, WBS Element, Debit, Credit, Description
    private static String buildExpenseCSV(Case c) {
        List<UHN_Transfer_Journal_Entry__c> entries = mockExpenseEntries != null
            ? mockExpenseEntries
            : [
                SELECT UHN_Company_Code__c, UHN_Business_Area__c, UHN_S4_GL_Account__c,
                       UHN_Cost_Center__c, UHN_Order_Number__c, UHN_WBS_Element__c,
                       UHN_Debit__c, UHN_Credit__c, UHN_Description__c
                FROM UHN_Transfer_Journal_Entry__c
                WHERE UHN_Transfer_Request__c = :c.Id
                  AND UHN_Is_Declined__c = false
                ORDER BY UHN_CSV_SortOrder__c DESC
            ];

        List<String> rows = new List<String>{
            'Case Number,Company Code,Business Area,GL Account,Cost Center,Order Number,WBS Element,Debit,Credit,Description'
        };

        for (UHN_Transfer_Journal_Entry__c e : entries) {
            rows.add(String.join(new List<String>{
                csvVal(c.CaseNumber),
                csvVal(e.UHN_Company_Code__c),
                csvVal(e.UHN_Business_Area__c),
                csvVal(e.UHN_S4_GL_Account__c),
                csvVal(e.UHN_Cost_Center__c),
                csvVal(e.UHN_Order_Number__c),
                csvVal(e.UHN_WBS_Element__c),
                csvVal(e.UHN_Debit__c),
                csvVal(e.UHN_Credit__c),
                csvVal(e.UHN_Description__c)
            }, ','));
        }

        return String.join(rows, '\n');
    }

    // --- Salary Transfer (UHN_Salary_Transfer_Transaction__c) ---
    // Columns: Case Number, Company Code, Profit Center, GL Account, Cost Center,
    //          Order Number, WBS Element, Debit, Credit, Item Text
    private static String buildSalaryCSV(Case c) {
        List<UHN_Salary_Transfer_Transaction__c> entries = mockSalaryEntries != null
            ? mockSalaryEntries
            : [
                SELECT UHN_Company_Code__c, UHN_Profit_Center__c, UHN_G_L_Account__c,
                       UHN_Cost_Center__c, UHN_Order_Number__c, UHN_WBS_Element__c,
                       UHN_Debit__c, UHN_Credit__c, UHN_Item_Text__c
                FROM UHN_Salary_Transfer_Transaction__c
                WHERE UHN_Transfer_Request__c = :c.Id
                  AND UHN_Is_Declined__c = false
                ORDER BY UHN_CSV_SortOrder__c DESC
            ];

        List<String> rows = new List<String>{
            'Case Number,Company Code,Profit Center,GL Account,Cost Center,Order Number,WBS Element,Debit,Credit,Item Text'
        };

        for (UHN_Salary_Transfer_Transaction__c e : entries) {
            rows.add(String.join(new List<String>{
                csvVal(c.CaseNumber),
                csvVal(e.UHN_Company_Code__c),
                csvVal(e.UHN_Profit_Center__c),
                csvVal(e.UHN_G_L_Account__c),
                csvVal(e.UHN_Cost_Center__c),
                csvVal(e.UHN_Order_Number__c),
                csvVal(e.UHN_WBS_Element__c),
                csvVal(e.UHN_Debit__c),
                csvVal(e.UHN_Credit__c),
                csvVal(e.UHN_Item_Text__c)
            }, ','));
        }

        return String.join(rows, '\n');
    }

    private static String csvVal(Object val) {
        if (val == null) return '';
        String s = String.valueOf(val);
        if (s == 'null') return '';
        if (s.contains(',') || s.contains('"') || s.contains('\n')) {
            return '"' + s.replace('"', '""') + '"';
        }
        return s;
    }
}
