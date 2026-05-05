# Demo Flow v3 — Single Flow, Standalone Web UI

## The change

**Business context:** EU export control regulations require that every line item on a commercial order specifies the destination region where the product will be shipped. This determines which customs tariff schedule, import duties, and regulatory requirements apply (e.g., bikes shipped to the EU need CE marking compliance documentation, APAC shipments need different battery safety certifications). The region lives on the line item — not the order — because a single wholesale order can contain items going to different warehouses/regions (e.g., 50 units to the EU warehouse, 30 to the US warehouse).

**Admin's request:** "Legal says we need a compliance region on every order line item before we can process it. New EU regulation, non-negotiable. Add a required field with values US, EU, and APAC."

**What gets committed:** One metadata XML file:
`force-app/main/default/objects/Order_Item__c/fields/Compliance_Region__c.field-meta.xml`
- Picklist: US, EU, APAC
- Required: true

No code. No IDE. Five clicks in Salesforce Setup. Pure declarative metadata.

---

## Why this breaks the app (validated 2026-05-03)

The `orderBuilder` LWC creates `Order_Item__c` via `createRecord` with only 3 hardcoded fields:

```js
// orderBuilder.js line 113-118
const fields = {};
fields[ORDER_FIELD.fieldApiName] = this.recordId;      // Order__c
fields[PRODUCT_FIELD.fieldApiName] = product.Id;        // Product__c
fields[PRICE_FIELD.fieldApiName] = Math.round(...);     // Price__c
// Compliance_Region__c is NOT included → createRecord fails
```

Similarly, `OrderItemRestController.createOrderItem` only sets fields present in the request body. Existing API consumers don't send `Compliance_Region__c`.

**Validated on live org:** Adding a required picklist to Order_Item__c and dragging a product onto the order builder produces an error toast. The item is not created.

**Important:** Adding required fields to **Order__c** does NOT break the Lightning "New Order" form — Salesforce standard forms dynamically pick up required fields. The break only works against hardcoded LWC components like `orderBuilder`.

### Test results

| # | Scenario | Type | Expected | Why |
|---|----------|------|----------|-----|
| 1 | Drag product to order builder | E2E/UI | **FAIL** | `createRecord` missing required Compliance_Region__c |
| 2 | Create order item via Apex REST API | Contract/API | **FAIL** | POST body missing Compliance_Region__c → DmlException |
| 3 | Create order item via sObject API | Contract/API | **FAIL** | Same — sObject API enforces required fields |
| 4 | Create order via Apex REST API | Contract/API | PASS | Different object (Order__c), unaffected |
| 5 | Create order via sObject API | Contract/API | PASS | Different object (Order__c), unaffected |
| 6 | Order lifecycle (status transitions) | Integration/API | PASS | Updates existing orders, unaffected |
| 7 | Browse and filter product catalog | E2E/UI | PASS | Different object (Product__c), unrelated |
| 8 | Edit existing order item quantities | E2E/UI | PASS | Update, not create — field already populated |
| 9 | Create support case | E2E/UI | PASS | Different object (Case), unrelated |

**The punchline:** "Legal asked for a required field so you don't violate EU export regulations. The admin added it — five clicks, no code, looks harmless. But now no reseller can add products to orders, the API returns errors, and nobody knows until a reseller calls support."

---

## Web UI flow (4 stages)

### Stage 1 — Change Request
- Centered text input area
- Admin pastes: "Legal says we need a compliance region on every order line item before we can process it. New EU regulation, non-negotiable. Add a required field with values US, EU, and APAC."
- Click "Analyze"

### Stage 2 — Test Plan
- Impact summary: "Change affects Order_Item__c — 2 API endpoints, 1 UI surface, N existing test scenarios"
- Scenario cards (vertical list, toggleable, expandable):
  - Each card: title, type badge (API / E2E / Integration), 1-line description
  - Expanded: numbered steps, editable inline
- Gap detection card highlighted separately (e.g., "What happens to existing order items without a compliance region?")
- Click "Run Tests"

### Stage 3 — Execution
- Same cards with live status spinners resolving to pass/fail
- Progress indicator

### Stage 4 — Results
- Summary banner: "N passed · N failed · N gaps identified"
- Failures expanded by default with details (error messages, screenshots for UI tests)
- Passes collapsed

---

## Test scenarios CSV (`tests/test_scenarios.csv`)

18 NL scenarios covering the full app. No scripts or traces referenced in the CSV — the CSV is purely natural language descriptions that the web UI displays. Test scripts live separately in the repo.

**Order Item flows (EB-TC-001 to 005):** drag-and-drop, multi-product, edit quantities, delete item, verify totals
**Order flows (EB-TC-006 to 007):** status path transitions, create new order via UI
**Product flows (EB-TC-008 to 010):** browse/filter, search, view detail card
**Case flows (EB-TC-011 to 012):** full case submission, minimal fields
**API flows (EB-TC-013 to 018):** order item contract, order contract, sObject variants, lifecycle integration, products GET

### Scripts in the repo (8-9 total)

| Script | Type | Language |
|--------|------|----------|
| `contract_order_items_post.py` | API contract | Python |
| `contract_orders_post.py` | API contract | Python |
| `contract_sobject_order_post.py` | API contract | Python |
| `order_lifecycle_integration_test.py` | API integration | Python |
| `contract_products_get.py` | API contract | Python — **needs creation** |
| `contract_sobject_order_item_post.py` | API contract | Python — **needs creation** |
| `order_with_items_integration_test.py` | API integration | Python — **needs creation** |
| `e2e_product_browse.ts` | E2E | TS/Playwright — **needs creation** |
| `e2e_order_item_drag_drop.ts` | E2E | TS/Playwright — **needs creation** |

### Skyramp selection for the Compliance Region change

Testbot selects ~8 of 18 scenarios. It runs 2-3 existing scripts from the repo AND generates 5-6 new tests from the NL scenarios in the CSV.

**Existing scripts selected and run:**

| Script | Result | Why |
|--------|--------|-----|
| `e2e_order_item_drag_drop.ts` | **FAIL** | Creates Order_Item__c via UI — missing Compliance_Region__c |
| `contract_order_items_post.py` | **FAIL** | Creates Order_Item__c via API — missing required field |
| `contract_sobject_order_item_post.py` | **FAIL** | Creates Order_Item__c via sObject API — same |

**NL scenarios selected and tests generated:**

| CSV Scenario | Result | Why |
|---|---|---|
| EB-TC-002 Add multiple products to same order | **FAIL** | Same createRecord gap as drag-and-drop |
| EB-TC-003 Edit order item quantities | PASS | Updates existing items, field already populated |
| EB-TC-004 Delete order item from order | PASS | Deletes, doesn't create |
| EB-TC-005 Verify order total after item changes | **FAIL** | First step adds an item, which fails |
| EB-TC-006 Transition order status via path | PASS | Order__c, unaffected |

**Skipped (~10 scenarios):**
EB-TC-007 to 012 (Product/Case — unrelated objects), EB-TC-014 to 016 (Order__c API — different object)

**Gap scenario — suggested by Skyramp:**

> "Verify existing order items without Compliance Region can be queried and edited"

When you add a required field, the platform enforces it on **new** records. But existing Order_Item__c records in the database don't have a value for Compliance_Region__c — the field is null. The question is: can you still query, display, and update those records? In most cases yes — Salesforce only enforces required on create/edit of that specific field. But it's a legitimate gap because:

- If a validation rule or trigger references the field, existing records may fail on any update
- If the UI renders the field as required on the edit form, users can't save edits to existing items without first filling in a compliance region they may not know
- Downstream integrations that read Order_Item__c records now get a null field they may not handle

This is the kind of blast-radius question that a human tester often misses — they test the new flow but forget to check what happens to the data that was already there. Skyramp flags it.

**Demo punchline:** Skyramp selected 8 of 18 scenarios, ran 3 existing test scripts and generated 5 new tests from natural language descriptions. 4 tests failed — all because a single required field broke every path that creates an order item. It also identified a gap nobody thought of: what happens to the existing records.

---

## How testbot uses scripts vs. CSV

**Existing scripts in the repo** — testbot identifies which are relevant to the change, selects them, and runs them directly. These are the "regression suite" — tests that were already passing and should keep passing.

**NL scenarios in the CSV** — testbot reads the natural language descriptions, selects the relevant ones, and generates new tests at runtime. These are additive scenarios that don't have pre-written scripts. This showcases Skyramp's ability to go beyond what's already automated.

---

## Field metadata XML

Committed by the web UI backend at runtime to a new branch:

File: `force-app/main/default/objects/Order_Item__c/fields/Compliance_Region__c.field-meta.xml`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Compliance_Region__c</fullName>
    <label>Compliance Region</label>
    <required>true</required>
    <type>Picklist</type>
    <valueSet>
        <restricted>true</restricted>
        <valueSetDefinition>
            <sorted>false</sorted>
            <value><fullName>US</fullName><default>false</default><label>US</label></value>
            <value><fullName>EU</fullName><default>false</default><label>EU</label></value>
            <value><fullName>APAC</fullName><default>false</default><label>APAC</label></value>
        </valueSetDefinition>
    </valueSet>
</CustomField>
```

---

## Build order

1. ~~Validate hypothesis~~ (done 2026-05-03)
2. Create field metadata XML file (ready above, commit when building)
3. Create test scenarios CSV
4. Write missing test scripts (3 Playwright E2E + 1 sObject contract)
5. Build web UI shell (4 stages)
6. Wire up backend (git branch/PR, testbot polling, SSE)
7. End-to-end dry run
8. Capture pre-staged fallback JSON

---

## Open questions

1. **Testbot behavior:** Does testbot select from existing scripts and run them, or generate new ones? This affects what we pre-build vs. what testbot creates at runtime.
2. **Pre-staged fallback:** Capture a real testbot run once and save the JSON. UI can switch to it if live execution fails.
3. **The "Send to Developer" framing:** Is this just a button label, or does the narrative need an explicit handoff moment?
