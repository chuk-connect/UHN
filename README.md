# Business Hub Verification Framework

> Drop-in deployable SFDX source package for verifying source-system data against principal investigator (PI) judgment. Reusable across Business Hub modules via field set configuration.

## Project Overview

| | |
|---|---|
| **Salesforce API Version** | 63.0 |
| **Namespace** | Unmanaged |
| **Default Branch** | `feature/dev` |
| **Org Alias** | `uhn-sandbox` |

### Architecture

The framework has three layers:

1. **Rule Engine** — `VerificationReconciliationService.cls`: Bulk-safe Apex service implementing a five-branch reconciliation rule that merges `Source_Payload__c` (raw source JSON) with `Override_Payload__c` (PI corrections delta) to determine final field values and `Verification_Status__c`.

2. **API Surface** — `VerificationCardController.cls`: `@AuraEnabled` controller exposing field set queries, record reads, save/verify operations, and change event retrieval to the LWC.

3. **UI Layer** — `lwc/verificationCard/`: Single LWC component rendering Proposed/Verified/Manual rows with per-row Verify, Verify All, and inline edit modal. Uses Change Data Capture (CDC) for auto-refresh.

### Framework Schema Fields

Every verifiable object requires these fields:

| Field | Type | Purpose |
|---|---|---|
| `Verification_Status__c` | Picklist | Proposed / Verified / Manual / Superseded |
| `Source_Hash__c` | String | Idempotency key for detecting source changes |
| `Source_Payload__c` | Long Text | Raw source fields as JSON |
| `Override_Payload__c` | Long Text | PI corrections as JSON delta |
| `Verified_At__c` | Datetime | Audit stamp |
| `Verified_By__c` | Lookup(User) | Audit stamp |
| `External_Id__c` | String | Source system key |
| `Is_Verified__c` | Boolean | Checkbox mirror of Verified status |

### Key Conventions

- Triggers are thin — business logic lives in handler/service classes
- `Verification_Change_Event__c` is append-only — never update or delete records
- `Verification_Binding__mdt` maps a parent object to a child object + field set
- `UHN_Publication_Author_SourceSyncHandler.cls` is the reference template for new integrations

---

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
