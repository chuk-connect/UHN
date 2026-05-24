trigger UHN_SetSignatureURLTrigger on ContentDocumentLink(before insert, before update) {

	// Get the signatures workspace
	List<ContentWorkspace> sigWSList = [SELECT Id FROM ContentWorkspace WHERE Name = 'Signatures' LIMIT 1];
	if (sigWSList.size() == 0) {
		System.debug(LoggingLevel.WARN, 'No signatures workspace.');
		return;
	}
	ContentWorkspace sigWS = sigWSList[0];

	// Get the records linking contacts only
	List<ContentDocumentLink> contactCDLs = new List<ContentDocumentLink>();
	String contactKeyPrefix = Contact.sObjectType.getDescribe().getKeyPrefix();
	for(ContentDocumentLink cdl : Trigger.new)
		if (String.valueOf(cdl.LinkedEntityId).startsWith(contactKeyPrefix))
			contactCDLs.add(cdl);

	// If there are none, no need to continue
	if (contactCDLs.size() == 0)
		return;

	// Get ids of the content documents (aka files), and the contacts
	// they are being linked to.
	Set<Id> contentDocumentIds = new Set<Id>();
	Set<Id> contactIds = new Set<Id>();
	for (ContentDocumentLink cdl : contactCDLs) {
		contactIds.add(cdl.LinkedEntityId);
		contentDocumentIds.add(cdl.ContentDocumentId);
	}
	
	// Do a bulk query to fetch the contacts and content documents
	Map<Id,ContentDocument> idToCD = new Map<Id,ContentDocument>([
		SELECT Id, ParentId
		FROM ContentDocument 
		WHERE Id IN :contentDocumentIds
	]);
	Map<Id,Contact> idToContact = new Map<Id,Contact>([
		SELECT Id 
		FROM Contact 
		WHERE Id IN :contactIds
	]);
	
	// Determine and set the signature image url of the contact the
	// file is being linked to, to a download link for the file.
	String baseURL = URL.getSalesforceBaseUrl().toExternalForm();
	List<Contact> contactsToUpdate = new List<Contact>();
	for(ContentDocumentLink cdl : Trigger.new) {

		// Get the content document
		ContentDocument cd = idToCD.get(cdl.ContentDocumentId);

		// Check that the document is in the signatures workspace.
		// This is to make sure it is a signature, and not just a
		// random file attached to the contact.
		if (cd.ParentId == sigWS.Id) {

			// Get the contact the signature is attached to
			Contact contact = idToContact.get(cdl.LinkedEntityId);

			// So community users can see the image
			cdl.Visibility = 'AllUsers';

			// Determine the signature image url
			contact.UHN_Signature_Image_URL__c = baseURL + '/sfc/servlet.shepherd/document/download/' + cdl.ContentDocumentId;

			contactsToUpdate.add(contact);
		}
	}
	UPDATE contactsToUpdate;
}