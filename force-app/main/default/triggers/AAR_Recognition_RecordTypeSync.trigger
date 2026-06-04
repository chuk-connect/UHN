/**
 * AAR_Recognition_RecordTypeSync
 * --------------------------------
 * Assigns the Manual_Entry Record Type on insert.
 * AAR_Recognition__c has no source system — all records are PI-authored,
 * so Manual_Entry is always the correct type.
 *
 * BH-1159: Record Types for verification status on AAR child objects.
 */
trigger AAR_Recognition_RecordTypeSync on AAR_Recognition__c(before insert) {
  AAR_RecordTypeAssignmentService.assign(Trigger.new, 'AAR_Recognition__c');
}
