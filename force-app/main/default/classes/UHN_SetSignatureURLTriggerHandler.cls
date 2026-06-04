/**
 * @description Handler for UHN_SetSignatureURLTrigger. Processes ContentDocumentLink
 *              records on before insert/update to set the UHN_Signature_Image_URL__c
 *              field on related Contact records when a signature file is linked from
 *              the Signatures ContentWorkspace.
 */
public with sharing class UHN_SetSignatureURLTriggerHandler {
  /**
   * @description Executes the signature URL logic for ContentDocumentLink records.
   * @param newList The list of ContentDocumentLink records from Trigger.new.
   */
  @SuppressWarnings('PMD.CyclomaticComplexity')
  public static void execute(List<ContentDocumentLink> newList) {
    // Get the signatures workspace
    List<ContentWorkspace> sigWSList = [
      SELECT Id
      FROM ContentWorkspace
      WHERE Name = 'Signatures'
      WITH USER_MODE
      LIMIT 1
    ];
    if (sigWSList.size() == 0) {
      return;
    }
    ContentWorkspace sigWS = sigWSList[0];

    // Get the records linking contacts only
    List<ContentDocumentLink> contactCDLs = new List<ContentDocumentLink>();
    String contactKeyPrefix = Contact.sObjectType.getDescribe(
        SObjectDescribeOptions.DEFERRED
      )
      .getKeyPrefix();
    for (ContentDocumentLink cdl : newList) {
      if (String.valueOf(cdl.LinkedEntityId).startsWith(contactKeyPrefix)) {
        contactCDLs.add(cdl);
      }
    }

    // If there are none, no need to continue
    if (contactCDLs.size() == 0) {
      return;
    }

    // Get ids of the content documents (aka files), and the contacts
    // they are being linked to.
    Set<Id> contentDocumentIds = new Set<Id>();
    Set<Id> contactIds = new Set<Id>();
    for (ContentDocumentLink cdl : contactCDLs) {
      contactIds.add(cdl.LinkedEntityId);
      contentDocumentIds.add(cdl.ContentDocumentId);
    }

    // Do a bulk query to fetch the contacts and content documents
    Map<Id, ContentDocument> idToCD = new Map<Id, ContentDocument>(
      [
        SELECT Id, ParentId
        FROM ContentDocument
        WHERE Id IN :contentDocumentIds
        WITH USER_MODE
      ]
    );
    Map<Id, Contact> idToContact = new Map<Id, Contact>(
      [
        SELECT Id
        FROM Contact
        WHERE Id IN :contactIds
        WITH USER_MODE
      ]
    );

    // Determine and set the signature image url of the contact the
    // file is being linked to, to a download link for the file.
    String baseURL = System.URL.getOrgDomainUrl().toExternalForm();
    List<Contact> contactsToUpdate = new List<Contact>();
    for (ContentDocumentLink cdl : newList) {
      // Get the content document
      ContentDocument cd = idToCD.get(cdl.ContentDocumentId);

      // Check that the document is in the signatures workspace.
      // This is to make sure it is a signature, and not just a
      // random file attached to the contact.
      if (cd != null && cd.ParentId == sigWS.Id) {
        // Get the contact the signature is attached to
        Contact contact = idToContact.get(cdl.LinkedEntityId);

        // So community users can see the image
        cdl.Visibility = 'AllUsers';

        // Determine the signature image url
        contact.UHN_Signature_Image_URL__c =
          baseURL +
          '/sfc/servlet.shepherd/document/download/' +
          cdl.ContentDocumentId;

        contactsToUpdate.add(contact);
      }
    }

    if (!Schema.sObjectType.Contact.isUpdateable()) {
      throw new System.SecurityException(
        'Insufficient access to update Contact'
      );
    }
    update contactsToUpdate;
  }
}
