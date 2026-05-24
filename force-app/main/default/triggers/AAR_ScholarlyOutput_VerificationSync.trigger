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
  for (AAR_Scholarly_Output__c newRec : Trigger.new) {
    AAR_Scholarly_Output__c oldRec = Trigger.isUpdate
      ? Trigger.oldMap.get(newRec.Id)
      : null;

    Boolean isVerifiedChanged = oldRec == null
      ? newRec.Is_Verified__c == true
      : newRec.Is_Verified__c != oldRec.Is_Verified__c;

    Boolean statusChanged = oldRec == null
      ? String.isNotBlank(newRec.Verification_Status__c)
      : newRec.Verification_Status__c != oldRec.Verification_Status__c;

    if (isVerifiedChanged) {
      // Direction A: Is_Verified__c is the source of truth for this change.
      if (newRec.Is_Verified__c) {
        if (
          newRec.Verification_Status__c !=
          VerificationReconciliationService.STATUS_VERIFIED
        ) {
          newRec.Verification_Status__c = VerificationReconciliationService.STATUS_VERIFIED;
        }
        if (newRec.Verified_At__c == null) {
          newRec.Verified_At__c = System.now();
        }
        if (newRec.Verified_By__c == null) {
          newRec.Verified_By__c = UserInfo.getUserId();
        }
      } else {
        if (
          newRec.Verification_Status__c ==
          VerificationReconciliationService.STATUS_VERIFIED
        ) {
          newRec.Verification_Status__c = VerificationReconciliationService.STATUS_PROPOSED;
          newRec.Verified_At__c = null;
          newRec.Verified_By__c = null;
        }
      }
    } else if (statusChanged) {
      // Direction B: Verification_Status__c changed independently — mirror to checkbox.
      newRec.Is_Verified__c =
        newRec.Verification_Status__c ==
        VerificationReconciliationService.STATUS_VERIFIED;
    }
  }
}
