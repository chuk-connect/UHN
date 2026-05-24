public without sharing class UHN_CaseTriggerHelper {

    // Case queues
    private static final String adminQueueDevName = 'Grant_Admin_Analyst_Queue';
    private static final String expenseQueueDevName = 'Grant_Expense_Analyst_Queue';
    private static final String managementQueueDevName = 'Grant_Management_Analyst_Queue';

    // Case record types
    private static final String fccRequestRecTypeDevName = 'FCC_Application';
    private static final String fccAmendmentRecTypeDevName = 'FCC_Amendment';
    private static final String fccTransferRecTypeDevName = 'Transfer_Request';
    private static final String generalRecTypeDevName = 'General';


    /**
     * Assigns any cases created by community users to a queue, and sets
     * the contact to be that of the user.
     * @param  newCases A list of the cases being updated
     */
    public static void beforeInsert(List<Case> newCases) {
        

        // Get the ids of the case owners.
        List<Id> ownerIds = new List<Id>();
        for (Case c : newCases)
            ownerIds.add(c.ownerId);

        // Get the user records of the case owners.
        Map<Id, User> idToCaseOwner = new Map<Id, User>([
            SELECT Id, IsPortalEnabled, ContactId 
            FROM User 
            WHERE Id IN :ownerIds
        ]);


        // Get the record types for the Case object.
        Map<ID,Schema.RecordTypeInfo> idToRecordTypeInfo = Case.SObjectType.getDescribe().getRecordTypeInfosById();

        // Get queues for the cases to be assigned to.
        Id adminQueueId      = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = :adminQueueDevName LIMIT 1].Id;
        Id expenseQueueId    = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = :expenseQueueDevName LIMIT 1].Id;
        Id managementQueueId = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = :managementQueueDevName LIMIT 1].Id;


        for (Case c : newCases) {

            // Is the case owner a community user?
            User caseOwner = idToCaseOwner.get(c.ownerId);
            if (caseOwner != null && caseOwner.IsPortalEnabled) {
            
                // Flag the case as being created by a community user.
                // Currently there is a process that attempts to assign
                // such cases to an analyst.
                // Doing so in the trigger causes insufficient access
                // rights errors for community users, as the analyst
                // probably hasn't been shared with them.
                c.UHN_Created_By_Community_User__c = true;

                // Set the contact of the case to be that of the community
                // user, and assign it to a queue.
                // Note: can't use constants in switch statements, so for now,
                // this stays hardcoded...
                if (!c.UHN_Assigned_Owner__c) {

                    String recordTypeDevName = idToRecordTypeInfo.get(c.RecordTypeId).getDeveloperName();
                    switch on recordTypeDevName {

                        // Assign new fcc requests and amendments to the admin queue.
                        when 'FCC_Application', 'FCC_Amendment' {
                            c.OwnerId = adminQueueId;
                            c.ContactId = caseOwner.ContactId;
                        }

                        // Assign expense/salary transfer requests and general questions
                        // to the management queue.
                        when 'UHN_Salary_Expense_Transfer', 'General' {
                            c.OwnerId = managementQueueId;
                            c.ContactId = caseOwner.ContactId;
                        }
                        
                    }
                }
            }
        }
    }

    /**
     * Checks to ensure any new FCC requests that are updated
     * to "Closed - Approved" have a user associated with the case contact.
     * This is necessary for the FCC conversion process to be able to create
     * the FCC.
     * @param  newCases A list of the cases being updated
     */
    public static void beforeUpdate(List<Case> newCases) {
        
        // Get a list of the updated cases that are FCC requests and
        // Closed - Approved.
        Id fccApplicationRecordTypeId =  Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get(fccRequestRecTypeDevName).getRecordTypeId();
        List<Case> closedApprovedFCCRequestCases = new List<Case>();
        for (Case ca : newCases) {
            if(ca.Status == 'Closed - Approved' && ca.RecordTypeId == fccApplicationRecordTypeId)
                closedApprovedFCCRequestCases.add(ca);
        }
        
        // Get a list of contact ids for these cases.
        Set<Id> sapIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        for(Case ca : closedApprovedFCCRequestCases) {
            if(ca.ContactId != null)
                contactIds.add(ca.ContactId); 
        }
        
        // Create a map from the contact id to it's associated
        // user (i.e. community users).
        List<User> contactUsers = [SELECT Id, ContactId FROM User WHERE ContactId in :contactIds];
        Map<Id, User> contactIdToUser = new Map<Id, User>();
        for (User user : contactUsers) {
            contactIdToUser.put(user.ContactId, user);
        }
    
        
        // Ensure that all of contacts for these cases have a user associated
        // with them.
        //for (Case ca : closedApprovedFCCRequestCases) {
           // if (!contactIdToUser.containsKey(ca.ContactId)) {
                //ca.addError('To update a new FCC request to "Closed - Approved", the contact must be associated with a user.');
            }
        }