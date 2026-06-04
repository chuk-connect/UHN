trigger UHN_SetSignatureURLTrigger on ContentDocumentLink(
  before insert,
  before update
) {
  UHN_SetSignatureURLTriggerHandler.execute(Trigger.new);
}
