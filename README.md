# Business Hub Verification Framework

Reference implementation of the framework described in the strategy deck. Drop-in deployable as an SFDX source package.

## What's included

**Apex (`force-app/main/default/classes/`)**
- `VerificationReconciliationService` — the rule engine. Bulk-safe entry point (`reconcile`) plus `markVerified`, `applyOverride`, `createManual`. Encodes all five branches of the reconciliation rule.
- `VerificationCardController` — `@AuraEnabled` surface for the LWC. Source/override merge happens here, in Apex, per the architectural decision (LWC stays dumb).
- `VerificationException` — typed exception for caller-fixable errors.
- `VerificationReconciliationServiceTest` — covers all five rule cases, idempotency of `markVerified`, incremental override merge, bulk safety (200 records, asserts on SOQL/DML counts), empty input, and createManual.
- `UHN_Publication_Author_SourceSyncHandler` — reference integration handler. Copy-paste template for the next verifiable object.

**LWC (`force-app/main/default/lwc/verificationCard/`)**
- `verificationCard` — the `c-verification-card` component. Three inputs: `recordId`, `childObjectApiName`, `fieldSetName`. Renders Proposed/Verified/Manual rows, supports per-row Verify, Verify All, and inline edit modal that produces a JSON delta of only the fields the PI changed.

**Schema (`force-app/main/default/objects/`)**
- `Verification_Change_Event__c` — append-only audit log. Fields: `Subject_Record_Id__c`, `External_Id__c`, `Event_Type__c` (restricted picklist matching the seven service constants), `Before_Payload__c`, `After_Payload__c`, `Actor_User_Id__c`, `Occurred_At__c`.
- `UHN_Publication_Author__c` — verifiable child object with the framework metadata fields (`Verification_Status__c`, `Source_Hash__c`, `Source_Payload__c`, `Override_Payload__c`, `Verified_At__c`, `Verified_By__c`, `External_Id__c`) plus business fields (`Title__c`, `Role__c`) and the `AAR__c` parent lookup.
- `Verification_Binding__mdt` — custom metadata type for parent-relationship config. Lets the LWC render against any parent without code changes.

## Deploying

Standard SFDX deploy:

```bash
sfdx force:source:deploy -p force-app
```

You'll need to:
1. Create an `AAR_Verification` field set on `UHN_Publication_Author__c` (or pass a different field set name in the LWC config). The field set defines which fields the card renders and edits.
2. Create the parent object referenced by `AAR__c` (the deck assumes `UHN_AAR__c` exists). If your AAR object is named differently, change the `referenceTo` in `AAR__c.field-meta.xml` before deploying, OR add a `Verification_Binding__mdt` record pointing at the right lookup field.
3. Drop `c-verification-card` onto the AAR record page in App Builder. Set the child object and field set properties.

## What this implementation deliberately does NOT include

These are out of scope for the reference but should be added before production:

- **Notification on drift events.** When `Source Changed Under Verified` fires, the deck calls for "optionally notify the PI." Wire this to a flow or platform event subscriber. The event row gives you everything you need.
- **EXP-03 bulk export.** The change event log is the data source. Build the exporter as a separate batch class — keep it out of the framework so the framework stays an abstraction layer, not a feature.
- **Optimistic locking.** `applyOverride` does a last-write-wins merge at the field level. For high-contention records, add a `LastModifiedDate` check on the LWC roundtrip and surface conflicts.
- **Permissions.** The classes use `with sharing` and check `isAccessible`/`isUpdateable` for FLS. A permission set bundling object + field permissions per role (PI, admin, integration user) is a separate deliverable.
- **Field set definition.** The framework reads the field set; you create it. This is intentional — it's the seam where each module configures itself.

## File map

```
force-app/main/default/
├── classes/
│   ├── VerificationException.cls(+meta)
│   ├── VerificationReconciliationService.cls(+meta)
│   ├── VerificationReconciliationServiceTest.cls(+meta)
│   ├── VerificationCardController.cls(+meta)
│   └── UHN_Publication_Author_SourceSyncHandler.cls(+meta)
├── lwc/verificationCard/
│   ├── verificationCard.html
│   ├── verificationCard.js
│   ├── verificationCard.css
│   └── verificationCard.js-meta.xml
└── objects/
    ├── Verification_Change_Event__c/  (object + 7 fields)
    ├── UHN_Publication_Author__c/      (object + 10 fields)
    └── Verification_Binding__mdt/      (CMT + 2 fields)
```
