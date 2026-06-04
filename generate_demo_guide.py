"""
Generates AAR Krembil Client Demo Guide PDF
Run: python.exe generate_demo_guide.py
"""

from fpdf import FPDF
from fpdf.enums import XPos, YPos
import os

# -- Colour palette ----------------------------------------------------------
NAVY   = (0,  47,  95)    # UHN navy
TEAL   = (0, 112, 122)    # UHN teal accent
LGRAY  = (245, 245, 247)  # section background
DGRAY  = (80,  80,  80)   # body text
WHITE  = (255, 255, 255)
BLACK  = (0,   0,   0)
GREEN  = (0,  128,  64)
AMBER  = (180, 100,  0)

OUTPUT = os.path.join(os.path.dirname(__file__),
                      "AAR_Krembil_Client_Demo_Guide.pdf")


class DemoGuide(FPDF):
    def __init__(self):
        super().__init__(orientation="P", unit="mm", format="A4")
        self.set_margins(18, 18, 18)
        self.set_auto_page_break(auto=True, margin=22)
        self._page_num = 0

    # -- header / footer ----------------------------------------------------
    def header(self):
        if self.page_no() == 1:
            return
        self.set_fill_color(*NAVY)
        self.rect(0, 0, 210, 10, style="F")
        self.set_font("Helvetica", "B", 8)
        self.set_text_color(*WHITE)
        self.set_xy(18, 2)
        self.cell(0, 6,
                  "AAR Krembil - Salesforce Client Demo Guide  |  Confidential",
                  new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_text_color(*DGRAY)
        self.ln(4)

    def footer(self):
        self.set_y(-14)
        self.set_font("Helvetica", "", 7.5)
        self.set_text_color(150, 150, 150)
        self.cell(0, 6,
                  f"UHN Business Hub  |  Demo: Thursday 29 May 2026 at 11 am  |  Page {self.page_no()}",
                  align="C")

    # -- helpers -------------------------------------------------------------
    def color_bar(self, r, g, b, h=1.2):
        self.set_fill_color(r, g, b)
        self.rect(18, self.get_y(), 174, h, style="F")
        self.ln(h + 1)

    def section_title(self, text, level=1):
        self.ln(3)
        if level == 1:
            self.set_fill_color(*NAVY)
            self.set_text_color(*WHITE)
            self.set_font("Helvetica", "B", 12)
            self.set_fill_color(*NAVY)
            self.cell(0, 8, f"  {text}", fill=True,
                      new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        elif level == 2:
            self.set_fill_color(*TEAL)
            self.set_text_color(*WHITE)
            self.set_font("Helvetica", "B", 10)
            self.cell(0, 7, f"  {text}", fill=True,
                      new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        elif level == 3:
            self.set_text_color(*NAVY)
            self.set_font("Helvetica", "B", 9.5)
            self.cell(0, 6, text, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
            self.color_bar(*TEAL, h=0.6)
        self.set_text_color(*DGRAY)
        self.ln(1)

    def body(self, text, indent=0, size=9):
        self.set_font("Helvetica", "", size)
        self.set_text_color(*DGRAY)
        self.set_x(18 + indent)
        self.multi_cell(174 - indent, 5, text,
                        new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.ln(1)

    def step(self, number, title, detail, persona_color=None):
        """Render a numbered demo step."""
        pc = persona_color or TEAL
        # number badge
        self.set_fill_color(*pc)
        self.set_text_color(*WHITE)
        self.set_font("Helvetica", "B", 9)
        x0 = self.get_x()
        y0 = self.get_y()
        self.set_xy(18, y0)
        self.cell(7, 7, str(number), fill=True, align="C")
        # title
        self.set_xy(27, y0)
        self.set_text_color(*BLACK)
        self.set_font("Helvetica", "B", 9.5)
        self.cell(0, 7, title, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        # detail lines
        self.set_text_color(*DGRAY)
        self.set_font("Helvetica", "", 8.5)
        for line in detail:
            self.set_x(27)
            self.multi_cell(165, 5, f"-  {line}",
                            new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.ln(2)

    def info_box(self, label, text, color=None):
        c = color or TEAL
        self.set_fill_color(*LGRAY)
        y0 = self.get_y()
        self.set_xy(18, y0)
        self.set_fill_color(*c)
        self.rect(18, y0, 2.5, 0, style="F")          # left accent bar placeholder
        self.set_fill_color(*LGRAY)
        self.rect(20.5, y0, 171.5, 0, style="F")
        # render text
        self.set_font("Helvetica", "B", 8.5)
        self.set_text_color(*c)
        self.set_x(22)
        self.cell(0, 5.5, label, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_font("Helvetica", "", 8.5)
        self.set_text_color(*DGRAY)
        for line in text:
            self.set_x(22)
            self.multi_cell(168, 5, line,
                            new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        # draw the accent bar retrospectively by measuring height
        h = self.get_y() - y0 + 2
        self.set_fill_color(*c)
        self.rect(18, y0, 2.5, h, style="F")
        self.set_fill_color(*LGRAY)
        self.rect(20.5, y0, 171.5, h, style="F")
        # re-render text on top of background
        self.set_xy(22, y0)
        self.set_font("Helvetica", "B", 8.5)
        self.set_text_color(*c)
        self.cell(0, 5.5, label, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_font("Helvetica", "", 8.5)
        self.set_text_color(*DGRAY)
        for line in text:
            self.set_x(22)
            self.multi_cell(168, 5, line,
                            new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.ln(3)

    def two_col_table(self, headers, rows, col_w=None):
        cw = col_w or [60, 114]
        # header row
        self.set_fill_color(*NAVY)
        self.set_text_color(*WHITE)
        self.set_font("Helvetica", "B", 8.5)
        for i, h in enumerate(headers):
            self.cell(cw[i], 7, f"  {h}", fill=True, border=0)
        self.ln()
        # data rows
        for idx, row in enumerate(rows):
            self.set_fill_color(*(LGRAY if idx % 2 == 0 else WHITE))
            self.set_text_color(*DGRAY)
            self.set_font("Helvetica", "", 8.5)
            # save y for multi-line alignment
            y0 = self.get_y()
            x0 = self.get_x()
            # cell 0
            self.set_xy(18, y0)
            self.multi_cell(cw[0], 6, f"  {row[0]}", fill=True, border=0,
                            new_x=XPos.RIGHT, new_y=YPos.TOP)
            # cell 1
            self.set_xy(18 + cw[0], y0)
            self.multi_cell(cw[1], 6, f"  {row[1]}", fill=True, border=0,
                            new_x=XPos.LMARGIN, new_y=YPos.NEXT)
            # ensure we're past both cells
        self.ln(2)

    def checklist_item(self, text, checked=False):
        box = "[x]" if checked else "[ ]"
        self.set_font("Helvetica", "", 9)
        self.set_text_color(*DGRAY)
        self.set_x(22)
        self.multi_cell(166, 5.5, f"{box}  {text}",
                        new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    def persona_banner(self, role, time_est, color):
        self.set_fill_color(*color)
        self.set_text_color(*WHITE)
        self.set_font("Helvetica", "B", 10)
        self.cell(120, 8, f"  PERSONA: {role}", fill=True)
        self.set_font("Helvetica", "", 9)
        self.cell(54, 8, f"  Est. time: {time_est}", fill=True,
                  new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_text_color(*DGRAY)
        self.ln(2)

    def three_col_table(self, headers, rows, col_w=None):
        """Render a 3-column table: Test | Steps | Expected Result."""
        cw = col_w or [52, 72, 50]
        # header
        self.set_fill_color(*NAVY)
        self.set_text_color(*WHITE)
        self.set_font("Helvetica", "B", 8)
        for i, h in enumerate(headers):
            self.cell(cw[i], 7, f"  {h}", fill=True, border=0)
        self.ln()
        # rows
        for idx, row in enumerate(rows):
            bg = LGRAY if idx % 2 == 0 else WHITE
            self.set_fill_color(*bg)
            self.set_text_color(*DGRAY)
            self.set_font("Helvetica", "", 8)
            y0 = self.get_y()
            for ci, col in enumerate(row):
                x_pos = 18 + sum(cw[:ci])
                self.set_xy(x_pos, y0)
                nxt_x = XPos.RIGHT if ci < len(row) - 1 else XPos.LMARGIN
                nxt_y = YPos.TOP  if ci < len(row) - 1 else YPos.NEXT
                self.multi_cell(cw[ci], 5.5, f"  {col}", fill=True, border=0,
                                new_x=nxt_x, new_y=nxt_y)
            # advance past the tallest cell
        self.ln(2)

    def pass_fail_row(self, test_id, description, steps, expected, col_w=None):
        """Single structured test case row with PASS/FAIL label column."""
        cw = col_w or [14, 48, 68, 44]
        bg_id   = TEAL
        bg_body = LGRAY
        y0 = self.get_y()
        # ID badge
        self.set_xy(18, y0)
        self.set_fill_color(*bg_id)
        self.set_text_color(*WHITE)
        self.set_font("Helvetica", "B", 7.5)
        self.multi_cell(cw[0], 5.5, f"  {test_id}", fill=True, border=0,
                        new_x=XPos.RIGHT, new_y=YPos.TOP)
        # Description
        self.set_xy(18 + cw[0], y0)
        self.set_fill_color(*bg_body)
        self.set_text_color(*BLACK)
        self.set_font("Helvetica", "B", 8)
        self.multi_cell(cw[1], 5.5, f"  {description}", fill=True, border=0,
                        new_x=XPos.RIGHT, new_y=YPos.TOP)
        # Steps
        self.set_xy(18 + cw[0] + cw[1], y0)
        self.set_text_color(*DGRAY)
        self.set_font("Helvetica", "", 7.5)
        self.multi_cell(cw[2], 5.5, f"  {steps}", fill=True, border=0,
                        new_x=XPos.RIGHT, new_y=YPos.TOP)
        # Expected
        self.set_xy(18 + cw[0] + cw[1] + cw[2], y0)
        self.set_font("Helvetica", "I", 7.5)
        self.set_text_color(*GREEN)
        self.multi_cell(cw[3], 5.5, f"  {expected}", fill=True, border=0,
                        new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.ln(1)

    def code_block(self, lines):
        """Render a monospace code snippet."""
        self.set_fill_color(30, 30, 30)
        self.set_text_color(180, 240, 160)
        self.set_font("Courier", "", 7.5)
        for line in lines:
            self.set_x(18)
            self.multi_cell(174, 4.8, line, fill=True, border=0,
                            new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_text_color(*DGRAY)
        self.ln(3)

    def val_section_header(self, code, title, color=None):
        c = color or TEAL
        self.ln(2)
        self.set_fill_color(*c)
        self.set_text_color(*WHITE)
        self.set_font("Helvetica", "B", 9.5)
        self.cell(16, 7, f"  {code}", fill=True)
        self.set_fill_color(220, 235, 240)
        self.set_text_color(*NAVY)
        self.cell(158, 7, f"  {title}", fill=True,
                  new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_text_color(*DGRAY)
        self.ln(2)

    def test_card(self, test_id, title, navigate_to, steps,
                  you_should_see, tip=None, warn=None, color=None):
        """
        Render one self-contained interactive test card.
        Automatically starts a new page if there is not enough vertical room.
        """
        tc = color or TEAL
        # --- estimate space needed so we can page-break cleanly --------------
        est = 7 + 6 + len(steps) * 6.5 + 6 + len(you_should_see) * 5.5 + 8
        if tip:  est += 10
        if warn: est += 10
        if self.get_y() + est > 268:
            self.add_page()

        # --- header bar: ID chip + title ------------------------------------
        self.set_font("Helvetica", "B", 8.5)
        self.set_fill_color(*NAVY)
        self.set_text_color(*WHITE)
        self.cell(22, 7, f"  {test_id}", fill=True)
        self.set_fill_color(*tc)
        self.cell(152, 7, f"  {title}", fill=True,
                  new_x=XPos.LMARGIN, new_y=YPos.NEXT)

        # --- WHERE TO GO bar ------------------------------------------------
        self.set_fill_color(228, 241, 245)
        self.set_font("Helvetica", "B", 7.5)
        self.set_text_color(*NAVY)
        self.set_x(18)
        self.cell(26, 5.5, "  WHERE TO GO:", fill=True)
        self.set_font("Helvetica", "", 7.5)
        self.set_text_color(40, 40, 80)
        self.multi_cell(148, 5.5, f"  {navigate_to}", fill=True,
                        new_x=XPos.LMARGIN, new_y=YPos.NEXT)

        # --- numbered steps -------------------------------------------------
        self.set_text_color(*DGRAY)
        for i, s in enumerate(steps, 1):
            self.set_x(18)
            self.set_fill_color(*WHITE)
            self.set_font("Helvetica", "B", 8)
            self.set_text_color(*tc)
            self.cell(11, 5.5, f"  {i}.", fill=True)
            self.set_font("Helvetica", "", 8)
            self.set_text_color(40, 40, 40)
            self.multi_cell(163, 5.5, s, fill=True,
                            new_x=XPos.LMARGIN, new_y=YPos.NEXT)

        # --- YOU SHOULD SEE -------------------------------------------------
        self.set_fill_color(232, 247, 238)
        self.set_font("Helvetica", "B", 7.5)
        self.set_text_color(0, 110, 50)
        self.set_x(18)
        self.cell(174, 5.5, "  YOU SHOULD SEE:", fill=True,
                  new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_font("Helvetica", "", 8)
        self.set_text_color(30, 30, 30)
        for r in you_should_see:
            self.set_x(22)
            self.multi_cell(170, 5, f"- {r}", fill=True,
                            new_x=XPos.LMARGIN, new_y=YPos.NEXT)

        # --- optional TIP ---------------------------------------------------
        if tip:
            self.set_fill_color(255, 252, 230)
            self.set_font("Helvetica", "B", 7.5)
            self.set_text_color(160, 100, 0)
            self.set_x(18)
            self.cell(16, 5, "  TIP:", fill=True)
            self.set_font("Helvetica", "", 7.5)
            self.set_text_color(80, 60, 0)
            self.multi_cell(158, 5, f"  {tip}", fill=True,
                            new_x=XPos.LMARGIN, new_y=YPos.NEXT)

        # --- optional WARNING -----------------------------------------------
        if warn:
            self.set_fill_color(255, 235, 235)
            self.set_font("Helvetica", "B", 7.5)
            self.set_text_color(180, 0, 0)
            self.set_x(18)
            self.cell(22, 5, "  WARNING:", fill=True)
            self.set_font("Helvetica", "", 7.5)
            self.set_text_color(120, 0, 0)
            self.multi_cell(152, 5, f"  {warn}", fill=True,
                            new_x=XPos.LMARGIN, new_y=YPos.NEXT)

        # --- PASS / FAIL tick line ------------------------------------------
        self.set_fill_color(245, 245, 248)
        self.set_font("Helvetica", "", 8)
        self.set_text_color(80, 80, 80)
        self.set_x(18)
        self.cell(174, 7,
                  "  [ ] PASS     [ ] FAIL     Notes: "
                  "________________________________________________",
                  fill=True, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.ln(3)

    def phase_banner(self, phase_num, title, subtitle, color):
        """Full-width coloured banner marking a new validation phase."""
        self.add_page()
        self.set_fill_color(*color)
        self.set_text_color(*WHITE)
        self.set_font("Helvetica", "B", 13)
        self.cell(0, 10, f"  PHASE {phase_num}  --  {title}", fill=True,
                  new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_font("Helvetica", "", 9)
        self.cell(0, 7, f"  {subtitle}", fill=True,
                  new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_text_color(*DGRAY)
        self.ln(4)


# ============================================================================
def build_interactive_validation_section(pdf):
    """
    Section 7 -- Interactive Sandbox Validation Guide.
    Client-facing step-by-step walkthrough. Each test_card tells the user
    exactly where to go, what to do, and what to expect.
    """

    # =========================================================================
    # INTRO PAGE
    # =========================================================================
    pdf.add_page()
    pdf.section_title("SECTION 7 -- INTERACTIVE SANDBOX VALIDATION GUIDE", level=1)
    pdf.body(
        "This guide walks you through 32 hands-on tests to confirm that every part of "
        "the AAR Krembil Salesforce application is working correctly in the sandbox. "
        "You do not need a technical background to complete these tests -- every step "
        "tells you exactly where to click, what to type, and what you should see. "
        "Mark each test PASS or FAIL as you go. Phase 1 tests (VAL-01 to VAL-32) cover "
        "what is live in the sandbox today. Items marked PHASE 2 are in the next sprint.",
        size=9.5
    )

    pdf.two_col_table(
        ["Phase", "What you are testing  |  Approx. time"],
        [
            ("Phase 1", "Quick System Health Check (setup, flows, security)  |  10 min"),
            ("Phase 2", "Scientist Experience -- filling in and submitting the AAR  |  25 min"),
            ("Phase 3", "Research Admin Experience -- reviewing and approving  |  10 min"),
            ("Phase 4", "Institute Director Experience -- final approval and dashboards  |  8 min"),
            ("Phase 5", "Data Integrity Spot Checks -- duplicate and amount rules  |  5 min"),
            ("Scorecard", "Record your PASS / FAIL results and sign off  |  2 min"),
        ]
    )

    pdf.info_box("HOW TO USE THIS GUIDE",
        ["1. Open the sandbox URL in Chrome and keep this PDF open beside it.",
         "2. Follow the 'WHERE TO GO' path in each card to reach the right place in Salesforce.",
         "3. Perform the numbered steps exactly as written.",
         "4. Check 'YOU SHOULD SEE' -- if what you see matches, mark PASS. If not, mark FAIL.",
         "5. Work through phases in order. Each phase depends on the one before it.",
         "6. Return the signed scorecard page at the end of the session."],
        color=NAVY)

    pdf.info_box("PERSONAS REQUIRED",
        ["You will need to be logged in as three different users at different points.",
         "  - SCIENTIST:  Dr. Sarah Chen (AAR Scientist profile)",
         "  - ADMIN:      Research Admin -- Brain & Spinal Cord (AAR Research Admin profile)",
         "  - DIRECTOR:   Institute Director (AAR Institute Leadership profile)",
         "Phase 1 requires a System Administrator login. Phases 2-5 use the personas above.",
         "Use separate Chrome profiles or incognito windows for each persona."],
        color=TEAL)


    # =========================================================================
    # PHASE 1 -- QUICK SYSTEM HEALTH CHECK (System Admin, ~10 min)
    # =========================================================================
    pdf.phase_banner(1, "Quick System Health Check",
        "Log in as System Administrator. Estimated time: 10 minutes.",
        NAVY)

    pdf.test_card(
        "VAL-01", "All Custom Objects, Record Page, and Permission Sets Are Deployed",
        "Gear icon (top-right) > Setup > Quick Find > type 'Object Manager' > Enter",
        [
            "In Object Manager, type 'AAR' in the search box at the top of the list.",
            "Count the results. You should see 14 objects whose names start with 'AAR_'.",
            "Click each object name. On the Details tab, confirm Deployment Status = Deployed.",
            "For AAR_Submission__c: confirm Activities = Enabled and Chatter = Enabled.",
            "From AAR_Submission__c > Lightning Record Pages, confirm 'AAR Submission Record Page' has Type = Org Default.",
            "Navigate to Setup > Permission Sets and confirm AAR_Admin and AAR_PI_Access both exist.",
        ],
        [
            "14 AAR_ objects listed: AAR_Submission__c, AAR_Appointment__c, AAR_Grant__c, AAR_Publication__c, AAR_HQP__c, AAR_Teaching__c, AAR_Award__c, AAR_Presentation__c, AAR_IP_Disclosure__c, AAR_Patent__c, AAR_License__c, AAR_Startup__c, AAR_Outreach__c, AAR_Professional_Activity__c.",
            "Every object shows Deployment Status = Deployed.",
            "AAR_Submission__c: Activities = Enabled, Chatter = Enabled.",
            "'AAR Submission Record Page' is listed with Type = Org Default (highlights panel + Details + Related + Activity sidebar).",
            "AAR_Admin and AAR_PI_Access permission sets exist and cover all 14 AAR objects.",
        ]
    )

    pdf.test_card(
        "VAL-02", "All 3 Automation Flows Are Active",
        "Setup > Quick Find > type 'Flows' > click Flows under Process Automation",
        [
            "In the Flows list, type 'AAR' in the search box.",
            "Check the Status column for each of the 3 AAR flows listed below.",
            "If any show 'Inactive', click the flow name, then click Activate.",
        ],
        [
            "Flow_AAR_Submission_Trigger -- Status: Active (ID: 301Aq000012zVjeIAE)",
            "Flow_AAR_Return_Notification -- Status: Active (ID: 301Aq000012zVjdIAE)",
            "Flow_Annual_AAR_Rollover -- Status: Active, scheduled daily starting 2027-01-01 at 01:00 UTC (ID: 301Aq000012znGfIAI)",
            "All 3 flows show a green Active status badge.",
        ],
        tip="The Approval Process (VAL-03) is a separate feature -- it is NOT a Flow and will not appear in this list. VAL-03 is Phase 2 and not yet deployed."
    )

    pdf.test_card(
        "VAL-03", "Approval Process Is Active  [PHASE 2 -- NOT YET DEPLOYED]",
        "Setup > Quick Find > type 'Approval Processes' > click Approval Processes",
        [
            "In the Manage Approval Processes For dropdown, select 'AAR Submission'.",
            "Find the row for 'Approval_Process_AAR_Submission'.",
            "Confirm the Active checkbox in that row is ticked (checked).",
            "Click the process name and review the two approval steps: Step 1 = Research Admin, Step 2 = Institute Director.",
        ],
        [
            "Approval_Process_AAR_Submission is listed with Active = checked.",
            "Step 1 approver is assigned to the AAR Research Admin role/profile.",
            "Step 2 approver is assigned to the Institute Director role/profile.",
            "Both steps show 'Reject' action = 'Set Status to Returned for Revision'.",
        ],
        warn="PHASE 2 -- The Approval Process has NOT been created yet. This test will FAIL in the current sandbox. "
             "Skip this card and mark it N/A for the demo. The 2-step approval workflow is the top priority for the next sprint."
    )

    pdf.test_card(
        "VAL-04", "Record Visibility Is Set to Private (OWD)  [PHASE 2 -- MANUAL ORG CONFIG REQUIRED]",
        "Setup > Quick Find > type 'Sharing Settings' > click Sharing Settings",
        [
            "Scroll down to the 'Default Internal Access' column in the object list.",
            "Find the row for 'AAR Submission'.",
            "Confirm both Internal and External access columns read 'Private'.",
            "Scroll through the list and find each AAR_ child object. Confirm they all read 'Controlled by Parent'.",
        ],
        [
            "AAR Submission (AAR_Submission__c) shows Default Internal Access = Private.",
            "All 13 child objects (AAR_Appointment__c through AAR_Professional_Activity__c) show 'Controlled by Parent'.",
            "The criteria-based sharing rule for the Brain & Spinal Cord pillar is listed under 'AAR Submission Sharing Rules'.",
        ],
        warn="PHASE 2 -- OWD for AAR_Submission__c has NOT been set to Private and the sharing rule has NOT been deployed. "
             "This must be configured manually in Setup by a System Admin before the sharing-based tests (VAL-06, VAL-18) will work."
    )

    pdf.test_card(
        "VAL-05", "Restricted Fields Are Hidden from the Scientist Profile  [PHASE 2 -- FLS NOT YET CONFIGURED]",
        "Setup > Quick Find > type 'Profiles' > click Profiles > click 'AAR Scientist'",
        [
            "On the AAR Scientist profile page, click 'Field-Level Security' (or scroll to it).",
            "Find 'AAR Publication' in the object list and click View.",
            "Look for the row 'WOS (Office Use Only)' -- confirm Visible = unchecked.",
            "Go back, then repeat for AAR IP Disclosure, AAR Patent, AAR License, and AAR Startup. In each case, find TDC Code and confirm Visible = unchecked.",
        ],
        [
            "WOS__c on AAR Publication: Visible = No / Read Access = No for AAR Scientist.",
            "TDC_Code__c on AAR IP Disclosure: Visible = No for AAR Scientist.",
            "TDC_Code__c on AAR Patent: Visible = No for AAR Scientist.",
            "TDC_Code__c on AAR License: Visible = No for AAR Scientist.",
            "TDC_Code__c on AAR Startup: Visible = No for AAR Scientist.",
        ],
        warn="PHASE 2 -- The AAR Scientist profile and Field-Level Security for WOS__c and TDC_Code__c have NOT been configured. "
             "The 3 custom profiles (AAR Scientist, AAR Research Admin, AAR Institute Leadership) must be created and FLS set before this test can pass.",
        tip="These same fields SHOULD be visible on the AAR Research Admin and AAR Institute Leadership profiles once FLS is configured."
    )

    # =========================================================================
    # PHASE 2 -- SCIENTIST EXPERIENCE (log in as Dr. Sarah Chen, ~25 min)
    # =========================================================================
    pdf.phase_banner(2, "Scientist Experience",
        "Log in as Dr. Sarah Chen (AAR Scientist profile). Estimated time: 25 minutes.",
        TEAL)

    pdf.test_card(
        "VAL-06", "Scientist Sees Only Their Own AAR Records",
        "App Launcher (9-dot grid, top-left) > type 'AAR Submissions' > click AAR Submissions",
        [
            "On the AAR Submissions list view, click 'All AAR Submissions' in the dropdown (or check the default list view).",
            "Look at the records shown. Note the names in the Scientist column.",
            "Try searching for a submission that belongs to a different scientist (e.g. change the filter to a different name).",
        ],
        [
            "The list only shows records where the Scientist field = Dr. Sarah Chen.",
            "No other scientists' submissions are visible -- the list is empty when filtered to another name.",
            "This confirms the Private OWD and record ownership are working correctly.",
        ]
    )

    pdf.test_card(
        "VAL-07", "Open the Draft Annual Report for 2025 -- Verify Record Page Layout",
        "AAR Submissions list > click the Draft record for Reporting Year 2025",
        [
            "Click the record name (e.g. SUB-0001) to open it.",
            "Confirm the page has a highlights panel at the top, a Details tab (active by default), a Related tab, and an Activity sidebar on the right.",
            "On the Details tab, scroll through all 9 sections: Identity, Research Profile, Lay Summary, Context - Leave & Circumstances, Circumstances Affecting Productivity, Clinical Duties, Compliance Declarations, Feedback on Form, System Information.",
            "In Identity: confirm Submission Status = Draft (or Final), Submission Name = SUB-xxxx.",
            "Click Edit -- confirm all fields are editable including Scientist, Reporting Year, Krembil Pillar, Research Keywords, all checkboxes.",
            "Scroll to Compliance Declarations: confirm all 5 checkboxes (Mandatory Training, Patient Engagement, CMaRS, Grants in Good Standing, Form Confirmed) are unchecked.",
            "Click Cancel to exit Edit mode.",
            "Click the Related tab -- confirm all 13 related lists are present (Appointments, Grants, Publications, Awards, HQP, Teaching, Presentations, IP Disclosures, Patents, Licenses, Startups, Outreach, Professional Activities).",
        ],
        [
            "Record opens with highlights panel, Details tab active, Related tab, and Activity sidebar (timeline).",
            "All 9 layout sections are visible when clicking Edit: Identity, Research Profile, Lay Summary, Context - Leave & Circumstances, Circumstances Affecting Productivity, Clinical Duties, Compliance Declarations, Feedback on Form, System Information.",
            "Krembil-specific fields visible in Identity: Krembil Pillar, Krembil Sub Grouping, Research Career Stage, Reporting Year, Reporting Start/End Date.",
            "5 compliance checkboxes present and unchecked.",
            "Related tab shows 13 separate child object sections with New buttons in each.",
            "Activity sidebar shows the activity timeline (Tasks, Emails, Chatter).",
        ],
        tip="Sections with no data entered show as collapsed or hidden in view mode -- click Edit to see all 9 sections in full. This is standard Lightning behaviour."
    )

    pdf.test_card(
        "VAL-08", "Fill In the Research Profile and Context Sections",
        "Same record -- click Edit at the top of the page",
        [
            "In Research Keywords, select any 3 values from the multi-select picklist.",
            "In Lay Summary of Research, type: 'Our lab studies neurodegeneration with a focus on Parkinson disease mechanisms.'",
            "In Protected Time for Research, enter: 60",
            "In Section 3, in Circumstances Affecting Productivity, type: 'Parental leave Jan-Apr 2025 reduced output. Full productivity resumed May 2025.'",
            "Set Leave Start Date to 01/01/2025 and Leave End Date to 30/04/2025.",
            "Click Save.",
        ],
        [
            "Record saves without errors.",
            "Research Keywords shows 3 selected values.",
            "Lay Summary text is saved.",
            "Leave Start Date = 01/01/2025 and Leave End Date = 30/04/2025 are both displayed.",
            "Circumstances Affecting Productivity shows the text you entered.",
        ],
        tip="The Circumstances field is the most important field in the entire form. Evaluators read this before looking at any publication or grant numbers."
    )

    pdf.test_card(
        "VAL-09", "Add an Appointment Record",
        "Scroll down to the 'AAR Appointments' related list > click New",
        [
            "Set Appointment Category = University.",
            "Enter Institution = University of Toronto.",
            "Enter Faculty = Faculty of Medicine.",
            "Enter Appointment Title = Associate Professor.",
            "Set Appointment Type = Cross-Appointment.",
            "Click Save.",
        ],
        [
            "New AAR Appointment record created and appears in the Appointments related list.",
            "The related list row shows: University of Toronto, Associate Professor.",
        ]
    )

    pdf.test_card(
        "VAL-10", "Add a Grant Record (Funded - Active)",
        "Scroll to 'AAR Grants' related list > click New",
        [
            "Set Grant Status = Funded - Active.",
            "Set Funding Type = Operating Grant.",
            "Enter Funding Source = CIHR.",
            "Set Scientist Role = Principal Investigator (PI).",
            "Enter Grant Title = Neuroinflammatory Pathways in Parkinson Disease.",
            "Set Total Award Amount = 500000.",
            "Set Amount Received This Year = 100000.",
            "Click Save.",
        ],
        [
            "Grant record saves successfully.",
            "The grant appears in the AAR Grants related list.",
            "NOTE: The 'Total Active Grants' rollup summary field is Phase 2 (pending Lookup-to-MasterDetail conversion) and will not yet increment.",
        ]
    )

    pdf.test_card(
        "VAL-11", "Add a Peer-Reviewed Publication",
        "Scroll to 'AAR Publications' related list > click New",
        [
            "Set Publication Type = Peer-Reviewed.",
            "Set Article Type = Original Research.",
            "Enter Article Title = LRRK2 Kinase Activity and Synaptic Vesicle Trafficking.",
            "Enter Author List = Chen S, Patel A, Williams R.",
            "Enter Source/Journal = Nature Neuroscience.",
            "Set ePub Date = 15/06/2025.",
            "Enter DOI = https://doi.org/10.1038/nn.12345",
            "Click Save.",
        ],
        [
            "Publication record saves without errors.",
            "Publication appears in the AAR Publications related list.",
            "NOTE: The 'Total Peer Publications' rollup summary field is Phase 2 (pending Lookup-to-MasterDetail conversion) and will not yet increment.",
        ]
    )

    pdf.test_card(
        "VAL-12", "Peer-Reviewed Publication Without ePub Date Is Blocked",
        "AAR Publications related list > click New (create a second test publication)",
        [
            "Set Publication Type = Peer-Reviewed.",
            "Enter Article Title = Test Article -- Validation Check.",
            "Leave the ePub Date field blank.",
            "Click Save.",
        ],
        [
            "IMPORTANT: the save is BLOCKED with an error on the ePub Date field.",
            "Error message reads: 'ePub Date is required for peer-reviewed publications.'",
            "The record is NOT created. Click Cancel after confirming the error appears.",
        ],
        warn="If the save succeeds without an ePub Date, the validation rule is not active. Check Setup > Object Manager > AAR Publication > Validation Rules > Peer_Review_Needs_Epub_Date and ensure it is Active."
    )

    pdf.test_card(
        "VAL-13", "Add a Highly Qualified Personnel (HQP) Trainee",
        "Scroll to 'HQP' related list > click New",
        [
            "Enter Trainee Last Name = Patel.",
            "Enter Trainee First Name = Arjun.",
            "Enter Position/Title = PhD Student.",
            "Set Employment Type = Full-Time.",
            "Set Supervisor Role = Primary Supervisor.",
            "Click Save.",
        ],
        [
            "HQP record saves and appears in the related list.",
            "NOTE: The 'Total HQP' rollup summary field is Phase 2 (pending Lookup-to-MasterDetail conversion) and will not yet increment.",
        ]
    )

    pdf.test_card(
        "VAL-14", "Add Teaching, Award, Presentation, and Outreach Records",
        "Use each corresponding related list. Click New, fill required fields, Save.",
        [
            "AAR Teaching: Instruction Format = Course, Course Title = Neuroscience 301, Hosting Institution = University of Toronto. Save.",
            "AAR Award: Award Name = CIHR New Investigator Award, Awarding Agency = CIHR, Award Category = Research Excellence. Save.",
            "AAR Presentation: Presentation Type = Keynote, Presentation Title = Advances in Parkinson Therapy, Event Name = World Neurology Congress. Save.",
            "AAR Outreach: Outreach Type = Public Outreach, Activity Name = Brain Awareness Week Talk, Event Date = 15/03/2025. Save.",
            "AAR Professional Activity: Activity Type = Grant Reviewing, Organization = CIHR, Role = Panel Reviewer. Save.",
        ],
        [
            "5 new child records created across 5 related lists -- Teaching, Award, Presentation, Outreach, Professional Activity.",
            "Each related list shows the new record without errors.",
        ],
        tip="You do not need to add IP Disclosure, Patent, License, or Startup records for this test -- those are validated separately in Phase 5."
    )

    pdf.test_card(
        "VAL-15", "Attempting to Submit Without Compliance Checks Is Blocked",
        "Edit the AAR Submission record",
        [
            "Click Edit on the main AAR Submission record.",
            "Leave ALL 5 compliance checkboxes unchecked.",
            "Change the Status picklist from Draft to Submitted.",
            "Click Save.",
        ],
        [
            "IMPORTANT: the save is BLOCKED. An error appears on the Mandatory Training Complete field.",
            "Error message: 'MyLearning training must be completed before you can submit your AAR.'",
            "The Status does NOT change to Submitted. The record remains in Draft.",
        ],
        warn="If the status changes to Submitted without the checkboxes being ticked, the validation rules are not working. Check Setup > Object Manager > AAR Submission > Validation Rules and confirm all 4 submission-blocking rules are Active."
    )

    pdf.test_card(
        "VAL-16", "Complete the Compliance Section and Submit the AAR",
        "Edit the AAR Submission record",
        [
            "Click Edit.",
            "Tick all 5 compliance checkboxes: Mandatory Training Complete, Patient Engagement Survey Complete, CMaRS Disclosure Updated, Grants in Good Standing, Form Confirmed Accurate.",
            "Optionally type a note in the 'Feedback on Form' field.",
            "Change Status to Submitted.",
            "Click Save.",
        ],
        [
            "Record saves successfully with Status = Submitted.",
            "The Submission Date/Time field is now populated with today's date and time (auto-set by the Flow).",
            "A confirmation message or toast notification may appear in Salesforce.",
        ]
    )

    pdf.test_card(
        "VAL-17", "Scientist Receives a Confirmation Email",
        "Check the email inbox for Dr. Sarah Chen (the Scientist user's email address)",
        [
            "Open the inbox for the email address associated with Dr. Sarah Chen's Salesforce user.",
            "Look for an email received in the last few minutes.",
            "Open the email and check its content.",
        ],
        [
            "Email received with subject line referencing the AAR submission.",
            "Email body includes a link to the AAR Submission record in Salesforce.",
            "Email is addressed to Dr. Sarah Chen.",
        ],
        tip="If email deliverability is set to 'System email only' in the sandbox, use a sandbox email relay or update Setup > Email > Deliverability > Access Level to 'All email' for testing."
    )

    # =========================================================================
    # PHASE 3 -- RESEARCH ADMIN EXPERIENCE (~10 min)
    # =========================================================================
    pdf.phase_banner(3, "Research Admin Experience",
        "Log in as Research Admin -- Brain & Spinal Cord. Estimated time: 10 minutes.",
        NAVY)

    pdf.test_card(
        "VAL-18", "Admin Sees Only Brain & Spinal Cord Pillar Records",
        "App Launcher > AAR Submissions > open the All AAR Submissions list view",
        [
            "Look at the Krembil Pillar column in the list. Note which pillar values appear.",
            "Try to open a record belonging to a different pillar (e.g. Arthritis or Vision) if any exist.",
        ],
        [
            "The list shows only records where Krembil Pillar = Brain & Spinal Cord.",
            "Records from other pillars (Arthritis, Vision, Neurosciences) are NOT visible.",
            "Dr. Sarah Chen's submitted record appears in the list.",
        ]
    )

    pdf.test_card(
        "VAL-19", "Admin Receives the Submission Notification Email",
        "Check the email inbox for the Research Admin user",
        [
            "Open the inbox for the Research Admin user.",
            "Look for an email that arrived after Dr. Sarah Chen submitted (VAL-16).",
            "Open the email and verify its contents.",
        ],
        [
            "Email received notifying the admin that a Brain & Spinal Cord submission was submitted.",
            "Email identifies the scientist (Dr. Sarah Chen) and includes a link to the record.",
        ]
    )

    pdf.test_card(
        "VAL-20", "WOS Field Is Visible to Admin But Was Hidden from Scientist",
        "Open Dr. Sarah Chen's AAR Submission > go to the AAR Publications related list > click the publication record",
        [
            "Open the peer-reviewed publication you created in VAL-11.",
            "Scroll through the record fields and look for a field labelled 'WOS (Office Use Only)'.",
            "Note that this field IS visible here as the Admin.",
            "For comparison, open a separate browser window or incognito tab, log in as the Scientist (Dr. Sarah Chen), navigate to the same publication, and confirm the WOS field does NOT appear.",
        ],
        [
            "As Admin: WOS (Office Use Only) field is visible on the publication record.",
            "As Scientist: WOS field is completely absent from the page -- not visible, not read-only, simply not there.",
        ]
    )

    pdf.test_card(
        "VAL-21", "Admin Enters the WOS ID on the Publication",
        "Still on the Publication record (logged in as Admin) > click Edit",
        [
            "Click Edit on the publication record.",
            "In the WOS (Office Use Only) field, type: WOS:000456789012.",
            "Click Save.",
        ],
        [
            "Publication saves successfully with the WOS ID populated.",
            "The WOS field displays the value you entered.",
            "If you refresh as the Scientist, the WOS field is still not visible.",
        ]
    )

    pdf.test_card(
        "VAL-22", "Admin Initiates the Step 1 Approval  [PHASE 2 -- APPROVAL PROCESS NOT YET DEPLOYED]",
        "Navigate back to Dr. Sarah Chen's AAR Submission record (as Admin)",
        [
            "On the AAR Submission record, look for the 'Submit for Approval' button. It may be in the page header or in an Approval History section at the bottom.",
            "Click 'Submit for Approval'.",
            "If prompted for a comment, enter: 'Data verified. All publications and grants confirmed.'",
            "Click Submit.",
        ],
        [
            "The record enters the approval process. Approval History shows a pending approval entry.",
            "A notification or email is dispatched to the Institute Director (Step 2 approver).",
            "The record is now locked for editing by the Scientist until the process completes.",
        ],
        warn="PHASE 2 -- The Approval Process has not been created. There will be no 'Submit for Approval' button. Skip VAL-22, VAL-23, VAL-25, VAL-26 and mark them N/A.",
        tip="Once deployed: if you do not see a 'Submit for Approval' button, ensure Status = Submitted and the Approval Process is Active."
    )

    pdf.test_card(
        "VAL-23", "Admin Approves at Step 1  [PHASE 2]",
        "Open the approval request from the Admin's notification bell or from the Approval History section on the record",
        [
            "Click the pending approval request to open it.",
            "Review the summary of the record.",
            "Click Approve.",
            "If prompted for a comment, enter: 'Step 1 approved by Research Admin.'",
        ],
        [
            "Approval step 1 is marked as Approved in the Approval History.",
            "An approval request is automatically dispatched to the Institute Director for Step 2.",
        ]
    )

    # =========================================================================
    # PHASE 4 -- INSTITUTE DIRECTOR EXPERIENCE (~8 min)
    # =========================================================================
    pdf.phase_banner(4, "Institute Director Experience",
        "Log in as Institute Director (AAR Institute Leadership profile). Estimated time: 8 minutes.",
        GREEN)

    pdf.test_card(
        "VAL-24", "Director Sees All Submissions Across All Pillars",
        "App Launcher > AAR Submissions > open All AAR Submissions",
        [
            "Look at the Krembil Pillar column. Check whether records from multiple pillars appear.",
            "If only seed data exists, this may show just Brain & Spinal Cord -- that is acceptable if no other pillar data was created.",
            "Confirm that Dr. Chen's submitted record IS visible here.",
        ],
        [
            "AAR Submission records are visible regardless of pillar (Institute Leadership has full read/write access).",
            "Dr. Sarah Chen's submission is visible and shows Status = Submitted (or Under Review if the approval has moved it).",
        ]
    )

    pdf.test_card(
        "VAL-25", "Director Approves at Step 2 -- Status Becomes Approved  [PHASE 2]",
        "Open the pending approval request from the notification bell (top-right) or Approval History on the record",
        [
            "Click the Step 2 approval request to open it.",
            "Review the submission details.",
            "Click Approve.",
            "Navigate back to Dr. Chen's AAR Submission record and refresh the page.",
        ],
        [
            "Status on the AAR Submission record = Approved.",
            "Approval History shows both Step 1 (Admin) and Step 2 (Director) as Approved.",
            "The record is now in its final approved state -- no further workflow actions are pending.",
        ]
    )

    pdf.test_card(
        "VAL-26", "Test the Rejection Path -- Status Returns to Scientist  [PHASE 2]",
        "Create a second test AAR Submission in Draft status, complete compliance, submit, then submit for approval",
        [
            "Quickly create a minimal second test submission: any scientist, Status = Draft, check all 5 compliance boxes, change Status to Submitted.",
            "Submit the record for Approval.",
            "As Admin: open the Step 1 approval request and click Reject. Enter a comment: 'Missing grant details.'",
            "Navigate to the AAR Submission record and check its Status.",
            "Check the email inbox of the Scientist user.",
        ],
        [
            "Status on the record changes to Returned for Revision.",
            "Scientist receives an email notifying them of the return, including the reviewer comment 'Missing grant details.'",
            "The record is unlocked and the Scientist can edit it again.",
        ],
        tip="You can delete this second test record after validating the rejection path. It is not needed for the demo."
    )

    pdf.test_card(
        "VAL-27", "Institute Research Overview Dashboard Shows Live Data  [PHASE 2 -- NOT YET DEPLOYED]",
        "App Launcher > Dashboards > Institute Research Overview",
        [
            "Click on the Institute Research Overview dashboard.",
            "Click Refresh (top-right of the dashboard) to pull the latest data.",
            "Look at each of the 4 dashboard components.",
        ],
        [
            "Component 1 (Submission Rate by Pillar): shows at least 1 bar for Brain & Spinal Cord with a non-zero completion percentage.",
            "Component 2 (Total Active Funding): shows a non-zero funding figure (from the Funded-Active grant added in VAL-10).",
            "Component 3 (Publications by Career Stage): shows at least 1 publication in the Mid Career bar.",
            "Component 4 (HQP Pipeline): shows at least 1 trainee counted under PhD Student.",
        ],
        warn="PHASE 2 -- Reports and dashboards have NOT been deployed. This test will FAIL. "
             "The Institute Research Overview dashboard and all underlying reports are in the next sprint. Mark this card N/A for current validation."
    )

    pdf.test_card(
        "VAL-28", "Submission Status by Pillar Report Returns Data  [PHASE 2 -- NOT YET DEPLOYED]",
        "App Launcher > Reports > Submission Status by Pillar > click Run",
        [
            "Click Run Report (or Run) to execute the report.",
            "Look at the rows returned.",
            "Try filtering by Status = Approved.",
        ],
        [
            "Report runs without errors.",
            "At least one row is returned showing Brain & Spinal Cord pillar.",
            "Dr. Sarah Chen's submission appears with Status = Approved.",
            "HQP Pipeline by Position report also runs: navigate to it and confirm Arjun Patel (PhD Student) appears.",
        ],
        warn="PHASE 2 -- Custom reports have NOT been deployed. This test will FAIL. Mark N/A for current validation."
    )

    # =========================================================================
    # PHASE 5 -- DATA INTEGRITY SPOT CHECKS (~5 min)
    # =========================================================================
    pdf.phase_banner(5, "Data Integrity Spot Checks",
        "Log in as System Administrator. Estimated time: 5 minutes.",
        AMBER)

    pdf.test_card(
        "VAL-29", "Cannot Create a Duplicate AAR for the Same Scientist and Year  [PHASE 2 -- RULE NOT YET DEPLOYED]",
        "App Launcher > AAR Submissions > click New",
        [
            "Click New to create a new AAR Submission.",
            "Set Scientist = Dr. Sarah Chen.",
            "Set Reporting Year = 2025 (same as the existing record).",
            "Fill in any required fields (Pillar, Career Stage, etc.).",
            "Click Save.",
        ],
        [
            "IMPORTANT: the save is BLOCKED by the duplicate rule.",
            "Salesforce shows a duplicate warning or error explaining that a record already exists for this scientist and year.",
            "No second record is created.",
        ],
        warn="PHASE 2 -- The Duplicate Rule for AAR_Submission__c has NOT been created. The duplicate will NOT be blocked. "
             "Create the rule in Setup > Duplicate Rules before running this test. Mark N/A for current validation."
    )

    pdf.test_card(
        "VAL-30", "Grant Amount Received Cannot Exceed Total Award Amount  [PHASE 2 -- RULE NOT YET CONFIRMED]",
        "Open any AAR_Grant__c record > click Edit",
        [
            "Open the grant you created in VAL-10 (CIHR, Total Award Amount = 500,000).",
            "Click Edit.",
            "Change Amount Received This Year to 600,000 (which exceeds the 500,000 total).",
            "Click Save.",
        ],
        [
            "IMPORTANT: the save is BLOCKED.",
            "Error appears on Amount Received This Year: 'Amount received this year cannot exceed the total award amount.'",
            "The grant record is not updated.",
            "Change the value back to 100,000 and Save -- this should succeed.",
        ],
        warn="PHASE 2 -- The grant amount cross-field validation rule on AAR_Grant__c has NOT been confirmed as deployed. "
             "Check Setup > Object Manager > AAR Grant > Validation Rules before running this test. Mark N/A if the rule is absent."
    )

    pdf.test_card(
        "VAL-31", "Innovation Records: TDC Code Hidden from Scientist, Visible to Admin  [PHASE 2 -- FLS NOT YET CONFIGURED]",
        "Create one IP Disclosure, one Patent, one License, and one Startup record on the AAR Submission (as Scientist)",
        [
            "As Scientist (Dr. Sarah Chen): go to each of the 4 Innovation-related lists -- IP Disclosures, Patents, Licenses, Startups -- and create one record in each with minimum required fields.",
            "For IP Disclosure: enter any Disclosure Date, Invention Title. Save.",
            "For Patent: enter any Filing Date, Patent Title. Save.",
            "For License: set License Type = Exclusive, enter any Licensing Party. Save.",
            "For Startup: enter any Company Name, Description. Save.",
            "On each record, confirm that the TDC Code field is NOT visible to you as the Scientist.",
            "Switch to the Admin login. Open one of the same records and confirm TDC Code IS visible.",
        ],
        [
            "As Scientist: all 4 records created successfully. TDC Code field is absent from every record view.",
            "As Admin: TDC Code field is visible and editable on all 4 object types.",
        ],
        warn="PHASE 2 -- FLS for TDC_Code__c has NOT been configured. The field will be visible to all users regardless of profile. Mark N/A until profiles and FLS are set up."
    )

    pdf.test_card(
        "VAL-32", "Rollup Summary Counters Are Accurate on the Master Record  [PHASE 2 -- ROLLUP FIELDS PENDING]",
        "Open Dr. Sarah Chen's Approved AAR Submission record",
        [
            "Scroll to the top of the record and locate the 3 rollup summary fields.",
            "Check Total Peer Publications -- compare to the number of Peer-Reviewed publications in the related list.",
            "Check Total Active Grants -- compare to the number of Funded-Active grants in the related list.",
            "Check Total HQP -- compare to the total number of records in the HQP related list.",
        ],
        [
            "Total Peer Publications = number of publications with Publication Type = Peer-Reviewed (should be 1 based on VAL-11).",
            "Total Active Grants = number of grants with Grant Status = Funded - Active (should be 1 based on VAL-10).",
            "Total HQP = total HQP child records regardless of type (should be 1 based on VAL-13).",
            "All 3 rollup values match the actual child record counts.",
        ],
        warn="PHASE 2 -- Rollup Summary fields require MasterDetail relationships, but AAR_Grant__c, AAR_Publication__c, and AAR_HQP__c "
             "currently use Lookup fields to AAR_Submission__c. These 3 fields cannot be created until Lookup relationships are converted "
             "to MasterDetail in Setup. This is the top data-model task in Phase 2. Mark N/A for current validation."
    )

    # =========================================================================
    # SCORECARD
    # =========================================================================
    pdf.add_page()
    pdf.section_title("VALIDATION SCORECARD -- Record Your Results Here", level=1)
    pdf.body(
        "Mark each test PASS or FAIL as you complete it. Tests marked [P2] are Phase 2 items not yet deployed -- "
        "mark them N/A rather than FAIL. All Phase 1 tests (no [P2] marker) must show PASS before the demo is cleared to proceed. "
        "If any Phase 1 test is FAIL, note what you saw in the Notes column and contact the implementation team."
    )

    pdf.three_col_table(
        ["Test ID", "What Is Being Tested", "PASS / FAIL / N/A"],
        [
            ("VAL-01", "All 14 custom objects deployed", ""),
            ("VAL-02", "All 3 automation flows active (IDs confirmed)", ""),
            ("VAL-03", "[P2] Approval process active with 2 steps", "N/A"),
            ("VAL-04", "[P2] OWD = Private / child objects = Controlled by Parent", "N/A"),
            ("VAL-05", "[P2] FLS: WOS and TDC fields hidden from Scientist profile", "N/A"),
            ("VAL-06", "[P2] Scientist sees only their own records (needs OWD)", "N/A"),
            ("VAL-07", "Draft AAR opens with correct 9-section layout + record page", ""),
            ("VAL-08", "Research Profile and Context sections save correctly", ""),
            ("VAL-09", "Appointment record adds to related list", ""),
            ("VAL-10", "Funded-Active grant record saves (rollup counter is P2)", ""),
            ("VAL-11", "Peer-reviewed publication saves (rollup counter is P2)", ""),
            ("VAL-12", "Peer-reviewed publication WITHOUT ePub Date is blocked", ""),
            ("VAL-13", "HQP trainee record saves (Total HQP rollup is P2)", ""),
            ("VAL-14", "Teaching, Award, Presentation, Outreach, Prof. Activity add", ""),
            ("VAL-15", "Submitting without compliance checkboxes is blocked (4 rules)", ""),
            ("VAL-16", "Submission succeeds with all 5 checkboxes ticked", ""),
            ("VAL-17", "Scientist receives confirmation email on submit", ""),
            ("VAL-18", "[P2] Admin sees only Brain & Spinal Cord pillar (needs OWD)", "N/A"),
            ("VAL-19", "Admin receives submission notification email", ""),
            ("VAL-20", "[P2] WOS field visible to Admin but hidden from Scientist", "N/A"),
            ("VAL-21", "Admin saves WOS ID on publication successfully", ""),
            ("VAL-22", "[P2] Admin initiates Step 1 approval -- no approval process yet", "N/A"),
            ("VAL-23", "[P2] Admin approves Step 1; Step 2 request sent to Director", "N/A"),
            ("VAL-24", "Director sees all submissions across all pillars", ""),
            ("VAL-25", "[P2] Director approves Step 2; Status = Approved", "N/A"),
            ("VAL-26", "[P2] Rejection sets Status = Returned for Revision + email", "N/A"),
            ("VAL-27", "[P2] Dashboard shows live data across 4 components", "N/A"),
            ("VAL-28", "[P2] Reports run and return expected data", "N/A"),
            ("VAL-29", "[P2] Duplicate AAR for same Scientist + Year is blocked", "N/A"),
            ("VAL-30", "[P2] Grant amount received > total award amount is blocked", "N/A"),
            ("VAL-31", "[P2] TDC Code fields hidden from Scientist on 4 objects", "N/A"),
            ("VAL-32", "[P2] Rollup summary counters match child record counts", "N/A"),
        ],
        col_w=[20, 100, 54]
    )

    pdf.ln(2)
    pdf.info_box("SIGN-OFF",
        ["Validated by: ___________________________________   Role: ___________________   Date: ___________",
         "",
         "Phase 1 tests: VAL-01, 02, 07-17, 19, 21, 24     PASS: _______     FAIL: _______",
         "Phase 2 items (N/A today): VAL-03, 04, 05, 06, 18, 20, 22, 23, 25, 26, 27, 28, 29, 30, 31, 32",
         "",
         "Demo on Thursday 29 May 2026 at 11:00 AM is cleared to proceed:   [ ] YES     [ ] NO",
         "",
         "Outstanding issues (if any): _______________________________________________________________"],
        color=GREEN)



# ============================================================================
def build_pdf():
    pdf = DemoGuide()
    pdf.set_title("AAR Krembil - Salesforce Client Demo Guide")
    pdf.set_author("UHN Business Hub")

    # -- COVER PAGE -----------------------------------------------------------
    pdf.add_page()
    pdf.set_fill_color(*NAVY)
    pdf.rect(0, 0, 210, 297, style="F")

    pdf.set_text_color(*WHITE)
    pdf.set_font("Helvetica", "B", 26)
    pdf.set_xy(18, 70)
    pdf.multi_cell(174, 12, "Annual Activity Report\n(AAR) Krembil",
                   new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.set_font("Helvetica", "", 14)
    pdf.set_xy(18, pdf.get_y() + 4)
    pdf.cell(0, 8, "Salesforce Sandbox -- Client Demo Guide",
             new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.set_fill_color(*TEAL)
    pdf.rect(18, pdf.get_y() + 4, 174, 1, style="F")

    pdf.set_font("Helvetica", "", 11)
    pdf.set_xy(18, pdf.get_y() + 10)
    pdf.cell(0, 7, "Thursday, 29 May 2026  |  11:00 AM",
             new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.cell(0, 7, "UHN Business Hub  x  Krembil Research Institute",
             new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.set_font("Helvetica", "", 9)
    pdf.set_text_color(180, 200, 220)
    pdf.set_xy(18, 240)
    pdf.cell(0, 6, "CONFIDENTIAL -- For demo purposes only. Not for distribution.",
             new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    # -- PAGE 2 -- EXECUTIVE SUMMARY ------------------------------------------
    pdf.add_page()
    pdf.section_title("SECTION 1 -- EXECUTIVE SUMMARY", level=1)
    pdf.body(
        "The Annual Activity Report (AAR) for Krembil Research Institute is a fully custom "
        "Salesforce application built on the UHN Business Hub. It replaces the manual "
        "paper/spreadsheet AAR process with a structured, auditable, and reportable digital "
        "workflow -- covering every facet of a scientist's annual output.", size=9.5
    )

    pdf.section_title("Data Model at a Glance", level=3)
    pdf.two_col_table(
        ["Component", "Detail"],
        [
            ("Architecture",       "Hub-and-spoke: 1 master + 1 Master-Detail child (AAR_Award__c) + 12 Lookup children"),
            ("Master Object",      "AAR_Submission__c -- one record per scientist per year"),
            ("Custom Objects",     "15 total (14 AAR objects + Contact extended with ORCID)"),
            ("Custom Fields",      "174 fields across all objects"),
            ("Record Page",        "AAR Submission Record Page -- active as Org Default; highlights panel, 9-section Details layout, 13-list Related tab, Activity sidebar"),
            ("Permission Sets",    "AAR_Admin (full CRUD + viewAllFields on all 14 AAR objects)  /  AAR_PI_Access (CRE, explicit FLS on all fields)"),
            ("Security Profiles",  "AAR Scientist  /  AAR Research Admin  /  AAR Institute Leadership  [Phase 2]"),
            ("Automation",         "3 Flows active (submit trigger, return notification, annual rollover) + Approval Process [Phase 2]"),
            ("Validation Rules",   "6 rules active: 5 on AAR Submission + 1 on AAR Publication"),
            ("Reports/Dashboards", "3 custom report types, 4 key reports, 2 dashboards [Phase 2]"),
        ]
    )

    pdf.section_title("Object Inventory", level=3)
    pdf.two_col_table(
        ["Object (API Name)", "Category & Purpose"],
        [
            ("AAR_Submission__c",           "CORE -- Master record; one per scientist per year"),
            ("Contact (extended)",          "PROFILE -- Scientist identity; adds ORCID, institute, career fields"),
            ("AAR_Appointment__c",          "PROFILE -- UHN & University appointments"),
            ("AAR_Grant__c",                "RESEARCH -- All funding (submitted / active / declined)"),
            ("AAR_Publication__c",          "RESEARCH -- Peer-reviewed, non-peer-reviewed, in-progress"),
            ("AAR_HQP__c",                  "PEOPLE -- Trainees and supervised staff"),
            ("AAR_Teaching__c",             "PEOPLE -- Courses, workshops, grand rounds"),
            ("AAR_Award__c",                "RESEARCH -- Prizes, fellowships, honours"),
            ("AAR_Presentation__c",         "ENGAGEMENT -- Keynote / plenary presentations"),
            ("AAR_IP_Disclosure__c",        "INNOVATION -- Technology disclosures to TDC"),
            ("AAR_Patent__c",               "INNOVATION -- Patent filings (provisional -> issued)"),
            ("AAR_License__c",              "INNOVATION -- Licensing agreements"),
            ("AAR_Startup__c",              "INNOVATION -- Spin-off companies"),
            ("AAR_Outreach__c",             "ENGAGEMENT -- Outreach, media, conference attendance"),
            ("AAR_Professional_Activity__c","ENGAGEMENT -- Committee work, journal reviewing, consulting"),
        ]
    )

    pdf.section_title("Key Workflow States", level=3)
    pdf.two_col_table(
        ["Status", "What it means"],
        [
            ("Draft",                "Scientist is actively filling in the form"),
            ("Submitted",            "Scientist has checked all compliance boxes and submitted"),
            ("Under Review",         "Research Admin (step 1) is reviewing"),
            ("Approved",             "Institute Director (step 2) has approved"),
            ("Returned for Revision","Admin or Director rejected; scientist notified by email"),
        ]
    )

    # -- PAGE 3 -- PRE-DEMO CHECKLIST -----------------------------------------
    pdf.add_page()
    pdf.section_title("SECTION 2 -- PRE-DEMO SETUP CHECKLIST", level=1)
    pdf.body("Complete the following in the sandbox at least 30 minutes before the demo.")

    pdf.section_title("Sandbox Users to Pre-create", level=3)
    pdf.checklist_item("Scientist user: Dr. Sarah Chen  --  Profile: AAR Scientist  |  Krembil Pillar: Brain & Spinal Cord  |  Career Stage: Mid Career")
    pdf.checklist_item("Research Admin user: Admin User  --  Profile: AAR Research Admin  |  Assigned Pillar: Brain & Spinal Cord")
    pdf.checklist_item("Director user: Institute Director  --  Profile: AAR Institute Leadership")
    pdf.ln(2)

    pdf.section_title("Seed Data Required", level=3)
    pdf.checklist_item("Contact record for Dr. Sarah Chen with ORCID field populated")
    pdf.checklist_item("AAR Submission (Draft) for Dr. Sarah Chen, Reporting Year 2025 -- auto-created by rollover Flow or created manually")
    pdf.checklist_item("Pre-populate 2 x AAR_Grant__c child records (one Active, one Submitted) to save time during demo")
    pdf.checklist_item("Pre-populate 1 x AAR_Publication__c (Peer-Reviewed, with Epub Date) so the Rollup Summary counter shows a non-zero value")
    pdf.checklist_item("Pre-populate 1 x AAR_HQP__c (PhD Student, Primary Supervisor)")
    pdf.ln(2)

    pdf.section_title("Browser Tabs to Have Open", level=3)
    pdf.checklist_item("Tab 1 -- Logged in as Dr. Sarah Chen (Scientist)")
    pdf.checklist_item("Tab 2 -- Logged in as Research Admin")
    pdf.checklist_item("Tab 3 -- Logged in as Institute Director / Leadership")
    pdf.checklist_item("Tab 4 -- Reports & Dashboards (Institute Research Overview)")
    pdf.ln(2)

    pdf.section_title("Technical Checks -- Phase 1 (Deployed & Active)", level=3)
    pdf.checklist_item("DONE: Confirm all 3 Flows are Active in Setup > Flows (VAL-02 -- IDs verified in sandbox)")
    pdf.checklist_item("DONE: AAR_Submission__c, AAR_Publication__c, AAR_Award__c and all 12 child objects deployed with fields")
    pdf.checklist_item("DONE: 5 validation rules active on AAR_Submission__c + 1 on AAR_Publication__c")
    pdf.checklist_item("DONE: Lightning Record Page 'AAR Submission Record Page' deployed and activated as Org Default -- highlights panel, Details tab (9 sections), Related tab (13 lists), Activity sidebar")
    pdf.checklist_item("DONE: Activities enabled on AAR_Submission__c -- Activity timeline and Chatter sidebar are live")
    pdf.checklist_item("DONE: AAR_Admin and AAR_PI_Access permission sets updated with full field coverage for all 14 AAR objects (incl. AAR_Award__c, AAR_Publication__c, and all Krembil-era AAR_Submission__c fields)")
    pdf.checklist_item("Activate Lightning Record Page if not yet org default: Setup > Object Manager > AAR Submission > Lightning Record Pages > Activate > Org Default")
    pdf.checklist_item("Verify email deliverability is ON in Setup > Email > Deliverability (set to All Email for sandbox testing)")
    pdf.checklist_item("Clear browser cache / use incognito tabs for clean demo views")
    pdf.ln(2)
    pdf.section_title("Phase 2 Blockers -- NOT Yet Deployed (skip these in today's demo)", level=3)
    pdf.checklist_item("[P2] Approval Process on AAR_Submission__c -- 2-step (Research Admin + Director)")
    pdf.checklist_item("[P2] OWD for AAR_Submission__c set to Private in Sharing Settings")
    pdf.checklist_item("[P2] Criteria-based Sharing Rule for pillar-scoped admin access")
    pdf.checklist_item("[P2] 3 Custom Profiles: AAR Scientist, AAR Research Admin, AAR Institute Leadership")
    pdf.checklist_item("[P2] FLS: WOS__c hidden from AAR Scientist; TDC_Code__c hidden from AAR Scientist")
    pdf.checklist_item("[P2] Duplicate Rule preventing 2 submissions for same Scientist + Reporting Year")
    pdf.checklist_item("[P2] Rollup Summary fields on AAR_Submission__c (requires Lookup->MasterDetail conversion)")
    pdf.checklist_item("[P2] Reports and dashboards (Institute Research Overview, Submission Status by Pillar)")

    pdf.ln(2)
    pdf.info_box("PRE-DEMO TIP",
        ["Log in as each persona in separate Chrome profiles (not just tabs) to avoid session conflicts. "
         "Use Chrome Profile 1 = Scientist, Profile 2 = Admin, Profile 3 = Director."],
        color=TEAL)

    # -- PAGE 4 -- DEMO SCRIPT ------------------------------------------------
    pdf.add_page()
    pdf.section_title("SECTION 3 -- INTERACTIVE DEMO SCRIPT", level=1)
    pdf.body("Estimated total demo time: 35-45 minutes. Talking points are in italic below each step.")

    # -- PART A -- SCIENTIST --------------------------------------------------
    pdf.persona_banner("Dr. Sarah Chen -- AAR Scientist", "15 min", TEAL)

    pdf.step(1, "Open the AAR Submission for 2025",
        ["Navigate to the AAR Submissions tab and open the Draft record.",
         "TALKING POINT: 'The system automatically created this blank submission on January 1st via a scheduled Flow -- every active scientist gets one. No one has to remember to start a form.'",
         "Show the Identity section: Scientist name, Reporting Year, Status = Draft, Pillar = Brain & Spinal Cord."],
        persona_color=TEAL)

    pdf.step(2, "Complete the Research Profile section",
        ["Fill in Research Keywords (multi-select picklist -- select 3).",
         "Enter a short Lay Summary of Research.",
         "Set Protected Time for Research to 60%.",
         "TALKING POINT: 'Keywords power the cross-institute dashboards. Leadership can filter all outputs by research theme across all pillars.'"],
        persona_color=TEAL)

    pdf.step(3, "Fill in the Context section (Circumstances Affecting Productivity)",
        ["Enter a note: 'Parental leave Jan-Apr 2025.'",
         "Set Leave Start Date = 01/01/2025, Leave End Date = 30/04/2025.",
         "TALKING POINT: 'This section is highlighted prominently on the layout -- it tells evaluators HOW to read the output data. It is the single most important context field. Evaluators see this before they see any publication or grant numbers.'"],
        persona_color=TEAL)

    pdf.step(4, "Add a new Publication",
        ["Scroll to the AAR Publication related list. Click New.",
         "Select Publication Type = Peer-Reviewed.",
         "Enter Article Title, Author List, Source/Journal, ePub Date (required for peer-reviewed), and DOI.",
         "TALKING POINT: 'Scientists self-enter publications. Future phase will auto-populate from ORCID API -- highest priority integration in the roadmap.'",
         "Note: the WOS field is invisible to the scientist (FLS). Show the admin tab later to contrast."],
        persona_color=TEAL)

    pdf.step(5, "Add a new HQP Trainee",
        ["Scroll to HQP related list. Click New.",
         "Enter: Last Name = Patel, First Name = Arjun, Position = PhD Student, Employment = Full-Time, Supervisor Role = Primary Supervisor.",
         "TALKING POINT: 'Every trainee row feeds the HQP Pipeline report for CIHR/NSERC funder reporting. Research Admin no longer needs to manually compile trainee counts.'"],
        persona_color=TEAL)

    pdf.step(6, "Attempt to submit WITHOUT compliance checks",
        ["Change Status picklist to Submitted and click Save.",
         "EXPECTED RESULT: Validation rule fires -- 'MyLearning training must be completed before you can submit your AAR.'",
         "TALKING POINT: 'The system enforces the five compliance declarations. Scientists cannot skip them. This replaces the honour-system checkbox email that used to get ignored.'"],
        persona_color=TEAL)

    pdf.step(7, "Complete Compliance Declarations and Submit",
        ["Tick all five checkboxes: Mandatory Training Complete, Patient Engagement Survey, CMaRS Updated, Grants in Good Standing, Form Confirmed Accurate.",
         "Optionally enter Form Feedback text.",
         "Change Status to Submitted. Save.",
         "EXPECTED RESULT: Status saves as Submitted. Submitted Date/Time auto-populates (Flow). Confirmation email sent to scientist. Notification email sent to Research Admin for Brain & Spinal Cord pillar.",
         "TALKING POINT: 'Status change triggers two automated emails -- scientist gets a receipt, admin gets an alert. Zero manual follow-up required.'"],
        persona_color=TEAL)

    # -- PART B -- RESEARCH ADMIN ---------------------------------------------
    pdf.add_page()
    pdf.persona_banner("Research Admin -- Brain & Spinal Cord Pillar", "10 min", NAVY)

    pdf.step(8, "Admin opens their submission queue",
        ["Switch to the Admin browser tab.",
         "Show that the admin can see Dr. Chen's submission (Sharing Rule grants Read/Write access to all Brain & Spinal Cord submissions).",
         "TALKING POINT: 'Sharing rules mean admins see only their pillar -- not all submissions across the institute. Data is scoped automatically.'"],
        persona_color=NAVY)

    pdf.step(9, "Review Publications and enter the WOS field",
        ["Open Dr. Chen's submission. Navigate to the Publication related list.",
         "Open the peer-reviewed publication record.",
         "SHOW: The WOS (Web of Science ID) field is now VISIBLE to the admin.",
         "Enter a sample WOS ID: WOS:000123456789.",
         "TALKING POINT: 'This field is hidden from scientists via Field-Level Security. Admins and leadership enter WOS IDs after cross-checking the Web of Science database -- keeping source-of-truth integrity.'"],
        persona_color=NAVY)

    pdf.step(10, "Initiate the Approval Process -- Step 1",
        ["From the AAR Submission record, click the Submit for Approval button (or show the Approval section).",
         "Admin approves at Step 1.",
         "EXPECTED RESULT: Record moves to Under Review, Step 2 approval request sent to Institute Director.",
         "TALKING POINT: 'Two-step approval mirrors the real Krembil process: Research Admin verifies data completeness, then the Institute Director gives final sign-off.'"],
        persona_color=NAVY)

    # -- PART C -- INSTITUTE DIRECTOR -----------------------------------------
    pdf.persona_banner("Institute Director -- Leadership View", "7 min", GREEN)

    pdf.step(11, "Director approves the submission",
        ["Switch to the Director browser tab.",
         "Open the pending approval item from the Approval notification or Approval History.",
         "Approve.",
         "EXPECTED RESULT: Status = Approved. No further workflow steps.",
         "TALKING POINT: 'Alternatively, the director can Return for Revision -- which triggers an automated email to the scientist with reviewer notes from the Chatter feed.'"],
        persona_color=GREEN)

    pdf.step(12, "Demonstrate the Institute Research Overview Dashboard",
        ["Navigate to the Dashboards tab -> Institute Research Overview.",
         "Show the four dashboard components:",
         "  (a) Submission Rate by Pillar -- bar chart showing % complete across Brain & Spinal Cord, Arthritis, Vision, Neurosciences.",
         "  (b) Total Active Funding -- sum of Amount Received This Year for Grant_Status = Funded-Active.",
         "  (c) Publications by Career Stage -- grouped bar by Early / Mid / Senior Career.",
         "  (d) HQP Pipeline -- count by Position Title (PhD, PostDoc, Coordinator, etc.)",
         "TALKING POINT: 'Leadership had zero real-time visibility before. This dashboard refreshes on demand. Every metric traces back to scientist-entered data, now structured and reportable.'"],
        persona_color=GREEN)

    pdf.step(13, "Show Submission Status by Pillar Report",
        ["Navigate to Reports -> Submission Status by Pillar.",
         "Show that you can filter by Status, Pillar, Career Stage, and Reporting Year.",
         "TALKING POINT: 'At the end of the reporting season, leadership runs this to see who has and hasn't submitted. Historically this was a manual email-chase process.'"],
        persona_color=GREEN)

    # -- PAGE -- DEMO WRAP-UP -------------------------------------------------
    pdf.add_page()
    pdf.section_title("SECTION 4 -- DEMO WRAP-UP & TALKING POINTS", level=1)

    pdf.section_title("Value Delivered -- Key Messages", level=3)
    rows_value = [
        ("Scientist burden",    "Structured form replaces blank Word doc. Rollover creates submissions automatically. ORCID integration (roadmap) eliminates manual publication entry."),
        ("Admin efficiency",    "Pillar-scoped data access. WOS and TDC enrichment in-platform. Approval workflow replaces email chains."),
        ("Leadership insight",  "Real-time dashboard vs. annual compiled spreadsheet. Cross-pillar comparisons in one view."),
        ("Compliance",          "Five validation-enforced declarations. Cannot submit without checking every box. Audit trail via Status history."),
        ("Scalability",         "Binding configuration (custom metadata) extends framework to other institutes (e.g. Toronto Western, PM&R) with no code changes."),
        ("Future integrations", "ORCID (High), MyLearning (Medium), CMaRS (Medium), CIHR/NSERC (Low) -- roadmap items discussed."),
    ]
    pdf.two_col_table(["Value Area", "Message"], rows_value)

    pdf.section_title("Anticipated Client Questions & Answers", level=3)

    pdf.info_box("Q: Can a scientist edit their submission after it has been Submitted?",
        ["A: Not by default -- once Submitted, the record is locked pending admin review. "
         "If revision is needed, the admin returns it (Status = Returned for Revision), "
         "which unlocks it and notifies the scientist via email."], color=TEAL)

    pdf.info_box("Q: What happens if a scientist misses the deadline?",
        ["A: The Submission Status by Pillar report flags all records still in Draft past "
         "the deadline. Research Admins can view these records directly (sharing rule) and "
         "follow up. A reminder email Flow (not in v1, roadmap item) can be scheduled."], color=TEAL)

    pdf.info_box("Q: How are new scientists added for the next reporting year?",
        ["A: Set Is_Active_Researcher__c = true on their Contact. The scheduled annual "
         "rollover Flow (runs January 1st) automatically creates their blank AAR_Submission__c. "
         "No admin action needed."], color=TEAL)

    pdf.info_box("Q: Can we add Krembil-specific fields in the future?",
        ["A: Yes -- the framework is fully unmanaged. Any additional picklist values, "
         "text fields, or child objects can be added to the existing objects without "
         "touching the core framework. Page layouts are independently configurable per object."],
        color=NAVY)

    pdf.info_box("Q: Are TDC codes visible to the scientist?",
        ["A: No. TDC_Code__c on IP Disclosure, Patent, License, and Startup objects is "
         "hidden from the AAR Scientist profile via Field-Level Security. Only AAR Research "
         "Admin and Institute Leadership profiles can read or write these fields."],
        color=AMBER)

    # -- PAGE -- REQUIREMENTS COVERAGE MATRIX --------------------------------
    pdf.add_page()
    pdf.section_title("SECTION 5 -- REQUIREMENTS COVERAGE MATRIX", level=1)
    pdf.body("This matrix maps each AAR requirement to the demo step that validates it.")

    pdf.two_col_table(
        ["Requirement", "Validated in Demo Step(s)"],
        [
            ("Scientist self-service annual report entry",            "Steps 1-5"),
            ("Automatic form creation each January",                  "Step 1 (rollover Flow)"),
            ("Compliance declarations block premature submission",     "Step 6"),
            ("Submission timestamp auto-populated",                   "Step 7"),
            ("Email notifications on submit and on return",           "Steps 7, 11"),
            ("Two-step approval: Admin then Director",                "Steps 10, 11"),
            ("Pillar-scoped data access for Research Admins",         "Step 8"),
            ("WOS field hidden from scientists (FLS)",                "Steps 4, 9"),
            ("TDC Code fields hidden from scientists (FLS)",          "Section 4 Q&A"),
            ("Rollup summary counters on master record",              "Step 7 (after publication added)"),
            ("Duplicate year prevention",                             "Pre-demo (validation rule)"),
            ("Grant amount validation (received <= total)",            "Pre-demo (validation rule)"),
            ("Peer-reviewed publication requires ePub Date",          "Step 4"),
            ("HQP pipeline data for CIHR/NSERC reporting",           "Steps 5, 13"),
            ("Real-time leadership dashboard",                        "Step 12"),
            ("Submission status report by pillar",                    "Step 13"),
            ("Context fields (leave, circumstances) on layout",       "Step 3"),
            ("Annual rollover creates blank submissions",             "Step 1"),
            ("Sharing rule confines admin to own pillar",             "Step 8"),
            ("FLS on WOS__c restricts to Admin/Leadership",          "Steps 4, 9"),
        ],
        col_w=[100, 74]
    )

    pdf.section_title("Out-of-Scope for Today's Demo (Roadmap)", level=3)
    pdf.two_col_table(
        ["Item", "Priority"],
        [
            ("Rollup Summary fields (requires Lookup -> MasterDetail conversion)", "High -- Phase 2 (next sprint)"),
            ("2-step Approval Process on AAR_Submission__c",  "High -- Phase 2 (next sprint)"),
            ("Custom Profiles: AAR Scientist, Research Admin, Institute Leadership", "High -- Phase 2"),
            ("FLS: hide WOS__c and TDC_Code__c from Scientist profile",  "High -- Phase 2"),
            ("OWD = Private + pillar-based Sharing Rule",    "High -- Phase 2"),
            ("Duplicate Rule: one AAR per scientist per year", "Medium -- Phase 2"),
            ("Reports and Dashboards (4 reports, 2 dashboards)", "Medium -- Phase 2"),
            ("ORCID API auto-populate publications",          "High -- Phase 3"),
            ("MyLearning API auto-confirm training",          "Medium -- Phase 3"),
            ("CMaRS API sync for disclosure status",         "Medium -- Phase 3"),
            ("CIHR / NSERC grant pre-population",            "Low -- Phase 3"),
            ("Submission deadline reminder Flow",             "Medium -- Phase 2"),
            ("Cross-institute AAR framework reuse (PM&R etc.)", "Phase 4+"),
        ],
        col_w=[120, 54]
    )

    # -- FINAL PAGE -- QUICK REFERENCE ----------------------------------------
    pdf.add_page()
    pdf.section_title("SECTION 6 -- QUICK REFERENCE CARD", level=1)
    pdf.body("Keep this visible during the demo as a quick navigation reference.")

    pdf.section_title("Object API Names (copy-paste ready)", level=3)
    pdf.two_col_table(
        ["Label", "API Name"],
        [
            ("AAR Submission",         "AAR_Submission__c"),
            ("AAR Appointment",        "AAR_Appointment__c"),
            ("AAR Grant / Funding",    "AAR_Grant__c"),
            ("AAR Publication",        "AAR_Publication__c"),
            ("Highly Qualified Personnel", "AAR_HQP__c"),
            ("Teaching & Instruction", "AAR_Teaching__c"),
            ("Award & Honour",         "AAR_Award__c"),
            ("Invited Presentation",   "AAR_Presentation__c"),
            ("IP Disclosure",          "AAR_IP_Disclosure__c"),
            ("Patent",                 "AAR_Patent__c"),
            ("Licensing Agreement",    "AAR_License__c"),
            ("Startup Company",        "AAR_Startup__c"),
            ("Outreach & Media",       "AAR_Outreach__c"),
            ("Professional Activity",  "AAR_Professional_Activity__c"),
        ]
    )

    pdf.section_title("Automation Quick Reference", level=3)
    pdf.two_col_table(
        ["Flow / Process Name", "Trigger / Status"],
        [
            ("Flow_AAR_Submission_Trigger",    "ACTIVE -- Status changes to Submitted  (ID: 301Aq000012zVjeIAE)"),
            ("Flow_AAR_Return_Notification",   "ACTIVE -- Status changes to Returned for Revision  (ID: 301Aq000012zVjdIAE)"),
            ("Flow_Annual_AAR_Rollover",       "ACTIVE -- Scheduled daily, fires January 1st  (ID: 301Aq000012znGfIAI)"),
            ("Approval_Process_AAR_Submission","[PHASE 2] 2-step approval: Research Admin then Institute Director"),
        ]
    )

    pdf.section_title("Profiles & Permissions Summary", level=3)
    pdf.two_col_table(
        ["Profile", "Access"],
        [
            ("AAR Scientist",          "Read/Write own records only. WOS and TDC fields hidden."),
            ("AAR Research Admin",     "Read/Write all records in assigned Pillar. Can edit WOS and TDC fields."),
            ("AAR Institute Leadership","Read/Write all records across all Pillars. Full field visibility."),
        ]
    )

    pdf.ln(4)
    pdf.info_box("DEMO SUCCESS CRITERIA",
        ["By end of demo the client should have seen:",
         "  1. A scientist complete and submit a full AAR with child records",
         "  2. Compliance validation blocking premature submission",
         "  3. Admin receiving notification and reviewing the submission",
         "  4. Two-step approval completing and transitioning to Approved",
         "  5. A live dashboard with cross-pillar research metrics",
         "  6. Field-Level Security hiding admin-only fields from scientist view"],
        color=GREEN)

    # -- SECTION 7 -- SANDBOX VALIDATION GUIDE -----------------------------------
    build_interactive_validation_section(pdf)

    pdf.output(OUTPUT)
    print(f"PDF written to: {OUTPUT}")


if __name__ == "__main__":
    build_pdf()
