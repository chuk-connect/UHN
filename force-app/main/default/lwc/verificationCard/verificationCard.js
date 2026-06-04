import { LightningElement, api, track, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { subscribe, unsubscribe, onError } from "lightning/empApi";
import getCardData from "@salesforce/apex/VerificationCardController.getCardData";
import verify from "@salesforce/apex/VerificationCardController.verify";
import overrideRecord from "@salesforce/apex/VerificationCardController.overrideRecord";

/**
 * c-verification-card
 *
 * Drop onto any record page that has verifiable child records. Configured
 * via three @api inputs:
 *   - recordId          (the parent — auto-injected by Lightning)
 *   - childObjectApiName  (e.g. UHN_Publication_Author__c)
 *   - fieldSetName        (which fields to render and make editable)
 *
 * The component is deliberately dumb. All merge logic, all rule logic, and
 * all field-meta resolution happens in Apex. The LWC's only responsibility
 * is to render the shape it receives and forward user actions back to Apex.
 *
 * That separation is what makes the component reusable across Business Hub
 * modules. Adding "the verification card for ethics review" is a page layout
 * change, not a code change.
 */
export default class VerificationCard extends LightningElement {
  @api recordId; // parent id — auto-injected on record pages
  @api childObjectApiName; // e.g. UHN_Publication_Author__c
  @api fieldSetName; // e.g. AAR_Verification
  @api cardTitle = "Verification";

  @track _wiredData; // raw wire result, kept for refreshApex
  @track rows = [];
  @track error;
  @track isLoading = true;

  // Edit modal state. Kept local — we flush to Apex on Save.
  @track showEditModal = false;
  @track editingRecordId;
  @track editingFields = [];

  // CDC subscription handle — stored so we can unsubscribe on disconnect.
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
  }

  disconnectedCallback() {
    this._unsubscribeCdc();
  }

  // Subscribe to the CDC channel for the configured child object so the card
  // refreshes automatically when any related record is added or modified —
  // without a full page reload. Degrades silently if Change Data Capture
  // is not enabled for the object in this org.
  _subscribeCdc() {
    if (!this.childObjectApiName) return;
    // Channel pattern: /data/AAR_Scholarly_Output__c → /data/AAR_Scholarly_Output__ChangeEvent
    const channel =
      "/data/" + this.childObjectApiName.replace("__c", "__ChangeEvent");
    subscribe(channel, -1, () => {
      if (this._wiredData) refreshApex(this._wiredData);
    })
      .then((sub) => {
        this._cdcSubscription = sub;
      })
      .catch(() => {}); // CDC not enabled for this object — no auto-refresh
    onError(() => {}); // suppress empApi error noise
  }

  _unsubscribeCdc() {
    if (this._cdcSubscription) {
      unsubscribe(this._cdcSubscription, () => {});
      this._cdcSubscription = null;
    }
  }

  // --- shaping ---

  /**
   * Take the controller's CardData and produce per-row UI shape.
   * Note we don't merge anything here — `displayValues` already arrives merged.
   * We're only computing presentation flags (CSS classes, badge variants,
   * which fields to render, etc.).
   */
  _shapeRows(cardData) {
    const fields = cardData.fields || [];
    const rows = cardData.rows || [];

    return rows.map((r) => {
      const overridden = new Set(r.overriddenFieldNames || []);
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

      return {
        recordId: r.recordId,
        status: r.status,
        badgeVariant: this._badgeVariant(r.status),
        cssClass: `slds-item vc-list-item verification-row verification-row_${(r.status || "").toLowerCase()}`,
        canVerify: r.status === "Proposed",
        canEdit: r.status === "Verified" || r.status === "Proposed",
        displayFields,
        verifiedFootnote: this._verifiedFootnote(r),
        _raw: r // kept for the edit modal — never bound to template
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

  // --- derived getters used by the template ---

  get hasRows() {
    return !this.isLoading && !this.error && this.rows.length > 0;
  }
  get isEmpty() {
    return !this.isLoading && !this.error && this.rows.length === 0;
  }
  get noProposed() {
    return !this.rows.some((r) => r.status === "Proposed");
  }

  // --- handlers ---

  handleVerifyOne(event) {
    const recordId = event.currentTarget.dataset.recordId;
    this._verify([recordId]);
  }

  handleVerifyAll() {
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

  handleEditClick(event) {
    const recordId = event.currentTarget.dataset.recordId;
    const row = this.rows.find((r) => r.recordId === recordId);
    if (!row) return;
    this.editingRecordId = recordId;
    // Verified_By__c and Verified_At__c are audit stamps — always read-only.
    // Verification_Status__c and Is_Verified__c are intentionally absent here so
    // PIs can edit them; they two-way-sync with each other in handleEditChange.
    const SYSTEM_FIELDS = new Set(["Verified_By__c", "Verified_At__c"]);
    this.editingFields = row.displayFields.map((f) => ({
      ...f,
      isReadOnly: f.editable === false || SYSTEM_FIELDS.has(f.apiName),
      isPicklist: f.type === "PICKLIST",
      editValue: f.isBoolean
        ? String(f._boolValue === true)
        : f.displayValue === "—"
          ? ""
          : f.displayValue,
      editChecked: f.isBoolean && f._boolValue === true
    }));
    this.showEditModal = true;
  }

  handleEditChange(event) {
    const name = event.target.name;
    const isCheckbox = event.target.type === "checkbox";
    const value = isCheckbox
      ? String(event.target.checked)
      : event.target.value;

    let fields = this.editingFields.map((f) => {
      if (f.apiName === name) {
        return {
          ...f,
          editValue: value,
          editChecked: isCheckbox && event.target.checked
        };
      }
      return f;
    });

    // Two-way sync: Verification_Status__c ↔ Is_Verified__c.
    // Changing either one in the modal immediately mirrors to the other
    // so the display is consistent before the PI clicks Save.
    if (name === "Verification_Status__c") {
      const nowVerified = value === "Verified";
      fields = fields.map((f) => {
        if (f.apiName === "Is_Verified__c") {
          return {
            ...f,
            editChecked: nowVerified,
            editValue: String(nowVerified)
          };
        }
        return f;
      });
    } else if (name === "Is_Verified__c") {
      const isChecked = event.target.checked;
      fields = fields.map((f) => {
        if (f.apiName === "Verification_Status__c") {
          return { ...f, editValue: isChecked ? "Verified" : "Proposed" };
        }
        return f;
      });
    }

    this.editingFields = fields;
  }

  handleEditCancel() {
    this.showEditModal = false;
    this.editingRecordId = null;
    this.editingFields = [];
  }

  async handleEditSave() {
    // Build a delta of only the fields the user actually changed.
    // This matters: sending the full row would clobber other PIs' work
    // on shared records. Sending only diffs lets the merge in Apex
    // do its job at the field level.
    const original = this.rows.find((r) => r.recordId === this.editingRecordId);
    const delta = {};
    for (const f of this.editingFields) {
      if (f.isReadOnly) continue;
      const originalField = original.displayFields.find(
        (of) => of.apiName === f.apiName
      );
      if (f.isBoolean) {
        const newBool = f.editValue === "true";
        const origBool = originalField
          ? originalField._boolValue === true
          : false;
        if (newBool !== origBool) {
          delta[f.apiName] = newBool;
        }
      } else {
        const originalValue = originalField ? originalField.displayValue : "";
        const bothEffectivelyEmpty =
          f.editValue === "" && originalValue === "—";
        if (f.editValue !== originalValue && !bothEffectivelyEmpty) {
          delta[f.apiName] = f.editValue === "" ? null : f.editValue;
        }
      }
    }

    if (Object.keys(delta).length === 0) {
      this._toast("Nothing changed", "No fields were modified", "info");
      this.handleEditCancel();
      return;
    }

    try {
      this.isLoading = true;
      await overrideRecord({
        recordId: this.editingRecordId,
        overrideJson: JSON.stringify(delta)
      });
      await refreshApex(this._wiredData);
      this._toast(
        "Saved",
        "Corrections applied and record verified",
        "success"
      );
      this.handleEditCancel();
    } catch (e) {
      this._toast("Could not save", this._extractErrorMessage(e), "error");
    } finally {
      this.isLoading = false;
    }
  }

  // --- utilities ---

  _toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  /**
   * Apex errors arrive in different shapes depending on type
   * (AuraHandledException, DML, generic). Extract a user-readable string.
   */
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
