import { createElement } from "lwc";
import VerificationCard from "c/verificationCard";
import { subscribe, unsubscribe } from "lightning/empApi";
import verify from "@salesforce/apex/VerificationCardController.verify";
import overrideRecord from "@salesforce/apex/VerificationCardController.overrideRecord";
import getCardData from "@salesforce/apex/VerificationCardController.getCardData";

// The LWC jest-transformer rewrites apex imports as:
//   import fn from '@salesforce/apex/...'  →  fn = require("...").default
// Mocks must expose { default: ... } so the binding resolves correctly.

jest.mock(
  "@salesforce/apex/VerificationCardController.getCardData",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/VerificationCardController.verify",
  () => ({ default: jest.fn().mockResolvedValue(undefined) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/VerificationCardController.overrideRecord",
  () => ({ default: jest.fn().mockResolvedValue(undefined) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex",
  () => ({ refreshApex: jest.fn().mockResolvedValue(undefined) }),
  { virtual: true }
);

// ── fixtures ────────────────────────────────────────────────────────────────

const FIELDS = [
  {
    apiName: "Title__c",
    label: "Title",
    type: "STRING",
    editable: true,
    picklistValues: []
  },
  {
    apiName: "Role__c",
    label: "Role",
    type: "PICKLIST",
    editable: true,
    picklistValues: [{ label: "Author", value: "Author" }]
  },
  {
    apiName: "Is_Verified__c",
    label: "Verified",
    type: "BOOLEAN",
    editable: true,
    picklistValues: []
  },
  {
    apiName: "Verified_By__c",
    label: "By",
    type: "STRING",
    editable: false,
    picklistValues: []
  },
  {
    apiName: "Verification_Status__c",
    label: "Status",
    type: "PICKLIST",
    editable: true,
    picklistValues: [
      { label: "Proposed", value: "Proposed" },
      { label: "Verified", value: "Verified" }
    ]
  }
];

function makeRow(overrides = {}) {
  return {
    recordId: "a001",
    status: "Proposed",
    displayValues: {
      Title__c: "Smith J",
      Role__c: "Author",
      Is_Verified__c: false,
      Verified_By__c: null,
      Verification_Status__c: "Proposed"
    },
    sourceValues: {},
    overriddenFieldNames: [],
    verifiedAt: null,
    verifiedByName: null,
    ...overrides
  };
}

function makeCardData(rows = [makeRow()]) {
  return { fields: FIELDS, rows };
}

// ── helpers ─────────────────────────────────────────────────────────────────

function createEl() {
  const el = createElement("c-verification-card", { is: VerificationCard });
  el.recordId = "p001";
  el.childObjectApiName = "UHN_Publication_Author__c";
  el.fieldSetName = "AAR_Verification";
  document.body.appendChild(el);
  return el;
}

// LWC uses microtask-based rendering; setTimeout gives all microtasks a chance to run.
function flushPromises() {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

// LWC @api properties are JS properties, not HTML attributes — can't use attribute selectors.
function findButton(root, label) {
  return Array.from(root.querySelectorAll("lightning-button")).find(
    (b) => b.label === label
  );
}
function findButtonIcon(root, altText) {
  return Array.from(root.querySelectorAll("lightning-button-icon")).find(
    (b) => b.alternativeText === altText
  );
}

afterEach(() => {
  while (document.body.firstChild)
    document.body.removeChild(document.body.firstChild);
  jest.clearAllMocks();
});

// ── initial state (adapter emits {data:undefined} immediately on connect) ───

describe("initial state", () => {
  it("renders no spinner when wire has no data (isEmpty)", async () => {
    const el = createEl();
    await flushPromises();
    // adapter emits {data:undefined} immediately → isLoading=false, rows=[]
    expect(el.shadowRoot.querySelector("lightning-spinner")).toBeNull();
  });

  it("shows empty message before data is emitted", async () => {
    const el = createEl();
    await flushPromises();
    expect(el.shadowRoot.textContent).toContain("No records to verify");
  });
});

// ── error state ──────────────────────────────────────────────────────────────

describe("error state", () => {
  it("renders error box on wire error — body.message", async () => {
    const el = createEl();
    // error(body, status, statusText) — first arg IS the body
    getCardData.error({ message: "Apex blew up" });
    await flushPromises();
    const alert = el.shadowRoot.querySelector('[role="alert"]');
    expect(alert).not.toBeNull();
    expect(alert.textContent).toContain("Apex blew up");
  });

  it("renders error box on wire error — body array", async () => {
    const el = createEl();
    getCardData.error([{ message: "err1" }, { message: "err2" }]);
    await flushPromises();
    const alert = el.shadowRoot.querySelector('[role="alert"]');
    expect(alert).not.toBeNull();
    expect(alert.textContent).toContain("err1");
  });

  it("hides row list when in error state", async () => {
    const el = createEl();
    getCardData.error({ message: "fail" });
    await flushPromises();
    expect(el.shadowRoot.querySelector("ul")).toBeNull();
  });
});

// ── empty state ───────────────────────────────────────────────────────────────

describe("empty state", () => {
  it('shows "No records to verify" when rows is empty', async () => {
    const el = createEl();
    getCardData.emit(makeCardData([]));
    await flushPromises();
    expect(el.shadowRoot.textContent).toContain("No records to verify");
  });

  it("does not render the row list when empty", async () => {
    const el = createEl();
    getCardData.emit(makeCardData([]));
    await flushPromises();
    expect(el.shadowRoot.querySelector("ul")).toBeNull();
  });
});

// ── row rendering ─────────────────────────────────────────────────────────────

describe("row rendering", () => {
  it("renders one li per row", async () => {
    const el = createEl();
    getCardData.emit(
      makeCardData([
        makeRow({ recordId: "a001" }),
        makeRow({
          recordId: "a002",
          status: "Verified",
          verifiedAt: "2026-01-01T00:00:00Z"
        })
      ])
    );
    await flushPromises();
    expect(el.shadowRoot.querySelectorAll("li")).toHaveLength(2);
  });

  it("Proposed row has a Verify button", async () => {
    const el = createEl();
    getCardData.emit(makeCardData([makeRow({ status: "Proposed" })]));
    await flushPromises();
    expect(findButton(el.shadowRoot, "Verify")).toBeTruthy();
  });

  it("Verified row has no Verify button", async () => {
    const el = createEl();
    getCardData.emit(
      makeCardData([
        makeRow({ status: "Verified", verifiedAt: "2026-01-01T00:00:00Z" })
      ])
    );
    await flushPromises();
    expect(findButton(el.shadowRoot, "Verify")).toBeFalsy();
  });

  it("Verified row shows verified footnote", async () => {
    const el = createEl();
    getCardData.emit(
      makeCardData([
        makeRow({
          status: "Verified",
          verifiedAt: "2026-01-01T00:00:00Z",
          verifiedByName: "Dr. Jane"
        })
      ])
    );
    await flushPromises();
    expect(el.shadowRoot.textContent).toContain("Verified by Dr. Jane");
  });

  it("Manual row shows PI-entered footnote", async () => {
    const el = createEl();
    getCardData.emit(makeCardData([makeRow({ status: "Manual" })]));
    await flushPromises();
    expect(el.shadowRoot.textContent).toContain(
      "No source system — PI-entered"
    );
  });

  it("overridden field shows Corrected icon", async () => {
    const el = createEl();
    getCardData.emit(
      makeCardData([makeRow({ overriddenFieldNames: ["Title__c"] })])
    );
    await flushPromises();
    const icon = Array.from(
      el.shadowRoot.querySelectorAll("lightning-icon")
    ).find((i) => i.alternativeText === "Corrected");
    expect(icon).toBeTruthy();
  });

  it('"Verify All Proposed" button is disabled when no Proposed rows', async () => {
    const el = createEl();
    getCardData.emit(
      makeCardData([
        makeRow({ status: "Verified", verifiedAt: "2026-01-01T00:00:00Z" })
      ])
    );
    await flushPromises();
    const btn = findButton(el.shadowRoot, "Verify All Proposed");
    expect(btn).toBeTruthy();
    expect(btn.disabled).toBe(true);
  });
});

// ── badge / CSS class ─────────────────────────────────────────────────────────

describe("row CSS class reflects status", () => {
  const cases = [
    ["Proposed", "verification-row_proposed"],
    ["Verified", "verification-row_verified"],
    ["Manual", "verification-row_manual"]
  ];

  test.each(cases)("status %s → li contains class %s", async (status, cls) => {
    const el = createEl();
    getCardData.emit(
      makeCardData([
        makeRow({
          status,
          verifiedAt: status === "Verified" ? "2026-01-01T00:00:00Z" : null
        })
      ])
    );
    await flushPromises();
    const li = el.shadowRoot.querySelector("li");
    expect(li.className).toContain(cls);
  });
});

// ── verify actions ────────────────────────────────────────────────────────────

describe("verify actions", () => {
  it("handleVerifyOne calls verify with the correct recordId", async () => {
    const el = createEl();
    getCardData.emit(
      makeCardData([makeRow({ recordId: "a001", status: "Proposed" })])
    );
    await flushPromises();
    findButton(el.shadowRoot, "Verify").click();
    await flushPromises();
    expect(verify).toHaveBeenCalledWith({ recordIds: ["a001"] });
  });

  it("handleVerifyAll calls verify with all Proposed ids only", async () => {
    const el = createEl();
    getCardData.emit(
      makeCardData([
        makeRow({ recordId: "a001", status: "Proposed" }),
        makeRow({ recordId: "a002", status: "Proposed" }),
        makeRow({
          recordId: "a003",
          status: "Verified",
          verifiedAt: "2026-01-01T00:00:00Z"
        })
      ])
    );
    await flushPromises();
    findButton(el.shadowRoot, "Verify All Proposed").click();
    await flushPromises();
    expect(verify).toHaveBeenCalledWith({ recordIds: ["a001", "a002"] });
  });

  it("handleVerifyAll is a no-op when no Proposed rows exist", async () => {
    const el = createEl();
    getCardData.emit(
      makeCardData([
        makeRow({ status: "Verified", verifiedAt: "2026-01-01T00:00:00Z" })
      ])
    );
    await flushPromises();
    findButton(el.shadowRoot, "Verify All Proposed").click();
    await flushPromises();
    expect(verify).not.toHaveBeenCalled();
  });
});

// ── edit modal ────────────────────────────────────────────────────────────────

describe("edit modal", () => {
  async function openModal(el) {
    getCardData.emit(
      makeCardData([makeRow({ status: "Proposed", recordId: "a001" })])
    );
    await flushPromises();
    findButtonIcon(el.shadowRoot, "Edit overrides").click();
    await flushPromises();
  }

  it("opens when edit icon is clicked", async () => {
    const el = createEl();
    await openModal(el);
    expect(el.shadowRoot.querySelector('[role="dialog"]')).not.toBeNull();
  });

  it("closes when Cancel is clicked", async () => {
    const el = createEl();
    await openModal(el);
    el.shadowRoot.querySelector(".slds-button_neutral").click();
    await flushPromises();
    expect(el.shadowRoot.querySelector('[role="dialog"]')).toBeNull();
  });

  it("Verified_By__c is rendered as read-only in modal", async () => {
    const el = createEl();
    await openModal(el);
    const readonlyLabels = Array.from(
      el.shadowRoot.querySelectorAll(
        ".modal-field_readonly .slds-form-element__label"
      )
    ).map((n) => n.textContent);
    expect(readonlyLabels).toContain("By");
  });
});

// ── handleEditSave: nothing-changed path ──────────────────────────────────────

describe("handleEditSave — nothing changed", () => {
  it("does not call overrideRecord when no fields were modified", async () => {
    const el = createEl();
    getCardData.emit(
      makeCardData([makeRow({ status: "Proposed", recordId: "a001" })])
    );
    await flushPromises();
    findButtonIcon(el.shadowRoot, "Edit overrides").click();
    await flushPromises();
    // Click Save without changing anything
    el.shadowRoot.querySelector(".slds-button_brand").click();
    await flushPromises();
    expect(overrideRecord).not.toHaveBeenCalled();
  });
});

// ── CDC subscription ──────────────────────────────────────────────────────────

describe("CDC subscription", () => {
  it("subscribes to the child object ChangeEvent channel on connect", async () => {
    createEl();
    await flushPromises();
    expect(subscribe).toHaveBeenCalledWith(
      "/data/UHN_Publication_Author__ChangeEvent",
      -1,
      expect.any(Function)
    );
  });

  it("unsubscribes on disconnect", async () => {
    const el = createEl();
    await flushPromises();
    document.body.removeChild(el);
    await flushPromises();
    expect(unsubscribe).toHaveBeenCalled();
  });
});

// ── _extractErrorMessage — tested via error display ───────────────────────────

describe("error message extraction (via rendered output)", () => {
  it("displays body.message from a wire error", async () => {
    const el = createEl();
    getCardData.error({ message: "Something went wrong" });
    await flushPromises();
    expect(el.shadowRoot.querySelector('[role="alert"]').textContent).toContain(
      "Something went wrong"
    );
  });

  it("displays joined messages from a body array", async () => {
    const el = createEl();
    getCardData.error([{ message: "Part A" }, { message: "Part B" }]);
    await flushPromises();
    const text = el.shadowRoot.querySelector('[role="alert"]').textContent;
    expect(text).toContain("Part A");
  });
});

// ── field formatting — tested via rendered display values ─────────────────────

describe("field value rendering", () => {
  it("null field value renders as em-dash", async () => {
    const el = createEl();
    getCardData.emit(
      makeCardData([
        makeRow({
          displayValues: {
            Title__c: null,
            Role__c: "Author",
            Is_Verified__c: false,
            Verified_By__c: null,
            Verification_Status__c: "Proposed"
          }
        })
      ])
    );
    await flushPromises();
    const values = Array.from(
      el.shadowRoot.querySelectorAll(".verification-col_value")
    );
    const texts = values.map((v) => v.textContent.trim());
    expect(texts).toContain("—");
  });

  it('boolean false field renders as "No"', async () => {
    const el = createEl();
    getCardData.emit(
      makeCardData([
        makeRow({
          displayValues: {
            Title__c: "Smith J",
            Role__c: "Author",
            Is_Verified__c: false,
            Verified_By__c: null,
            Verification_Status__c: "Proposed"
          }
        })
      ])
    );
    await flushPromises();
    const values = Array.from(
      el.shadowRoot.querySelectorAll(".verification-col_value")
    );
    const texts = values.map((v) => v.textContent.trim());
    expect(texts).toContain("No");
  });
});
