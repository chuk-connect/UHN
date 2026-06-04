/**
 * AAR_ScholarlyOutput_VerificationSync
 * -------------------------------------
 * Keeps Is_Verified__c and Verification_Status__c in sync on
 * AAR_Scholarly_Output__c so changes made from either direction
 * (LWC card or direct record edit) stay consistent.
 *
 * Direction A — Is_Verified__c changed:
 *   true  → set Verification_Status__c = Verified, stamp Verified_At/By
 *   false → reset Verification_Status__c = Proposed, clear Verified_At/By
 *
 * Direction B — Verification_Status__c changed (without Is_Verified__c changing):
 *   Verified     → set Is_Verified__c = true
 *   anything else → set Is_Verified__c = false
 *
 * Using before insert/update avoids an extra DML round-trip and breaks
 * potential recursion because the modified in-memory values become the
 * "old" values for any subsequent trigger evaluation of the same record.
 */
trigger AAR_ScholarlyOutput_VerificationSync on AAR_Scholarly_Output__c(
  before insert,
  before update
) {
  AAR_ScholarlyOutputSyncHandler.syncVerificationFields(
    Trigger.new,
    Trigger.oldMap
  );
}
