---
name: salesforce-delivery-validator
description: "After Salesforce work is completed, produce a strict handoff with what was completed, what was not completed or not verified, and a Salesforce-specific validation guide for Apex, Flow, deployments, sandbox testing, permissions, and data checks, and a final Git workflow checkpoint before PR creation and remote push."
---

# Salesforce Delivery Validator

Use this skill after any Salesforce-related implementation, code completion, configuration change, deployment prep, or troubleshooting task.

This skill is Salesforce-first and must prioritize:

- Apex classes, triggers, and test classes.
- Flows and Flow interviews.
- Validation rules.
- Lightning pages and component changes.
- Permission sets, profiles, field-level security, record types, and sharing.
- Sandbox, UAT, and production validation.
- Deployment, pull request prep, and regression testing.
- Manual confirmation before pushing to the remote repository.

## Core objective

After a successful Salesforce task, always produce a structured handoff that tells the user:

1. What was completed.
2. What was not completed, not deployed, or not verified.
3. Exactly how to validate the work in the correct org.
4. Whether the work is ready for pull request creation.
5. Whether the user must manually confirm before any push to the Git remote repository.

Do not give a generic summary. Be specific to Salesforce metadata, behavior, environment, and Git workflow state.

## Required response structure

Always respond with these sections in this exact order:

## Completed

Summarize what was actually delivered.

- State the Salesforce object, feature, or metadata touched.
- Mention the exact artifact when known, such as Apex class, trigger, Flow, validation rule, permission set, report, or Lightning page.
- Include whether the change is draft, ready for sandbox testing, deployment-ready, PR-ready, or production-ready.

## Not Completed or Not Verified

List everything that still needs attention.
Include:

- Items not implemented.
- Tests not run.
- Deployments not completed.
- Sandbox, UAT, or production behavior not verified.
- Permission, sharing, or FLS assumptions.
- Data setup, integration, or record type dependencies.
- Any edge case or limitation.
- Whether a pull request has not yet been created.
- Whether the remote Git push has not yet been manually confirmed by the user.

If nothing is missing, say:

- No known functional gaps in the drafted output.
- Final validation in the target Salesforce org is still required.
- Pull request creation is pending.
- Remote repository push must be manually confirmed by the user.

## Validation Guide

Provide a numbered Salesforce validation checklist.

Each step must include:

- Step.
- Expected result.
- If not, what to check next.

The guide must be tailored to the actual Salesforce feature involved and should not be generic.

## Git Handoff Checkpoint

After validation, include a separate checkpoint that states:

- Whether the work is ready for PR creation.
- Whether the branch is ready for remote push.
- That the user must manually confirm pushing to the remote repository before any push occurs.

Use this exact rule:

- Never assume permission to push.
- Never state that a remote push was completed unless the user explicitly confirmed it.
- If the work is ready but not yet pushed, say so clearly.
- If the work is not ready for PR, explain what still blocks it.

## Final Validation Status

End with one clear status line using one of:

- Pending user validation in sandbox.
- Pending user validation in production.
- Ready for PR, awaiting manual push confirmation.
- Verified in target org.
- Blocked by access, deployment, or data constraints.

## Salesforce validation rules

When the task involves Salesforce, apply these rules:

- Identify the target org first: sandbox, UAT, or production.
- If Apex changed, mention test class execution, code coverage, and any failing tests.
- If Flow changed, mention activation state, Flow debug, and sample record testing.
- If deployment is involved, mention deployment success, metadata status, and post-deploy checks.
- If permissions matter, verify profile access, permission sets, field-level security, and record type access.
- If record behavior matters, test with realistic sample records and the correct user type.
- If automation matters, confirm downstream effects like email alerts, field updates, approvals, tasks, or integrations.
- If integration matters, confirm logs, request/response behavior, and failure handling.
- If page layout or Lightning changes matter, verify page assignment and user experience in the right app and form factor.

## Apex mode

If Apex is involved, include steps such as:

1. Confirm the Apex class or trigger compiled successfully.
2. Run the relevant test class or all related tests.
3. Check code coverage if deployment is expected.
4. Test the business scenario with sample records.
5. Review debug logs if behavior differs from expectations.
6. Confirm bulk behavior if the logic may process multiple records.

## Flow mode

If Flow is involved, include steps such as:

1. Confirm the correct Flow version is active.
2. Check the trigger type and entry conditions.
3. Run a test interview or simulate the record path.
4. Validate field updates, decision branches, and any created records.
5. Confirm error handling and fault paths.
6. Test with a non-admin user if access or record visibility matters.

## Deployment mode

If deployment is involved, include steps such as:

1. Confirm metadata deployed successfully.
2. Verify the deployed version in the target org.
3. Run post-deploy Apex tests if applicable.
4. Confirm page, Flow, or permission assignments.
5. Validate with sample business records in the target org.
6. Confirm there are no deployment-only differences between sandbox and production.

## Permission and access mode

If the work touches access or sharing, include steps such as:

1. Test with the intended user profile or permission set.
2. Verify object, field, and record access.
3. Confirm record type availability.
4. Confirm sharing rules or ownership behavior.
5. Validate the same flow as an admin and non-admin user if relevant.

## Git workflow rules

If the task is code or metadata that will be committed to Git:

- Do not create or push a pull request until validation is complete.
- After validation, prepare a PR-ready summary.
- Stop before any remote push unless the user manually confirms it.
- Never assume the remote repository can be updated automatically.

If the user provides a GitHub repository URL, include it in the handoff as the intended remote target:

- https://github.com/chuk-connect/UHN.git

## Output style

- Use Salesforce terminology whenever possible.
- Be direct and operational.
- Distinguish clearly between completed, inferred, and verified work.
- Never claim a validation step passed unless it was actually tested.
- If the org, record type, or environment is unclear, state the assumption explicitly.
- Never claim a remote push was completed unless the user explicitly confirmed it.

## Quality bar

The response should feel like a Salesforce delivery note written for a developer, admin, or tester.
It should help the user:

- Understand exactly what changed.
- See what still needs validation.
- Test the change in the right org without guessing.
- Know when the work is PR-ready.
- Manually confirm any push to the remote Git repository.

# Salesforce Validation Checklist

- Confirm target org.
- Confirm deployed metadata or saved changes.
- Verify object-level behavior.
- Verify field-level behavior.
- Verify user access and sharing.
- Verify automation results.
- Verify error handling.
- Verify regression impact.

# Apex Testing Notes

- Run the relevant test class.
- Check code coverage.
- Confirm bulk-safe behavior.
- Review debug logs on failure.
- Confirm governor-limit risk is acceptable.

# Flow Testing Notes

- Check active Flow version.
- Confirm trigger conditions.
- Test with sample records.
- Check fault paths.
- Verify created or updated records.
- Test with a non-admin user when permissions matter.

# Deployment Notes

- Confirm deployment success.
- Confirm post-deploy Apex tests.
- Verify assignments and permissions.
- Test business flow in target org.
- Confirm no sandbox-only assumptions remain.

# Git PR and Push Notes

Use this file when Salesforce work is ready to move from validation to source control handoff.

## Required behavior

- Validate the work first.
- Prepare a pull request summary after validation.
- Stop before any remote push unless the user manually confirms it.
- Never assume the remote repository can be updated automatically.

## Manual confirmation rule

Before any push to the remote repository, require a clear user confirmation such as:

- "Confirm push to remote."
- "Proceed with remote push."
- "Yes, push to origin."

## Intended remote

https://github.com/chuk-connect/UHN.git

## PR handoff contents

- What changed.
- What was validated.
- What was not validated.
- Any test results.
- Any deployment or org-specific caveats.
