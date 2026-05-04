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

This is the full suite that Skyramp selects from. For the compliance region change, Skyramp should select scenarios on Order_Item__c (EB-TC-001 through 004) as directly affected, include EB-TC-005 as potentially affected (parent object), and skip the rest as unrelated.

```csv
id,title,type,surface,object,description,steps
EB-TC-001,Add product to order via drag-and-drop,e2e,lightning-ui,Order_Item__c,"Drag a product from sidebar onto order builder, verify item appears with correct price","1. Navigate to Reseller Orders tab; 2. Open existing order; 3. Drag product from sidebar to order builder drop zone; 4. Verify order item tile appears; 5. Verify price is 60% of MSRP"
EB-TC-002,Create order item via Apex REST API,contract,api,Order_Item__c,"POST to /services/apexrest/order-items/ with order ID, product, price, and quantities","1. Create parent order via POST /apexrest/orders/; 2. POST /apexrest/order-items/ with Order__c, Product__c, Price__c, Qty_S__c, Qty_M__c, Qty_L__c; 3. Assert 201 response; 4. Assert returned fields match request"
EB-TC-003,Create order item via sObject API,contract,api,Order_Item__c,"POST to /services/data/v65.0/sobjects/Order_Item__c/ with required fields","1. Create parent order; 2. POST /sobjects/Order_Item__c/ with all fields; 3. Assert 201 and success=true"
EB-TC-004,Edit order item quantities,e2e,lightning-ui,Order_Item__c,"Change S/M/L quantities on an existing order item and save","1. Navigate to order with existing items; 2. Change Qty_S__c value; 3. Click save (checkmark); 4. Verify updated quantity persists"
EB-TC-005,Order lifecycle status transitions,integration,api,Order__c,"Create order then transition Draft → Submitted → Approved, verify each","1. POST /apexrest/orders/ with Draft status; 2. PUT to Submitted to Manufacturing; 3. GET and verify; 4. PUT to Approved by Manufacturing; 5. GET and verify"
EB-TC-006,Create order via Apex REST API,contract,api,Order__c,"POST to /services/apexrest/orders/ with Account and Status","1. POST /apexrest/orders/ with Account__c and Status__c=Draft; 2. Assert 201; 3. Assert returned Id and Status"
EB-TC-007,Create order via sObject API,contract,api,Order__c,"POST to /services/data/v65.0/sobjects/Order__c/","1. POST /sobjects/Order__c/ with Account__c and Status__c; 2. Assert 201 and success=true"
EB-TC-008,Browse and filter product catalog,e2e,community-ui,Product__c,"Navigate to Product Explorer on community site, apply filters, verify results","1. Navigate to /ebikes/s/product-explorer; 2. Type search term; 3. Adjust max price slider; 4. Uncheck a category; 5. Verify product tiles update"
EB-TC-009,Create support case,e2e,community-ui,Case,"Submit a support case on community site","1. Navigate to /ebikes/s/create-case; 2. Fill Product, Priority, Category, Reason, Subject, Description; 3. Click Submit; 4. Verify success toast"
```

### Skyramp selection for this change

| Scenario | Selected? | Reason |
|----------|-----------|--------|
| EB-TC-001 (drag to order builder) | **Yes** | Creates Order_Item__c — directly affected |
| EB-TC-002 (order item Apex API) | **Yes** | Creates Order_Item__c — directly affected |
| EB-TC-003 (order item sObject API) | **Yes** | Creates Order_Item__c — directly affected |
| EB-TC-004 (edit order item) | **Yes** | Modifies Order_Item__c — check for side effects |
| EB-TC-005 (order lifecycle) | **Yes** | Parent object Order__c — potential cascade |
| EB-TC-006 (create order Apex API) | No | Order__c only, no Order_Item__c involvement |
| EB-TC-007 (create order sObject API) | No | Order__c only, no Order_Item__c involvement |
| EB-TC-008 (browse products) | No | Product__c, unrelated |
| EB-TC-009 (create case) | No | Case, unrelated |
| **GAP** (query/edit items without region) | **Suggested** | Skyramp identifies existing records may lack the field |

---

## Test scripts

| CSV ID | Script | Exists? | Notes |
|--------|--------|---------|-------|
| EB-TC-001 | `tests/e2e_order_item_drag_drop.py` | **No** | Playwright — needs creation |
| EB-TC-002 | `tests/contract_order_items_post.py` | **Yes** | Existing, covers this |
| EB-TC-003 | `tests/contract_sobject_order_item_post.py` | **No** | Needs creation (sObject variant) |
| EB-TC-004 | `tests/e2e_order_item_edit.py` | **No** | Playwright — needs creation |
| EB-TC-005 | `tests/order_lifecycle_integration_test.py` | **Yes** | Existing, covers this |
| EB-TC-006 | `tests/contract_orders_post.py` | **Yes** | Existing |
| EB-TC-007 | `tests/contract_sobject_order_post.py` | **Yes** | Existing |
| EB-TC-008 | `tests/e2e_product_browse.py` | **No** | Playwright — needs creation |
| EB-TC-009 | `tests/e2e_create_case.py` | **No** | Playwright — needs creation |

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
