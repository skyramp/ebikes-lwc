# Skyramp Live Demo — Proposed Flow (v2)

**Purpose:** Proposed demo flow for the Skyramp + Antigravity live demo against the Salesforce E-Bikes sample app. Two flows showing two Skyramp modes, two personas, one app.

---

## 1. Context

**Company:** Skyramp — MCP server + PR testbot that generates, maintains, and executes functional tests across API and UI surfaces.

**Demo environment:** Skyramp running inside Antigravity (Google's IDE). Two Skyramp modes are shown:
- **Skyramp MCP (Flow 1 — shown first, live):** Admin interacts with Skyramp via chat. Skyramp selects relevant test scenarios from a pre-existing CSV spreadsheet based on the change, generates UI tests, and runs them. Conversational workflow — the admin doesn't write or read code.
- **Skyramp Testbot (Flow 2 — shown second, pre-staged):** Developer opened a PR earlier. Skyramp Testbot triggered automatically — analyzed the diff, maintained existing tests that cover the changed code, generated new tests where coverage gaps existed (using traces in the repo), ran everything, and posted results as a PR comment distinguishing maintained vs. newly generated tests.

Antigravity is the IDE environment; Skyramp is the test generation/execution layer.

**Audience:** Directors at Google. Live demo, no fixed time constraint, target ~10 minutes.

**App under test:** Salesforce E-Bikes sample app (`ebikes-lwc`). Fictional electric bike retailer with two main surfaces:

### App surfaces (verified against deployed org)

**Experience Cloud Community Site** (public-facing, guest-accessible):
`https://playful-bear-m8hbtf-dev-ed.trailblaze.my.site.com/ebikes/s/`

| Page | URL path | Components | What it does |
|---|---|---|---|
| Home | `/ebikes/s/` | Two `c:hero` banners | Hero video (Dynamo X2) + hero image (Electra Series) with CTA buttons |
| Product Explorer | `/ebikes/s/product-explorer` | `c:productFilter` + `c:productTileList` + `c:productCard` | Browse/filter 16 e-bikes by category, material, level, max price |
| Product Detail | `/ebikes/s/product/{recordId}` | Standard record headline + tabs | Full product record |
| Create Case | `/ebikes/s/create-case` | `c:createCase` | Support case form: Product, Priority, Category, Reason, Subject, Description |
| Cases | `/ebikes/s/cases` | Standard list | Customer's submitted cases |

**Lightning App** (internal users — reseller operations):
`https://playful-bear-m8hbtf-dev-ed.trailblaze.lightning.force.com`

| Tab | Components | What it does |
|---|---|---|
| Product Explorer | Same `productFilter` + `productTileList` + `productCard` | Same as community but in Lightning context |
| Reseller Orders | `c:orderStatusPath` + field section (Account, Status) + `c:orderBuilder` with `c:productTileList` sidebar | **Status pipeline:** clickable path (Draft → Submitted to Manufacturing → Approved by Manufacturing → In Production). **Order builder:** drag products from sidebar to create Order_Item__c records. |
| Products (record page) | Highlights panel + Related/Details tabs + `c:similarProducts` sidebar | Product record. Related tab currently shows "No related lists to display." |
| Accounts, Contacts, Product Families | Standard record pages | Standard Salesforce CRUD |

**REST API endpoints** (Apex REST controllers in the repo):

| Endpoint | Controller | Methods |
|---|---|---|
| `/services/apexrest/orders/*` | `OrderRestController.cls` | GET, POST, PUT, DELETE |
| `/services/apexrest/order-items/*` | `OrderItemRestController.cls` | GET, POST, PUT, DELETE |
| `/services/apexrest/products/*` | `ProductRestController.cls` | GET, POST, PUT, DELETE |

**Existing test coverage:**

| Type | Files |
|---|---|
| Apex unit tests | `TestProductController.cls`, `TestOrderController.cls` |
| LWC Jest tests | 12 test files under `lwc/*/__tests__/` |
| Skyramp contract tests | `tests/contract_orders_post.py`, `tests/contract_order_items_post.py` |
| Skyramp integration test | `tests/order_lifecycle_integration_test.py` |
| UTAM E2E | `force-app/test/utam/page-explorer.spec.js` |

---

## 2. Demo goals (what directors must walk away believing)

1. Skyramp **selects the right tests** for a given change — not 100 generic tests, the specific scenarios that matter (shown in both flows).
2. Skyramp closes the gap where **admins can't test** their own changes — they don't know what to test or how. Skyramp gives them systematic, targeted coverage from a test scenario spreadsheet (Flow 1).
3. Skyramp **maintains existing tests and generates new ones** where coverage gaps exist — the full test lifecycle, automated on PR (Flow 2).
4. Skyramp **catches bugs manual QA misses** — a cross-UI wiring bug the AI introduced that visual inspection wouldn't find, caught by a newly generated test (Flow 2).
5. Skyramp works in **two modes** — conversational in the IDE (MCP) and automated on PR (Testbot) — fitting how admins and developers actually work.

---

## 3. Demo structure

Two flows. Flow 1 is live. Flow 2 is pre-staged.

| Block | Duration | Content |
|---|---|---|
| Open | 0:30 | Show the Lightning app — Order Record Page, Product Explorer. Frame: "This is a Salesforce e-commerce app. Two personas work on it." |
| Flow 1: Admin + MCP (LIVE) | 5:00 | Admin adds required Shipping Region to orders via Salesforce Setup. Asks Skyramp MCP to validate. Skyramp selects relevant scenarios from the CSV, generates UI tests, runs them. All pass. |
| Bridge | 0:30 | "Same app, different persona — now the developer made a code change that spans both UIs." |
| Flow 2: Developer + Testbot (PRE-STAGED) | 3:30 | Walk through a PR that was opened earlier. Testbot maintained existing tests, generated a new cross-UI test, ran everything. PR comment shows one newly generated test caught a wiring bug. |
| Close | 0:30 | Landing line |

---

## 4. FLOW 1 — Admin + Skyramp MCP: Required Shipping Region on Orders (LIVE)

### 4.1 Narrative

**Business context:** E-Bikes has been shipping all orders from a single warehouse in California. The business is expanding to multi-warehouse fulfillment — East (New Jersey), West (California), and Central (Texas). To route orders correctly, the operations team needs every reseller order tagged with a Shipping Region. Without it, the warehouse team doesn't know which facility should fulfill the order, and the logistics partner can't generate shipping labels.

**The admin's task:** Add a required Shipping Region picklist to the Reseller Order object. Standard Salesforce admin work — five clicks in Object Manager, no code.

**The hidden risk:** The org already has existing orders that were created before Shipping Region existed. Those orders have a blank Shipping Region. When someone tries to edit one of those old orders — change the Account, advance the status, add a line item — the required field validation fires and blocks the save. The user can't update the order without filling in a field they didn't know was added. The admin would never think to test this because they're focused on *new* orders. They'd check that new orders require the field, see it works, and ship it. Monday morning, the reseller ops team can't update any existing orders.

**Today's testing approach:** The admin clicks around, verifies the field shows up on the page layout, creates one test order, and hopes nothing else broke. They don't know which user flows might be affected, which edge cases to check, or whether existing functionality still works.

**Skyramp closes this gap.** The admin's team has a CSV spreadsheet of 21 test scenarios covering the app's key user flows. After making the change, the admin asks Skyramp MCP to validate it. Skyramp reads the change, selects the relevant scenarios from the spreadsheet, generates executable test scripts, and runs them. But Skyramp also identifies a **missing scenario** — editing a pre-existing order without the new required field — and generates a new test for it. Systematic coverage plus gap detection, no code knowledge required.

### 4.2 The test scenario spreadsheet

**Repo:** A separate, clean repo containing only a README and a CSV file.

See full CSV at `ebikes-admin-tests/test_scenarios.csv`. 21 scenarios across 9 feature areas, with columns: ID, Feature Area, Test Type, Scenario, Preconditions, Steps, Expected Result, Priority (P0-P3), Automated, Owner, Last Executed.

**Order-related scenarios (EB-TC-001 to EB-TC-007):** Order creation (happy path + validation), status pipeline, record page fields, inline editing, order builder.

**Non-order scenarios (EB-TC-008 to EB-TC-021):** Product Explorer filtering, product record pages, community Create Case, community navigation, community home, auth/login.

When the admin adds a required Shipping Region field to orders, Skyramp should select the 5 scenarios that involve writing to or validating fields on `Order__c` (EB-TC-001, 002, 003, 004, 005) and skip the 16 unrelated ones — including the order builder scenarios (EB-TC-006, 007) which operate on `Order_Item__c`, not `Order__c`. Skyramp should also identify a **missing scenario** (editing a pre-existing order without Shipping Region) and generate it. That gives 5 selected + 1 generated = 6 total.

### 4.3 The change (admin does this live in Salesforce Setup)

**Step-by-step instructions for the admin during the demo:**

1. Open Salesforce Setup: click the gear icon (top right) → **Setup**
2. In Quick Find, type **Object Manager** → click **Object Manager**
3. Find and click **Reseller Order** (API name: `Order__c`)
4. Click **Fields & Relationships** in the left sidebar
5. Click **New** (top right)
6. Select **Picklist** → click **Next**
7. Field Label: **Shipping Region**
8. Values (enter each on a new line):
   - East
   - West
   - Central
9. Check **Use first value as default value** (optional)
10. Click **Next**
11. On the field-level security screen, check **Required** (or leave as-is and set required via validation rule)
12. Click **Next** → **Save**

The field is now live on `Order__c`. This change will be captured as metadata in the repo (field XML file) when pushed.

**What gets pushed to repo:**
`force-app/main/default/objects/Order__c/fields/Shipping_Region__c.field-meta.xml`

**How to revert (if you need to re-demo or reset):**

1. Open Salesforce Setup: gear icon → **Setup**
2. Quick Find → **Object Manager** → click **Object Manager**
3. Find and click **Reseller Order** (`Order__c`)
4. Click **Fields & Relationships**
5. Find **Shipping Region** in the list
6. Click the dropdown arrow (far right of the row) → **Delete**
7. Salesforce will warn about data loss — confirm deletion
8. The field is removed from the org immediately

Note: if any Order records were created with a Shipping Region value during the demo, deleting the field will permanently remove that data from those records. This is fine for demo purposes.

### 4.4 Prompt to paste into Antigravity chat (copy-paste ready)

```
I just implemented the following change request in Salesforce Setup. Please validate it with Skyramp by selecting and running the relevant test scenarios.

Title: Add Shipping Region to Reseller Orders
Requested by: Operations (Warehouse Team)
Priority: P1

Description:
We are expanding to multi-warehouse fulfillment across three regions: East (New Jersey), West (California), and Central (Texas). Every reseller order needs to be tagged with a Shipping Region so the warehouse team can route fulfillment to the correct facility and the logistics partner can generate the right shipping labels.

Changes made:
- Added a new required picklist field "Shipping Region" to the Reseller Order object (Order__c)
- Picklist values: East, West, Central
- Field is required — orders cannot be saved without a region
- Field is visible on the Order record page layout

Acceptance criteria:
- New orders require Shipping Region before save
- Shipping Region is visible on the Order record page
- Existing order workflows (status pipeline, order builder) continue to function
```

### 4.5 Expected MCP response

After the admin pastes the prompt, Skyramp MCP responds with test selection and gap analysis:
> I've analyzed your change — a new required picklist field `Shipping_Region__c` on `Order__c`. Here's my plan:
>
> **Selected from existing scenarios (5):**
> - EB-TC-001: Create new reseller order with all required fields *(now includes Shipping Region)*
> - EB-TC-002: Create order with missing required fields *(validates Shipping Region enforcement)*
> - EB-TC-003: Advance order through status pipeline *(verify new field doesn't interfere with status transitions)*
> - EB-TC-004: View order record page — all fields and sections display *(Shipping Region should be visible)*
> - EB-TC-005: Edit order — update a field and save *(verify required field doesn't block unrelated edits)*
>
> **Coverage gap identified — generating new scenario:**
> - **NEW: Edit pre-existing order without Shipping Region** — Orders created before this field was added have a blank Shipping Region. When a user tries to edit one of these orders (e.g., change Account or advance status), the required field validation will block the save. This scenario verifies the user is prompted to fill in Shipping Region and can successfully save after providing a value.
>
> **Skipped (16 scenarios):**
> - EB-TC-006, EB-TC-007: Order Builder scenarios — these operate on `Order_Item__c` (line items), not on the `Order__c` record itself. Adding a field to `Order__c` doesn't affect drag-and-drop or line item creation.
> - EB-TC-008 through EB-TC-021: Product Explorer, Product Record, Community, and Auth scenarios are not affected by a field change on `Order__c`.
>
> Shall I generate UI tests and run them?

**Admin:** *"Yes, go ahead."*

Skyramp generates UI tests from the selected scenarios and runs them.

### 4.6 Test results

All 6 UI tests pass (5 from spreadsheet + 1 newly generated). Skyramp reports:

> **6/6 UI tests passed.**
>
> **From existing scenarios (5):**
> - EB-TC-001: Create order with Shipping Region = "East" — field visible on record page ✓
> - EB-TC-002: Save without Shipping Region blocked — validation error displayed ✓
> - EB-TC-003: Status advanced Draft → Submitted to Manufacturing with Shipping Region set ✓
> - EB-TC-004: Record page shows Account, Status, and Shipping Region fields ✓
> - EB-TC-005: Inline edit saves without validation errors on unrelated fields ✓
>
> **Newly generated (1):**
> - NEW: Edit pre-existing order without Shipping Region — user prompted to fill field, saves successfully after providing value ✓

The change is clean — but only because Salesforce handles required fields gracefully on edit (it prompts the user). The point: **the admin would never have tested this.** They were thinking about new orders. Skyramp identified the gap, generated the test, and validated it. The admin now knows: existing orders will prompt users to fill in Shipping Region on next edit, and that flow works correctly.

Skyramp selected 5 out of 21 existing scenarios, generated 1 new one, and validated every user flow that touches `Order__c`.

### 4.7 Demo beats

| Beat | What happens | Duration |
|---|---|---|
| 1 | Show the Lightning Order Record Page: point out Account, Status fields, Order Builder sidebar, status pipeline. "This is how the internal team manages reseller orders. They're expanding to multi-warehouse — East, West, Central — and need every order tagged with a Shipping Region so the warehouse team knows where to route it." | 0:25 |
| 2 | Frame: "Standard admin task — add a required picklist in Salesforce Setup. The problem: after making this change, the admin has no way to systematically test it. They check the field shows up, create one test order, and hope nothing broke. They're not thinking about the hundreds of existing orders that don't have this field yet." | 0:20 |
| 3 | Show the CSV spreadsheet briefly: "The team maintains a spreadsheet of 21 test scenarios across the app — orders, product explorer, community site. Today no one runs them systematically." | 0:15 |
| 4 | Admin goes into Salesforce Setup. Adds the Shipping Region picklist to Reseller Orders. (Follow steps in 4.3.) | 0:45 |
| 5 | Admin pastes the change request into Skyramp MCP: "I just implemented this change request. Please validate it with Skyramp." The ticket includes the business context (multi-warehouse, three regions), the specific changes made, and acceptance criteria. | 0:15 |
| 6 | Skyramp responds with test selection: 5 of 21 scenarios selected, 16 skipped. **Pause — first key moment.** "Skyramp read the change, read the spreadsheet, and selected the 5 scenarios that touch `Order__c`. It skipped the order builder tests — those operate on line items, different object — plus product explorer, community, and auth. Not affected." | 0:30 |
| 7 | Point to the coverage gap: **"Skyramp also identified a missing scenario — editing a pre-existing order that doesn't have Shipping Region. This wasn't in the spreadsheet. Skyramp generated it."** This is the second key moment. "The admin was thinking about new orders. Skyramp thought about the old ones." | 0:30 |
| 8 | Admin says "go ahead." Skyramp generates UI tests and runs all 6 (5 selected + 1 generated). All green. Walk through a few results — including the generated test. | 0:45 |
| 9 | "The admin made a change in Setup. Skyramp picked the right scenarios, generated UI tests, found a gap no one had thought of, and confirmed everything works. No developer. No guesswork." | 0:15 |

---

## 5. FLOW 2 — Developer + Skyramp Testbot: Product-to-Case Linking (PRE-STAGED)

### 5.1 Narrative

The E-Bikes app has a gap: the community site lets customers browse products and separately file support cases, but the two aren't connected. When a customer has an issue with their Dynamo X2, they have to manually search for the product in the case form. The internal team looking at a product in Lightning can't see what cases customers have filed for it.

A developer used Antigravity to generate a fix: wire the community "Create Case" form to auto-link to the product the customer was viewing, and surface customer cases on each product's record page in Lightning. The developer opened a PR. Skyramp Testbot triggered automatically — it analyzed the diff, found existing tests that cover the changed code and maintained them, identified coverage gaps and generated new tests (using traces in the repo as a foundation), then ran everything and posted results.

**This flow is pre-staged.** The PR is already open with Testbot results posted. Walk through the PR comment and test files.

### 5.2 The change (already in the PR)

**Prompt that was given to Antigravity:**
> "The Create Case form on the community site is missing the Product and Category fields — deploy them so the form works fully. Then wire it up so when a customer navigates from a product page to Create Case, the product is automatically pre-filled. Finally, add the Cases related list to the Product Record Page in Lightning so the internal team can see customer-reported issues per product."

**Files modified in the PR:**

1. **`force-app/main/default/lwc/createCase/createCase.js`** — Added `@wire(CurrentPageReference)` to read the product ID from the URL. Intended to pre-fill the Product field.

2. **`force-app/main/default/lwc/createCase/createCase.html`** — Template update for pre-filled product value.

3. **`force-app/main/default/flexipages/Product_Record_Page.flexipage-meta.xml`** — Added Cases related list to the Related tab.

4. **Field deployment** — `Product__c` and `Case_Category__c` on Case (already in repo metadata) deploy with this PR.

### 5.3 The planted bug

The AI added the `CurrentPageReference` wire to read the product ID from the URL, but **didn't actually bind it to the form field**. The Product field renders (custom field is now deployed) but it's always empty — even when the customer navigated from a specific product page.

Plausible AI mistake: focused on deploying fields and adding navigation code, missed the last step of piping the value into the form. The form *looks* right — all fields visible — but the pre-fill is broken.

**Result:** Cases are created without a product link. The Lightning Product Record Page Related tab stays empty.

### 5.4 How to revert (if you need to reset the org)

The Testbot deployment pushes code and metadata changes to the org. To revert:

**Code revert (CLI):**
```bash
# Redeploy the original createCase LWC and Product Record Page from main branch
sf project deploy start \
  --source-dir force-app/main/default/lwc/createCase \
  --source-dir force-app/main/default/flexipages/Product_Record_Page.flexipage-meta.xml \
  --target-org testauth
```
This overwrites the buggy LWC and modified flexipage with the originals from the main branch.

**Case custom fields (Salesforce Setup):**
The deploy also pushes `Product__c` and `Case_Category__c` on Case. These can't be "undeployed" via CLI. To remove them:

1. Setup → Object Manager → **Case** → Fields & Relationships
2. Find **Product** (`Product__c`) → dropdown arrow → **Delete** → confirm
3. Find **Case Category** (`Case_Category__c`) → dropdown arrow → **Delete** → confirm

Note: deleting these fields will remove data from any Cases created with them. Fine for demo purposes.

Alternatively, leave the Case fields deployed — they don't affect Flow 1 (different object) and the Create Case form showing extra fields is harmless since Flow 2 doesn't rely on a "before" state.

### 5.5 What Testbot does with this diff

Testbot analyzes the diff (touches `createCase` LWC, `Product_Record_Page` flexipage, deploys Case custom fields) and takes three actions:

**Maintained (existing tests updated for the change):**
- API — Create Case with Product link (POST with `Product__c`) — existing test, updated to include the newly deployed Product field
- API — Query Cases by Product — existing test, maintained as-is
- API — Create Case without Product (backward compat) — existing test, maintained as-is
- API — Invalid Product reference (referential integrity) — existing test, maintained as-is
- Community — Create Case without product context — existing test, maintained as-is
- Community — Submit case with all fields — existing test, updated to include Product and Category fields
- Lightning — Cases related list on Product Record Page — existing test, updated to verify newly added related list

**Newly generated (coverage gaps filled):**
- **Community — Create Case with product context** — no existing test covered the product pre-fill flow. Testbot generated this from a trace in the repo. It navigates from a product on the community site → Create Case → asserts the Product field is pre-filled → submits → switches to Lightning → opens the Product Record Page → checks the Related tab. One test, both UIs.

**Skipped:**
- Order-related tests, Product Explorer tests, and other scripts not affected by this diff.

The newly generated cross-UI test is the headline — and it's the one that catches the planted bug.

### 5.6 What the PR comment shows

Testbot posted results to the PR:

> **8 tests run. 7 passed. 1 failed.**
>
> **Maintained (7 existing tests):**
> ✓ API — Create Case with Product link (201)
> ✓ API — Query Cases by Product
> ✓ API — Create Case without Product (backward compat)
> ✓ API — Invalid Product reference (referential integrity)
> ✓ Community — Create Case without product context
> ✓ Community — Submit case with all fields
> ✓ Lightning — Cases related list visible on Product Record Page
>
> **Newly generated (1 test):**
> ✗ **Community — Create Case with product context**
> `Expected Product field to be pre-filled with "Dynamo X2". Actual: field is empty.`
>
> *Skipped N tests not affected by this diff (order builder, product explorer, status pipeline, etc.)*

The maintained tests all pass — the backend data model is fine, the existing flows still work. The newly generated cross-UI test caught the bug: the AI added navigation code but didn't bind the product ID to the form field.

### 5.7 Demo beats

| Beat | What happens | Duration |
|---|---|---|
| 1 | Frame: "Now the developer persona. A developer used Antigravity to generate a feature that spans both UIs — the community site and Lightning. They opened a PR. Skyramp Testbot triggered automatically." Briefly describe the feature: "Link products to support cases on the community site, and surface those cases on the product record page in Lightning." | 0:20 |
| 2 | Open the PR. Show the diff briefly — LWC changes, flexipage update, field deployment. "Small change, but it spans both UIs." | 0:20 |
| 3 | Show the Testbot comment. Point out the two sections: "7 maintained tests — Testbot found existing tests that cover Case creation and the Product Record Page, updated them for the new fields, and ran them. All passed." | 0:30 |
| 4 | Point to the newly generated test: "Testbot also identified a coverage gap — no existing test covered the product-to-case pre-fill flow. So it generated a new cross-UI test from a trace in the repo. One test: community product → Create Case → assert pre-fill → submit → switch to Lightning → check Related tab. **That test failed.**" | 0:40 |
| 5 | Highlight the failure message: `Expected Product field pre-filled with "Dynamo X2". Actual: empty.` "The AI added the navigation code but didn't bind it to the form field. The maintained tests couldn't catch this — they test existing flows. The newly generated test did." | 0:30 |
| 6 | Walk through one or two test files briefly: "Here's the API contract test — maintained, updated for the Product field. Here's the cross-UI Playwright test — newly generated, one test, both UIs." | 0:30 |
| 7 | "Testbot ran on PR open. It maintained 7 existing tests, generated 1 new one, and the new one caught the bug. Maintain, generate, run — all automatic." | 0:15 |

---

## 6. Why this pairing works

- **Both flows show selection + generation.** Flow 1 selects from a spreadsheet and generates UI tests (including a missing scenario). Flow 2 maintains existing tests and generates a new cross-UI test. Same Skyramp capabilities, two product surfaces.
- **Flow 1 is the admin's pain point.** The customer's current gap: admins make changes and can't systematically test them. Skyramp reads the spreadsheet, selects the right scenarios, generates UI tests, identifies a gap the admin never thought of (existing orders without the new field), and runs everything. Direct answer to the customer's problem.
- **Flow 2 shows the full Testbot lifecycle.** Maintain existing tests for the change, generate new tests where gaps exist, run everything. The maintained tests confirm nothing broke. The newly generated test catches a bug that didn't have coverage before.
- **Two Skyramp modes, two personas.** MCP (conversational) fits the admin who needs guidance. Testbot (automated on PR) fits the developer workflow. The audience sees both product surfaces.
- **Flow 1 is live, Flow 2 is pre-staged.** The live flow (admin + MCP) is lower risk — it's a conversation with clear, controlled steps. The pre-staged flow (developer + Testbot) avoids waiting for Antigravity/Testbot to run live.
- **Both changes are real business features.** Adding shipping regions and linking cases to products are exactly the kind of work that happens in production orgs.
- **The narrative escalates.** Flow 1: "Skyramp picks the right scenarios, generates UI tests, finds a gap, and confirms the change is safe." Flow 2: "Skyramp maintains existing tests, generates a new cross-UI test, and catches a bug." Both flows show selection + generation. The demo builds from validation to bug-catching.

---

## 7. Pre-staging requirements

### Flow 1 (Admin + MCP — live)

1. **Scratch org deployed** (`playful-bear-m8hbtf-dev-ed`) with sample data and Experience Cloud site published
2. **Lightning app accessible** with at least one Order__c record (status "Draft", some Order_Item__c attached). Create via Order Builder UI during pre-staging.
3. **Shipping Region field does NOT exist** on `Order__c` before the demo — admin adds it live
4. **Separate clean repo** with only a README and `test_scenarios.csv`
5. **Skyramp MCP connected** to Antigravity, authenticated against the clean repo + scratch org
6. **Rehearse:** Skyramp selects the correct 5 of 21 scenarios consistently, generates the missing pre-existing order scenario, and all 6 tests pass consistently after the field is added.

### Flow 2 (Developer + Testbot — pre-staged)

7. **PR open** on the ebikes-lwc repo with the product-to-case linking change (including the planted bug). Note: the Testbot deployment will push the changes to the org — the Case custom fields (Product, Category) and Product Record Page layout will be live. This is fine: the Flow 2 walkthrough focuses on the PR comment and test files, not on showing a "before" state in the live org.
8. **Testbot results posted** on the PR — 7/8 passed, cross-UI test failed with readable error
9. **Test files committed** in the PR branch — API contract tests, community UI tests, cross-UI end-to-end test, Lightning UI test

### Cross-flow impact

10. **Flow 1 → Flow 2:** Flow 1 adds a required Shipping Region field to `Order__c`. Flow 2 touches `Case` and `Product__c` — completely different objects. **No impact.** You can proceed to Flow 2 without reverting.
11. **Flow 2 → Flow 1:** Flow 2's Testbot deployment pushes Case custom fields and Product Record Page layout changes to the org. These are on `Case`/`Product__c`, not `Order__c`. **No impact on Flow 1.** The admin's Shipping Region field addition and the order-related test scenarios are completely unaffected.
12. **Re-running Flow 1:** If you need to re-demo, revert the Shipping Region field via Salesforce Setup (see revert instructions in Section 4.3).

### General

12. **Recorded fallback** of each flow's key moments as a 30-second cutaway if anything stalls live
13. **Pre-composed prompts** rehearsed to produce consistent output. See Sections 4.4 and 5.2.

---

## 8. Open questions

1. **Flow 1 — field-level required vs. validation rule:** Making the field required at the field level (step 11 in Setup) will block all DML inserts without the field — including REST API calls and Apex test fixtures. Making it required via a validation rule scoped to UI edits only would avoid backend breakage. For the demo, field-level required is simpler and the change is clean from the UI perspective. Decide which approach.
2. **Flow 1 — pushing the change:** After adding the field in Setup, how does the metadata get into the repo for Skyramp to analyze? Options: (a) `sf project retrieve start` to pull metadata, commit, push, (b) pre-stage the field XML and just deploy it live. Decide during rehearsal.
3. **Flow 2 — navigation mechanism:** How does the customer navigate from a product page to Create Case with product context? Options: (a) add a "Report Issue" button that passes `c__productId` in URL, (b) modify "Create Case" nav to accept URL params. Decide during implementation.
4. **Flow 2 — pre-fill implementation:** The `createCase` LWC uses `lightning-record-edit-form` with `lightning-input-field`. Setting a default value on a lookup field requires specific handling. Test the exact mechanism before creating the PR.
5. **Status picklist values:** Org has: Draft, Submitted to Manufacturing, Approved by Manufacturing, In Production. Confirm acceptable for demo or add simpler values.

---

## 9. Deliverables for implementation

1. **`test_scenarios.csv`** — the 21-scenario spreadsheet for the clean repo (see Section 4.2)
2. **Clean repo** with README + CSV, Skyramp MCP configured
3. **Pre-existing test scripts in ebikes-lwc repo** — API contract tests (pytest), community UI tests, Lightning UI tests. These must exist on the main branch *before* the PR is opened so Testbot can maintain them. Also include a trace for the cross-UI product-to-case flow so Testbot can generate the new test from it.
4. **LWC diffs** for `createCase.js` and `createCase.html` — buggy version for the PR branch
5. **Flexipage diff** for `Product_Record_Page.flexipage-meta.xml` — add Cases related list (PR branch)
6. **Pre-staged PR** on ebikes-lwc with the planted bug and Testbot results posted (showing maintained tests, newly generated test, and the failure)
7. **Rehearsal checklist** confirming all pre-staging items are met

---

## 10. Closing line

> "The admin added a required field in Salesforce Setup. Skyramp picked 5 scenarios from a 21-scenario spreadsheet, found a gap no one had thought of — what happens to existing orders — generated UI tests, and confirmed everything works. Six tests, all green, no developer needed. The developer opened a PR with AI-generated code. Skyramp maintained 7 existing tests, generated a new cross-UI test, and caught a wiring bug. Two personas, two modes. Skyramp selects, generates, and runs — either it catches the problem or it tells you it's safe to go."
