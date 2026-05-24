/**
 * Typed exception for the Verification Framework.
 * Thrown by VerificationReconciliationService and VerificationCardController
 * for caller-fixable errors (bad input, missing config, attestation conflicts).
 *
 * Infrastructure-level failures (DML, governor limits) bubble up as their
 * native exception types so retry logic upstream can distinguish them.
 */
public with sharing class VerificationException extends Exception {}
