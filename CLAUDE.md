# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Business Hub Verification Framework — a drop-in deployable SFDX source package for verifying source-system data against principal investigator (PI) judgment. Reusable across Business Hub modules via field set configuration.

**Salesforce API Version:** 63.0  
**Namespace:** unmanaged (none)

## Common Commands

```bash
# Install dependencies
npm install

# Lint LWC/Aura JavaScript
npm run lint

# Format all code (Apex, Lightning, CSS, HTML, JS, JSON, MD, XML, YAML)
npm run prettier

# Verify formatting without writing changes
npm run prettier:verify

# Run LWC Jest unit tests
npm run test

# Run tests in watch mode
npm run test:unit:watch

# Generate test coverage report
npm run test:unit:coverage

# Run tests in debug mode (attach node debugger)
npm run test:unit:debug
```

**Salesforce deployments (via SF CLI):**
```bash
# Deploy source to connected org
sfdx force:source:deploy -p force-app

# Pull changes from scratch org
sfdx force:source:pull

# Check source status
sfdx force:source:status
```

**Scratch org setup:**
```bash
sfdx org login web
sfdx org create scratch --definition-file config/project-scratch-def.json
sfdx force:source:deploy -p force-app
```

## Architecture

### Core Framework Components

The verification framework has three layers:

1. **Rule Engine** — `VerificationReconciliationService.cls`: Bulk-safe Apex service implementing a five-branch reconciliation rule that merges `Source_Payload__c` (raw source JSON) with `Override_Payload__c` (PI corrections delta) to determine final field values and `Verification_Status__c`.

2. **API Surface** — `VerificationCardController.cls`: `@AuraEnabled` controller exposing field set queries, record reads, save/verify operations, and change event retrieval to the LWC.

3. **UI Layer** — `force-app/main/default/lwc/verificationCard/`: Single LWC component rendering proposed/verified/manual rows with per-row Verify, Verify All, and inline edit modal. Uses Change Data Capture (CDC) for auto-refresh. Configurable via four properties: `cardTitle`, `childObjectApiName`, `fieldSetName`, `recordId`.

### Framework Schema Fields

Every verifiable object must have these fields:

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

### Custom Metadata for Configuration

`Verification_Binding__mdt` records map a parent object to a child object + field set. Create records manually after deployment to wire up new verifiable objects.

### Integration Template

`UHN_Publication_Author_SourceSyncHandler.cls` is the reference template for connecting a source system to the framework — copy and adapt for new integrations.

### Audit Log

`Verification_Change_Event__c` is append-only. Never update or delete records on this object.

### Trigger Conventions

Triggers in `force-app/main/default/triggers/` are thin — business logic lives in handler/service classes. `AAR_ScholarlyOutput_VerificationSync.trigger` syncs `Verification_Status__c` ↔ `Is_Verified__c` bidirectionally.

## Testing

LWC unit tests use `@salesforce/sfdx-lwc-jest`. Apex tests follow the `*Test.cls` naming convention and are colocated with their classes. `UHN_TestDataFactory.cls` provides shared test data builders.

Pre-commit hooks (Husky + lint-staged) run ESLint and Prettier automatically on staged files.
