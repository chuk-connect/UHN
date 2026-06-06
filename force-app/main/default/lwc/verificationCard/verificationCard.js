import { LightningElement, api, track, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { subscribe, unsubscribe, onError } from "lightning/empApi";
import getCardData from "@salesforce/apex/VerificationCardController.getCardData";
import getParentStatus from "@salesforce/apex/VerificationCardController.getParentStatus";
import verify from "@salesforce/apex/VerificationCardController.verify";
import rejectRecord from "@salesforce/apex/VerificationCardController.rejectRecord";
import confirmManualRecord from "@salesforce/apex/VerificationCardController.confirmManualRecord";

/**
 * c-verification-card
 *
 * Read-display + action-dispatch component (per ADR AAR-REC-verification-card-readonly).
 * The card displays verification state and dispatches state-transition actions.
 * It never writes to records directly — all mutations route through
 * VerificationReconciliationService (via the controller).
 *
 * Reusable on any object record page. Configure via Verification_Binding__mdt.
 *
 * @api properties:
 *   recordId            — auto-injected by Lightning on record pages
 *   childObjectApiName  — e.g. UHN_Publication_Author__c
 *   fieldSetName        — field set on the child object
 *   cardTitle           — display label (default "Verification")
 *   parentStatus        — parent Status__c from App Builder binding (primary inertness signal)
 *   parentStatusFieldApiName — API name of status field on parent, used as fallback
 *                              when App Builder binding is not configured
 */
export default class VerificationCard extends LightningElement {
  @api recordId;
  @api childObjectApiName;
  @api fieldSetName;
  @api cardTitle = "Verification";

  // Primary inertness signal — bind to parent record Status__c in App Builder.
  @api parentStatus;

  // Fallback inertness signal — when set, the card queries parent status via Apex
  // on connect. This ensures inertness works even without App Builder binding.
  @api parentStatusFieldApiName;

  @track _wiredData;
  @track rows = [];
  @track error;
  @track isLoading = true;

  // Fallback-resolved parent status (set imperatively on connect)
  @track _resolvedStatus = null;

  // Reject confirmation state
  @track showRejectModal = false;
  @track _rejectingRecordId = null;
  @track _rejectReason = "";

  _cdcSubscription = null;

  @wire(getCardData, {
    parentRecordId: "$recordId",
    childObjectApiName: "$childObjectApiName",
    fieldSetName: "$fieldSetName"
  })
  wiredData(result) {
    this._wiredData = result;
    this.isLoading = false;
    if (result.error) {
      this.error = this._extractErrorMessage(result.error);
      this.rows = [];
    } else if (result.data) {
      this.error = undefined;
      this.rows = this._shapeRows(result.data);
    }
  }

  // --- lifecycle ---

  connectedCallback() {
    this._subscribeCdc();
    this._initParentStatus();
  }

  disconnectedCallback() {
    this._unsubscribeCdc();
  }

  // Fallback: imperatively query parent status when parentStatusFieldApiName is set.
  // This closes the gap where the App Builder binding was never configured.
  async _initParentStatus() {
    if (!this.parentStatusFieldApiName || !this.recordId) return;
    try {
      this._resolvedStatus = await getParentStatus({
        parentRecordId: this.recordId,
        statusFieldApiName: this.parentStatusFieldApiName
      });
    } catch {
      // Degrade silently — App Builder binding remains authoritative
    }
  }

  _subscribeCdc() {
    if (!this.childObjectApiName) return;
    const channel =
      "/data/" + this.childObjectApiName.replace("__c", "__ChangeEvent");
    subscribe(channel, -1, () => {
      if (this._wiredData) refreshApex(this._wiredData);
    })
      .then((sub) => {
        this._cdcSubscription = sub;
      })
      .catch(() => {});
    onError(() => {});
  }

  _unsubscribeCdc() {
    if (this._cdcSubscription) {
      unsubscribe(this._cdcSubscription, () => {});
      this._cdcSubscription = null;
    }
  }

  // --- post-submission inertness ---

  // Checks App Builder binding first (reactive, immediate), then the
  // Apex-resolved fallback (set once on connect). Either is sufficient.
  get _isInert() {
    const status = this.parentStatus || this._resolvedStatus;
    return (
      status === "Submitted" ||
      status === "Under Review" ||
      status === "Complete"
    );
  }

  get isInert() {
    return this._isInert;
  }
  get isNotInert() {
    return !this._isInert;
  }

  // --- unreviewed count (legacy records without status) ---

  get unreviewedCount() {
    return this._wiredData?.data?.unreviewedCount || 0;
  }
  get hasUnreviewed() {
    return this.unreviewedCount > 0;
  }
  get unreviewedMessage() {
    const n = this.unreviewedCount;
    return (
      `${n} legacy record${n === 1 ? "" : "s"} exist without verification status — ` +
      "they predate the source sync and will appear once the sync handler runs."
    );
  }

  // --- shaping ---

  _shapeRows(cardData) {
    const fields = cardData.fields || [];
    const rows = cardData.rows || [];
    const inert = this._isInert;

    return rows.map((r) => {
      const overridden = new Set(r.overriddenFieldNames || []);
      const hasSourceData =
        r.sourceValues && Object.keys(r.sourceValues).length > 0;
      const displayFields = fields.map((f) => {
        const sourceVal = r.sourceValues
          ? r.sourceValues[f.apiName]
          : undefined;
        const isOverridden = overridden.has(f.apiName);
        const rawVal = r.displayValues[f.apiName];
        const isBool = f.type === "BOOLEAN";
        return {
          apiName: f.apiName,
          label: f.label,
          type: f.type,
          editable: f.editable,
          picklistValues: f.picklistValues || [],
          isBoolean: isBool,
          displayValue: this._fmtByType(rawVal, f.type),
          _boolValue: isBool ? rawVal === true : undefined,
          isOverridden,
          sourceTooltip:
            isOverridden && sourceVal !== undefined
              ? `Source value: ${this._fmt(sourceVal)}`
              : ""
        };
      });

      const statusLower = (r.status || "default").toLowerCase();
      return {
        recordId: r.recordId,
        status: r.status,
        badgeVariant: this._badgeVariant(r.status),
        cssClass: `slds-item vc-list-item verification-row verification-row_${statusLower}`,
        statusChipClass: `vc-status-chip vc-status-chip_${statusLower}`,
        statusIcon:
          {
            Verified: "utility:success",
            Proposed: "utility:pending",
            Manual: "utility:user"
          }[r.status] || "utility:record",
        canVerify: r.status === "Proposed" && !inert,
        canReject: r.status === "Proposed" && !inert,
        canConfirmManual: r.status === "Manual" && !inert,
        noSourceData: r.status === "Proposed" && !hasSourceData,
        displayFields,
        verifiedFootnote: this._verifiedFootnote(r),
        _raw: r
      };
    });
  }

  _badgeVariant(status) {
    switch (status) {
      case "Verified":
        return "success";
      case "Proposed":
        return "warning";
      case "Manual":
        return "inverse";
      default:
        return "default";
    }
  }

  _verifiedFootnote(row) {
    if (row.status === "Verified" && row.verifiedAt) {
      const when = this._fmtDatetime(row.verifiedAt);
      const who = row.verifiedByName || "PI";
      return `Verified by ${who} on ${when}`;
    }
    if (row.status === "Manual") {
      return "No source system — PI-entered";
    }
    return "";
  }

  _fmt(v) {
    if (v === null || v === undefined) return "—";
    if (typeof v === "boolean") return v ? "Yes" : "No";
    if (v instanceof Date) return v.toLocaleString();
    return String(v);
  }

  _fmtDatetime(v) {
    if (v === null || v === undefined || v === "") return "—";
    const d = new Date(v);
    if (isNaN(d.getTime())) return String(v);
    const date = d.toLocaleDateString("en-US", {
      year: "numeric",
      month: "long",
      day: "numeric"
    });
    const day = d.toLocaleDateString("en-US", { weekday: "long" });
    const time = d.toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
      hour12: true
    });
    return `${date}, ${day}, ${time}`;
  }

  _fmtByType(v, type) {
    if (type === "DATETIME") return this._fmtDatetime(v);
    return this._fmt(v);
  }

  // --- derived getters ---

  get hasRows() {
    return !this.isLoading && !this.error && this.rows.length > 0;
  }
  get isEmpty() {
    return (
      !this.isLoading &&
      !this.error &&
      this.rows.length === 0 &&
      this.unreviewedCount === 0
    );
  }
  get noProposed() {
    return !this.rows.some((r) => r.status === "Proposed");
  }

  // --- verify handlers ---

  handleVerifyOne(event) {
    const recordId = event.currentTarget.dataset.recordId;
    this._verify([recordId]);
  }

  handleVerifyAll() {
    if (this._isInert) return;
    const ids = this.rows
      .filter((r) => r.status === "Proposed")
      .map((r) => r.recordId);
    if (ids.length === 0) return;
    this._verify(ids);
  }

  async _verify(recordIds) {
    try {
      this.isLoading = true;
      await verify({ recordIds });
      await refreshApex(this._wiredData);
      this._toast(
        "Verified",
        `${recordIds.length} record(s) marked verified`,
        "success"
      );
    } catch (e) {
      this._toast("Could not verify", this._extractErrorMessage(e), "error");
    } finally {
      this.isLoading = false;
    }
  }

  // --- reject handlers ---

  handleRejectOne(event) {
    this._rejectingRecordId = event.currentTarget.dataset.recordId;
    this._rejectReason = "";
    this.showRejectModal = true;
  }

  handleRejectReasonChange(event) {
    this._rejectReason = event.target.value;
  }

  handleRejectCancel() {
    this.showRejectModal = false;
    this._rejectingRecordId = null;
    this._rejectReason = "";
  }

  async handleRejectConfirm() {
    const recordId = this._rejectingRecordId;
    const reason = this._rejectReason;
    this.showRejectModal = false;
    this._rejectingRecordId = null;
    this._rejectReason = "";
    try {
      this.isLoading = true;
      await rejectRecord({ recordId, reason });
      await refreshApex(this._wiredData);
      this._toast("Excluded", "Record excluded from verification", "success");
    } catch (e) {
      this._toast("Could not reject", this._extractErrorMessage(e), "error");
    } finally {
      this.isLoading = false;
    }
  }

  // --- confirm manual handler ---

  async handleConfirmManual(event) {
    const recordId = event.currentTarget.dataset.recordId;
    try {
      this.isLoading = true;
      await confirmManualRecord({ recordId });
      await refreshApex(this._wiredData);
      this._toast(
        "Confirmed",
        "Manual record confirmed and marked verified",
        "success"
      );
    } catch (e) {
      this._toast("Could not confirm", this._extractErrorMessage(e), "error");
    } finally {
      this.isLoading = false;
    }
  }

  // --- utilities ---

  _toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  _extractErrorMessage(err) {
    if (!err) return "Unknown error";
    if (typeof err === "string") return err;
    if (err.body) {
      if (Array.isArray(err.body))
        return err.body.map((e) => e.message).join(", ");
      if (err.body.message) return err.body.message;
      if (err.body.pageErrors && err.body.pageErrors.length) {
        return err.body.pageErrors.map((e) => e.message).join(", ");
      }
    }
    return err.message || JSON.stringify(err);
  }
}
