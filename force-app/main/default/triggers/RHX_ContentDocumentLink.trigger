trigger RHX_ContentDocumentLink on ContentDocumentLink(
  after delete,
  after insert,
  after undelete,
  after update,
  before delete
) {
  RHX_ContentDocumentLinkHandler.execute(Trigger.oldMap, Trigger.newMap);
}
