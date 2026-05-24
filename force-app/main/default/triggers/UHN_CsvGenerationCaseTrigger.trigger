trigger UHN_CsvGenerationCaseTrigger on Case(after update) {
  CreateAndAttachCSVHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
}
