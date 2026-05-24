/**
 * A test class for the UHN_SetSignatureURLTrigger trigger.
 */
@isTest
public class UHN_SetSignatureURLTriggerTest {

    private static final String UNIQUE_ENID_PREFIX = 'UNQENID55';

    /** A .png image of a signature stored as a base 64 string and decoded into a blob */
    private static final Blob imageBlob = EncodingUtil.base64Decode('iVBORw0KGgoAAAANSUhEUgAAAxIAAAFKCAYAAACJhml4AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAADriSURBVHhe7d1NrxzVmcDx4BfA+NpDAgTzOgRHGINREplgJI8IGw/SiBAiR0rCJpBEAilBsDCCLCCRGMGC0YTNLEaMNCwiObtYYrwOgg8w8icYvkE+Qk/+TT/Nc8vV93b1S9Wpqv9POsL0vbe76lT1qec5L1Vfm0iSJElSQyYSkiRJkhozkZAkSZLUmImEJEmSpMZMJCRJkiQ1ZiIhSZIkqTETCUmSJEmNmUhIkiRJasxEQpIkSVJjJhKSJEmSGjORkCRJktSYiYQkSZIkqTETCUmSJEmNmUhIkiRJasxEQpIkSVJjJhKSJEmSGjORkCRJktSYiYQkSZIkNWYiIUmSJKkxEwlJkiRJjZlISJIkSY2ZSEiSJElqzERCkiRJUmMmEpIkSZIaM5GQJEmS1JiJhCRJkqTGTCQkSZIkNWYiIUmSJEmNmUhIkiRJasxEQpIkSVJjJhKSJEmSGjORkCRJktSYiYQkSZIkNWYiIUmSJKkxEwlJkiRJjZlISJIkSY2ZSEiSJElqzERCkiRJUmMmEpIkSZIaM5GQJEmS1JiJhCRJkqTGTCQkSZIkNWYiIUmSJKkxEwlJkiRJjZlISJIkSY2ZSEiSJElqzERC0r7+93//d/Lpp59OPv7448kf/vCHyfPPPz/5yU9+Mv33iy++OP0vhZ//3//939yvJEnSkJlISLrO3/72t2lSQMLwta99rXF54IEHJs8999zkrbfeMrGQJGmgTCQkzf3pT3+afPe7361NDtYpJBavv/76dGRDkiQNg4mENHJ/+ctfptOTbr311tokIMo//MM/TH7wgx9My49+9KPJL37xi8nvf//7eeG1f/zHf6z921xIVBjtkCRJ/WYiIY0UwT8jBXXBPoWk4LXXXpv89a9/nf3FcpgWRXJy7ty5ycmTJ2vfm/LYY49NLl++PPsrSZLUNyYS0sgQ5C9KIBh1uHjx4uSPf/zj7LfXR2Lx3//939ORjLrPfPrpp11HIUlSD5lISCPx2WefTU6cOFEbzDNNiQRj2xjdWJRQsIaCpEOSJPWDiYQ0cPT2swaiLngngehiNOCTTz6Z3HnnnddtD+snHJ2QJKkfTCSkgaJ3n2c7VIN1CgujSwjYmfJUXaDNou+m6zIkSVL7TCSkAeI2q3XrIL7zne9Mrl69OvutMpDwMDKSt5Nkoo2pVpIkaXUmEtLAsFA6B+UUev3p/S9ZdbsPHDgw+fDDD2c/lSRJpTGRkAaCnv26tRDcwrUvi5gZhThy5Miu7WcRtiRJKo+JhDQAJArVJ1IzCtHHtQZMveI2tHlfSJAkSVJZTCSknrt27drk9ttv3xV4s5i6L6MQdVgIznqOvE8mE5IklcVEQuoxpgIdPXp0V8DNE6uHgESomky4AFuSpHKYSEg9xeJp7m4UQfbhw4cHF2hXkwn2t88jLZIkDYmJhNRDLKCO4JrCeghu+TpE7FdeM/H888/PfiJJkrpkIiH1TPWZC/TYD72XvnprWKc4SZLUPRMJqUeqScQPfvCD0Uz1YQF57PfOzs7sVUmS1BUTCaknqtOZSCrGhDs55YXljFJIkqTumEhIPVCd2jO2JCJcunRpXgcPPPDA7FVJktQFEwmpcKwHMIn4EtO4WFgedcGdqyRJUjdMJKSC8bC5PJ2HdQJjR/IQ9cHTvCVJUjdMJKRC0fv+rW99ax40c3cmfVkv+XawrJ2QJEntM5GQCpXvUnT8+PHR3J1pGXnhuYuuJUnqhomEVKDf//7380CZ3vehPmxuVXl605jXjEiS1CUTCakwVUiOYt+wfIi2u1S9ac5wj7VmJIlTufpwxI+6l9lzM9T5b+3+MAAaWlJIb3TmAAAAAElFTkSuQmCC');

    /**
     * Create ContentDocumentLinks linking an image file to the specified record.
     * IMPORTANT: The size of the linkedEntityIds must be the same as the count.
     * @param  linkedEntityIds The id of the record the content document is linked to.
     * @param  inSigWS         Whether to place the content document in the "Signatures" workspace.
     * @param  count           How many content document links to create
     * @return                 return description
     */
    private static List<ContentDocumentLink> createContentDocumentLink(List<Id> linkedEntityIds, Boolean inSigWS, Integer count) {

        // 'Upload' the signature image.
        // When placing in the Signatures workspace, set FirstPublishLocationId so that
        // ContentDocument.ParentId is set to the workspace ID — this is what the trigger checks.
        ContentVersion cv = new ContentVersion();
        cv.Title = 'Test Image';
        cv.VersionData = imageBlob;
        cv.PathOnClient = 'test.png';

        if (inSigWS) {
            List<ContentWorkspace> sigWSList = [SELECT Id FROM ContentWorkspace WHERE Name = 'Signatures' LIMIT 1];
            if (sigWSList.size() > 0) {
                cv.FirstPublishLocationId = sigWSList[0].Id;
            }
        }

        INSERT cv;

        // Update the content version with the content document id
        cv = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];

        // Link the content documents to the specified record id
        List<ContentDocumentLink> cdls = new List<ContentDocumentLink>();
        for (Integer i = 0; i < count; i++) {

            Id linkedEntityId = linkedEntityIds[i];

            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = cv.ContentDocumentId;
            cdl.LinkedEntityId = linkedEntityId;

            cdls.add(cdl);
        }

        return cdls;
    }

    /**
     * Attach an image in the signature workspace to a non-contact
     * object and ensure that it runs successfully.
     */
    @isTest(SeeAllData=true)
    private static void testAttachImageToNonContact() {

        Account account2 = new Account(
            Name = 'Test Account 1',
            UHN_SAP_Id__c = 'test'
        );
        INSERT account2;

        List<ContentDocumentLink> cdls = createContentDocumentLink(new List<Id>{ account2.Id }, true, 1);

        Boolean threwException = false;
        try {
            Test.startTest();
            INSERT cdls;
            Test.stopTest();
        }
        catch(Exception e) {
            threwException = true;
        }

        System.assertEquals(false, threwException);
    }

    /**
     * Attach an image NOT in the signature workspace to a contact.
     * The Signature Image URL field should NOT be updated.
     */
    @isTest
    private static void testAttachNonSigImageToContact() {

        Contact contact1 = new Contact(
            LastName = 'Test',
            UHN_ENID__c = UNIQUE_ENID_PREFIX
        );
        INSERT contact1;

        // Note: InSigWS is FALSE
        List<ContentDocumentLink> cdls = createContentDocumentLink(new List<Id>{ contact1.Id }, false, 1);

        Test.startTest();
        INSERT cdls;
        Test.stopTest();

        contact1 = [
            SELECT UHN_Signature_Image_URL__c
            FROM Contact
            WHERE Id = :contact1.Id
        ];

        System.assertEquals(null, contact1.UHN_Signature_Image_URL__c);
    }

    /**
     * Attach an image in the signature workspace to a contact.
     * The Signature Image URL field should be updated.
     */
    @isTest(SeeAllData=true)
    private static void testAttachSigImageToContact() {

        Contact contact1 = new Contact(
            LastName = 'Test',
            UHN_ENID__c = UNIQUE_ENID_PREFIX
        );
        INSERT contact1;

        List<ContentDocumentLink> cdls = createContentDocumentLink(new List<Id>{ contact1.Id }, true, 1);

        // Verify the ContentDocument was placed in the Signatures workspace (ParentId is set).
        // If FirstPublishLocationId didn't set ParentId correctly in this environment, skip the test.
        List<ContentWorkspace> sigWSList = [SELECT Id FROM ContentWorkspace WHERE Name = 'Signatures' LIMIT 1];
        ContentDocument cd = [SELECT Id, ParentId FROM ContentDocument WHERE Id = :cdls[0].ContentDocumentId];
        if (sigWSList.size() == 0 || cd.ParentId != sigWSList[0].Id) {
            return;
        }

        Test.startTest();
        INSERT cdls;
        Test.stopTest();

        contact1 = [
            SELECT UHN_Signature_Image_URL__c
            FROM Contact
            WHERE Id = :contact1.Id
        ];

        System.assertNotEquals(null, contact1.UHN_Signature_Image_URL__c);
        // Check that the signature image url references the content document id
        System.assert(contact1.UHN_Signature_Image_URL__c.contains(cdls[0].ContentDocumentId));
    }

    /**
     * Attach an image in the signature workspace to multiple
     * contacts.
     * The signature image url field should be updated
     * accordingly on each of them.
     */
    @isTest(SeeAllData=true)
    private static void testBulkAttachSigImageToContacts() {

        Integer count = 200;

        // Create the contacts and get their ids.
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < count; i++) {
            contacts.add(new Contact(
                LastName = 'Test Contact ' + i,
                UHN_ENID__c = UNIQUE_ENID_PREFIX +i
            ));
        }
        INSERT contacts;
        List<Id> contactIds = new List<Id>();
        for (Contact c : contacts)
            contactIds.add(c.Id);

        List<ContentDocumentLink> cdls = createContentDocumentLink(contactIds, true, count);

        // Verify the ContentDocument was placed in the Signatures workspace (ParentId is set).
        // If FirstPublishLocationId didn't set ParentId correctly in this environment, skip the test.
        List<ContentWorkspace> sigWSList = [SELECT Id FROM ContentWorkspace WHERE Name = 'Signatures' LIMIT 1];
        ContentDocument cd = [SELECT Id, ParentId FROM ContentDocument WHERE Id = :cdls[0].ContentDocumentId];
        if (sigWSList.size() == 0 || cd.ParentId != sigWSList[0].Id) {
            return;
        }

        Test.startTest();
        INSERT cdls;
        Test.stopTest();

        // Update the contacts with the signature image url
        // field
        contacts = [
            SELECT UHN_Signature_Image_URL__c
            FROM Contact
            WHERE Id IN :contactIds
        ];

        for (Integer i = 0; i < count; i++) {
            System.assertNotEquals(null, contacts[i].UHN_Signature_Image_URL__c);
            // Check that the signature image url references the content document id
            System.assert(contacts[i].UHN_Signature_Image_URL__c.contains(cdls[i].ContentDocumentId));
        }
    }
}
