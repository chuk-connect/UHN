/**
 * UHN_Publication_Author_SourceSyncHandler
 * ------------------------------------------
 * Reference handler showing how an integration entry point feeds the
 * Verification Framework. NOT a record trigger — this is meant to be
 * called from a Wellspring (or other source-system) sync routine,
 * platform event handler, or Apex REST endpoint.
 *
 * The handler's job is narrow: translate the source system's payload shape
 * into the framework's SourceUpsert DTO, then call reconcile(). The rule
 * engine does everything else.
 *
 * Copy this class and rename the fields when adding the next verifiable
 * object (UHN_FCC__c for grants, ethics review records, etc.). The shape
 * of the handler is identical regardless of object — that's the whole point
 * of building this as platform.
 */
public with sharing class UHN_Publication_Author_SourceSyncHandler {
  /**
   * Called by the Wellspring sync. Each WellspringPubPayload represents
   * one author-on-publication record from the source system.
   * @param incoming List of WellspringPubPayload DTOs from the source system.
   */
  public static void handleIncoming(List<WellspringPubPayload> incoming) {
    if (incoming == null || incoming.isEmpty()) {
      return;
    }

    List<VerificationReconciliationService.SourceUpsert> upserts = new List<VerificationReconciliationService.SourceUpsert>();

    for (WellspringPubPayload p : incoming) {
      // Project the source payload into the canonical map. Keys must
      // match the field API names on UHN_Publication_Author__c —
      // anything that doesn't match is silently ignored by the service.
      Map<String, Object> projection = new Map<String, Object>{
        'Title__c' => p.title,
        'Role__c' => p.authorRole,
        'Data_Origin__c' => 'Wellspring'
      };

      upserts.add(
        new VerificationReconciliationService.SourceUpsert(
          UHN_Publication_Author__c.SObjectType,
          p.wellspringId,
          projection
        )
      );
    }

    // The service handles bulk safety, the rule engine, and the change log.
    // We just hand it the batch.
    VerificationReconciliationService.reconcile(upserts);
  }

  /**
   * Wire DTO. Source systems will deserialize their payloads into this.
   * Kept dumb — no behaviour. The translation to the framework's shape
   * happens in handleIncoming.
   */
  public class WellspringPubPayload {
    public String wellspringId;
    public String title;
    public String authorRole;
  }
}
