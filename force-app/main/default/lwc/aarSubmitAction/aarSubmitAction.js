import { LightningElement, api, wire, track } from "lwc";
import { getRecord, getFieldValue, updateRecord } from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CloseActionScreenEvent } from "lightning/actions";

import CMARS_FIELD from "@salesforce/schema/UHN_AAR__c.CMaRS_Updated__c";
import GRANTS_FIELD from "@salesforce/schema/UHN_AAR__c.Grants_Good_Standing__c";
import TRAINING_FIELD from "@salesforce/schema/UHN_AAR__c.Mandatory_Training_Complete__c";
import FORM_FIELD from "@salesforce/schema/UHN_AAR__c.Form_Confirmed_Accurate__c";
import STATUS_FIELD from "@salesforce/schema/UHN_AAR__c.Status__c";
import SUBMISSION_DATE_FIELD from "@salesforce/schema/UHN_AAR__c.Submission_Date__c";

const FIELDS = [
  CMARS_FIELD,
  GRANTS_FIELD,
  TRAINING_FIELD,
  FORM_FIELD,
  STATUS_FIELD
];

export default class AarSubmitAction extends LightningElement {
  @api recordId;

  @track isLoading = false;
  @track isSubmitted = false;

  cMaRSChecked = false;
  grantsChecked = false;
  trainingChecked = false;
  formChecked = false;

  @wire(getRecord, { recordId: "$recordId", fields: FIELDS })
  wiredRecord({ data }) {
    if (data) {
      this.cMaRSChecked = getFieldValue(data, CMARS_FIELD);
      this.grantsChecked = getFieldValue(data, GRANTS_FIELD);
      this.trainingChecked = getFieldValue(data, TRAINING_FIELD);
      this.formChecked = getFieldValue(data, FORM_FIELD);
    }
  }

  get validationErrors() {
    const errors = [];
    if (!this.cMaRSChecked)
      errors.push(
        "CMaRS Conflict of Interest disclosure must be marked as updated"
      );
    if (!this.grantsChecked)
      errors.push("All grants must be confirmed in good standing");
    if (!this.trainingChecked)
      errors.push("Mandatory training must be marked complete");
    if (!this.formChecked) errors.push("Form accuracy must be confirmed");
    return errors;
  }

  get hasErrors() {
    return this.validationErrors.length > 0;
  }

  get cMaRSClass() {
    return this.cMaRSChecked
      ? "slds-text-color_success"
      : "slds-text-color_error";
  }

  get grantsClass() {
    return this.grantsChecked
      ? "slds-text-color_success"
      : "slds-text-color_error";
  }

  get trainingClass() {
    return this.trainingChecked
      ? "slds-text-color_success"
      : "slds-text-color_error";
  }

  get formClass() {
    return this.formChecked
      ? "slds-text-color_success"
      : "slds-text-color_error";
  }

  handleCancel() {
    this.dispatchEvent(new CloseActionScreenEvent());
  }

  handleSubmit() {
    this.isLoading = true;
    const fields = {};
    fields.Id = this.recordId;
    fields[STATUS_FIELD.fieldApiName] = "Submitted";
    fields[SUBMISSION_DATE_FIELD.fieldApiName] = new Date().toISOString();

    updateRecord({ fields })
      .then(() => {
        this.isSubmitted = true;
        this.isLoading = false;
        this.dispatchEvent(
          new ShowToastEvent({
            title: "AAR Submitted",
            message:
              "Your Annual Activity Report has been submitted for review.",
            variant: "success"
          })
        );
      })
      .catch((error) => {
        this.isLoading = false;
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Submission failed",
            message: error.body
              ? error.body.message
              : "An unexpected error occurred.",
            variant: "error"
          })
        );
      });
  }
}
