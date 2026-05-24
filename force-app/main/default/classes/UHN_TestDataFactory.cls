/**
* Creates test data that can be used in other test classes
*/
@isTest
public without sharing class UHN_TestDataFactory{
    
    //Profile and Role Name
    public static final String portalProfileName = 'Account Holder User';
    
  	// Case queues
  	public static final String adminQueueDevName = 'Grant_Admin_Analyst_Queue';
  	public static final String managementQueueDevName = 'Grant_Management_Analyst_Queue';
    
    // Get queues for the cases to be assigned to.
	public static Id adminQueueId 	 	= [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = :adminQueueDevName LIMIT 1].Id;
	public static Id managementQueueId 	= [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = :managementQueueDevName LIMIT 1].Id;

  	// Case record types
  	public static final String fccRequestRecTypeDevName = 'FCC_Application';
  	public static final String fccTransferRecTypeDevName = 'Transfer_Request';

    //Create a Customer Community Plus User
    public static User createPortalUser(String PortalUserEmail){
        
        //Create a System Admin User
        User sysAdminUser = createSystemAdminUser();
    	insert sysAdminUser;
        
        User portalUser = new User();
        //Create portal User through new system admin user
        System.runAs (sysAdminUser) {

			//Create unique identifiers to avoid duplicate values when called multiple times
			Integer rand = Integer.valueOf(Math.rint(Math.random()*1000000));

			//Create account
			Account portalAccount = new Account(
			Name = 'TestAccount',
            UHN_SAP_Id__c = String.valueOf(rand),
			OwnerId = sysAdminUser.Id);
			insert portalAccount;

			//Create contact
			Contact portalContact = new Contact(
			FirstName = 'Test',
			Lastname = 'Contact',
			AccountId = portalAccount.Id,
            UHN_ENID__c = String.valueOf(rand),
			Email = System.now().millisecond() + 'test@test.com');
			insert portalContact;
            
        	Profile portalProfile = [SELECT Id FROM Profile WHERE Name = :portalProfileName];
        	
            //Create uniqueName to avoid duplicate usernames while running tests
        	String orgId = UserInfo.getOrganizationId();
    		String dateString = 
        	String.valueof(Datetime.now()).replace(' ','').replace(':','').replace('-','');
    		Integer randomInt = Integer.valueOf(math.rint(math.random()*1000000));
    		String uniqueName = orgId + dateString + randomInt;
        	portalUser = new User(Alias = 'standt', Email=PortalUserEmail, 
                          EmailEncodingKey='UTF-8', LastName='Testing', 
                          LanguageLocaleKey='en_US', 
                          LocaleSidKey='en_US', 
                          ProfileId = portalProfile.Id,
                          //userRoleId = portalRole.Id,
                          TimeZoneSidKey='America/Los_Angeles', 
                          UserName=uniqueName + '@test' + orgId + '.org',
                          ContactId = portalContact.Id);
        	insert portalUser;
        }
        return portalUser;
    }
    
   /**
   * Creates a case record
   * @param  status sets the Case status
   * @param  recordTypeDeveloperName used to fetch Id for Case Record Type
   */
    public static Case createCase(string status, string recordTypeDeveloperName) {
        Id recordTypeId =  Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get(RecordTypeDeveloperName).getRecordTypeId();
        Case ca = new Case();
        ca.Status = status;
        if(recordTypeId != null)
            ca.recordTypeId = recordTypeId;
            
        return ca;
    }
    
    /**
	* Returns System Admin user with a unique username
	*/
    public static User createSystemAdminUser(){
        //Get System Admin Profile and Non-Portal Role
		Profile sysAdmin = [Select Id from Profile where name = 'System Administrator'];
    	UserRole nonPortalRole = [Select Id From UserRole Where PortalType = 'None' Limit 1];
        
        //Create uniqueName to avoid duplicate usernames while running tests
        String orgId = UserInfo.getOrganizationId();
    	String dateString = 
        String.valueof(Datetime.now()).replace(' ','').replace(':','').replace('-','');
    	Integer randomInt = Integer.valueOf(math.rint(math.random()*1000000));
    	String uniqueName = orgId + dateString + randomInt;
       
		User sysAdminUser = new User(UserRoleId = nonPortalRole.Id,
                                ProfileId = sysAdmin.Id,
                                Username = uniqueName + '@test' + orgId + '.org',
                                Alias = 'abc',
                                Email='abc@sysAdminUser.com',
                                EmailEncodingKey='UTF-8',
                                Firstname='System',
                                Lastname='Admin',
                                LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US',
                                TimeZoneSidKey='America/Chicago');
        return sysAdminUser;
    }
    
}