/**
 * Trigger handler for AAR_ScholarlyOutput_VerificationSync.
 * Keeps Is_Verified__c and Verification_Status__c in sync on AAR_Scholarly_Output__c.
 */
public with sharing class AAR_ScholarlyOutputSyncHandler {
  /**
   * Syncs Is_Verified__c and Verification_Status__c bidirectionally.
   * @param newList records in Trigger.new
   * @param oldMap records in Trigger.oldMap (null on insert)
   */
  @SuppressWarnings(
    'PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.AvoidDeeplyNestedIfStmts'
  )
  public static void syncVerificationFields(
    List<AAR_Scholarly_Output__c> newList,
    Map<Id, AAR_Scholarly_Output__c> oldMap
  ) {
    for (AAR_Scholarly_Output__c newRec : newList) {
      AAR_Scholarly_Output__c oldRec = (oldMap != null)
        ? oldMap.get(newRec.Id)
        : null;

      Boolean isVerifiedChanged = (oldRec == null)
        ? newRec.Is_Verified__c == true
        : newRec.Is_Verified__c != oldRec.Is_Verified__c;

      Boolean statusChanged = (oldRec == null)
        ? String.isNotBlank(newRec.Verification_Status__c)
        : newRec.Verification_Status__c != oldRec.Verification_Status__c;

      if (isVerifiedChanged) {
        applyIsVerifiedChange(newRec);
      } else if (statusChanged) {
        newRec.Is_Verified__c =
          newRec.Verification_Status__c ==
          VerificationReconciliationService.STATUS_VERIFIED;
      }
    }
  }

  private static void applyIsVerifiedChange(AAR_Scholarly_Output__c newRec) {
    if (newRec.Is_Verified__c) {
      setVerified(newRec);
    } else {
      clearVerified(newRec);
    }
  }

  private static void setVerified(AAR_Scholarly_Output__c newRec) {
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
  }

  private static void clearVerified(AAR_Scholarly_Output__c newRec) {
    if (
      newRec.Verification_Status__c ==
      VerificationReconciliationService.STATUS_VERIFIED
    ) {
      newRec.Verification_Status__c = VerificationReconciliationService.STATUS_PROPOSED;
      newRec.Verified_At__c = null;
      newRec.Verified_By__c = null;
    }
  }
}
