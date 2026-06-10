import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class AarSelfAssessment extends LightningElement {
  @api recordId;
  @api isReadOnly = false;

  @track isLoading = true;

  handleLoad() {
    this.isLoading = false;
  }

  handleSave(event) {
    event.preventDefault();
    this.template.querySelector("lightning-record-edit-form").submit();
  }

  handleSuccess() {
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Saved",
        message: "Self-assessment saved successfully.",
        variant: "success"
      })
    );
  }

  handleError(event) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Save failed",
        message: event.detail.message,
        variant: "error"
      })
    );
  }
}
