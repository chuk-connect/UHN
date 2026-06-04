/**
 * UHN_PublicationAuthor_RecordTypeSync
 * ----------------------------------------
 * Assigns Proposed or Manual_Entry Record Type on insert based on Data_Origin__c.
 *
 * Assignment rule (BH-1159):
 *   Data_Origin__c = Manual (or blank)  → Manual_Entry
 *   Data_Origin__c = ORCID / Wellspring / Integration → Proposed
 *
 * The Proposed → Verified transition is handled by the BH-1249 verification
 * Screen Flow, not by this trigger.
 *
 * Note: Verification status lives on UHN_Publication_Author__c (junction),
 * not on UHN_Publication__c itself, so one PI verifying a publication
 * does not affect another PI's verification state for the same publication.
 */
trigger UHN_PublicationAuthor_RecordTypeSync on UHN_Publication_Author__c(
  before insert
) {
  AAR_RecordTypeAssignmentService.assign(
    Trigger.new,
    'UHN_Publication_Author__c'
  );
}
