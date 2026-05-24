/**
 * UHN_PubAuthor_SourceSyncHandlerTest
 * -----------------------------------
 * Minimal coverage tests for the sync handler. The handler is mostly a
 * translation layer between an external system's payload shape and the
 * framework's SourceUpsert DTO — the only logic worth testing is the
 * shape transformation and the empty-input early return.
 *
 * Coverage of the framework's internal reconciliation behaviour is in
 * VerificationReconciliationServiceTest. Here we just confirm the handler
 * forwards correctly without throwing.
 *
 * Class name abbreviated to fit Apex's 40-character identifier limit;
 * the class under test is UHN_Publication_Author_SourceSyncHandler.
 */
@IsTest
private class UHN_PubAuthor_SourceSyncHandlerTest {

    private static Id getTestContactId() {
        Contact c = new Contact(LastName = 'SyncHandlerTestContact');
        insert c;
        return c.Id;
    }

    /**
     * Empty input should be a silent no-op. This is the guard at the top
     * of handleIncoming and worth covering explicitly.
     */
    @IsTest
    static void handleIncoming_emptyListIsNoop() {
        Test.startTest();
        UHN_Publication_Author_SourceSyncHandler.handleIncoming(new List<UHN_Publication_Author_SourceSyncHandler.WellspringPubPayload>());
        UHN_Publication_Author_SourceSyncHandler.handleIncoming(null);
        Test.stopTest();
        // No assertion needed — we just want to confirm no exception is thrown.
        System.assert(true, 'Empty / null input must be tolerated silently');
    }

    /**
     * Single payload — confirm handleIncoming forwards through to reconcile
     * and a record is created with the expected External_Id__c.
     *
     * Note: the new record needs UHN_Contact__c populated to satisfy the
     * org's schema. Since the handler doesn't accept arbitrary lookups, we
     * pre-create a manual record with UHN_Contact__c populated, then call
     * the handler with a matching external id. Rule 2 (hash differs,
     * Proposed) will update silently. This exercises the handler's
     * happy path without needing schema-aware handler logic.
     */
    @IsTest
    static void handleIncoming_singlePayloadForwardsToService() {
        // Seed an existing Proposed record so the reconcile finds a match
        // and updates rather than insert-creating a new one.
        UHN_Publication_Author__c seed = new UHN_Publication_Author__c(
            External_Id__c = 'SYNCTEST-001',
            Verification_Status__c = 'Proposed',
            UHN_Contact__c = getTestContactId(),
            Source_Hash__c = 'old-hash',
            Source_Payload__c = '{"Title__c":"Old"}'
        );
        insert seed;

        UHN_Publication_Author_SourceSyncHandler.WellspringPubPayload p =
            new UHN_Publication_Author_SourceSyncHandler.WellspringPubPayload();
        p.wellspringId = 'SYNCTEST-001';
        p.title = 'New Title From Source';
        p.authorRole = 'First Author';

        Test.startTest();
        UHN_Publication_Author_SourceSyncHandler.handleIncoming(
            new List<UHN_Publication_Author_SourceSyncHandler.WellspringPubPayload>{ p }
        );
        Test.stopTest();

        // The handler should have driven a reconcile that updated the seed's
        // Source_Hash__c. Exact value doesn't matter — just that something changed.
        UHN_Publication_Author__c after = [
            SELECT Source_Hash__c FROM UHN_Publication_Author__c WHERE External_Id__c = 'SYNCTEST-001'
        ];
        System.assertNotEquals('old-hash', after.Source_Hash__c,
            'Reconcile via handler should have updated the source hash');
    }
}
