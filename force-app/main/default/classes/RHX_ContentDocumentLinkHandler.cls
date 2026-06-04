/** Trigger handler for RHX rollup on ContentDocumentLink. Delegates to the rh2.ParentUtil managed package. */
public without sharing class RHX_ContentDocumentLinkHandler {
  /**
   * Executes the rh2 rollup for ContentDocumentLink records.
   * @param oldMap old record map
   * @param newMap new record map
   */
  public static void execute(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
    Type rollClass = System.Type.forName('rh2', 'ParentUtil');
    if (rollClass != null) {
      rh2.ParentUtil pu = (rh2.ParentUtil) rollClass.newInstance();
      if (Trigger.isAfter) {
        pu.performTriggerRollups(
          oldMap,
          newMap,
          new List<String>{ 'ContentDocumentLink' },
          null
        );
      }
    }
  }
}
