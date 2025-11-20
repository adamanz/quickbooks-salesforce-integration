# QuickBooks Estimate Flow Integration Guide

## Overview
You now have a complete invocable action to create QuickBooks Estimates from Salesforce with **multiple line items** and **discount support**.

---

## How It Works

### 1. **Invocable Method**
```apex
@InvocableMethod(label='Create QuickBooks Estimate'
                 description='Creates an estimate in QuickBooks with multiple line items'
                 category='QuickBooks Integration')
public static List<EstimateResponse> createEstimate(List<EstimateRequest> requests)
```

### 2. **Request Parameters** (EstimateRequest)

#### Required:
- **opportunityId** (Text): The Salesforce Opportunity ID
- **companyId** (Text): QuickBooks Company/Realm ID

#### Optional (but powerful):
- **lineItems** (Collection): Custom line items to add to estimate
  - Each item needs:
    - description (required)
    - quantity (required)
    - unitPrice (required)
    - amount (required)
    - quickBooksItemId (optional - QB Item ID)

- **discountAmount** (Currency): Discount amount to apply
- **applyTaxAfterDiscount** (Boolean): Apply tax after discount (default: true)
- **estimateDate** (Date): Estimate date (default: today)
- **expirationDate** (Date): When estimate expires (default: 30 days)
- **referenceNumber** (Text): Custom estimate number
- **customerMemo** (Text): Customer-visible memo
- **privateMemo** (Text): Internal memo (not shown to customer)
- **shipToAddress** (Text): Shipping address

### 3. **Response Data** (EstimateResponse)

Returns:
- **success** (Boolean): True if successful
- **message** (String): Status/error message
- **quickBooksEstimateId** (Text): QB Estimate ID
- **quickBooksEstimateNumber** (Text): QB Estimate Number
- **salesforceOpportunityId** (Text): Original Opportunity ID

---

## How to Use in Flow Builder

### Step 1: Create an Apex-Defined Variable for Line Items

In Flow Builder, create a variable of type `Apex Defined`:
```
Type: com.example.QuickBooksAPIService$EstimateLineItem
Collection: Yes (allows multiple items)
```

### Step 2: Build Line Items (Loop Through OpportunityLineItems)

Add a **Loop** element:
- Collection: Opportunity.OpportunityLineItems
- Create an **Assign** element inside the loop:

```
Assign EstimateLineItem Properties:
- description = {!Current_OLI.Product2.Name}
- quantity = {!Current_OLI.Quantity}
- unitPrice = {!Current_OLI.UnitPrice}
- amount = {!Current_OLI.TotalPrice}
- quickBooksItemId = {!Current_OLI.Product2.QuickBooks_Item_Id__c}

Add to collection: {!Line_Items_Collection}
```

### Step 3: Create EstimateRequest Variable

```
Variable Type: Apex Defined
Type: com.example.QuickBooksAPIService$EstimateRequest
```

### Step 4: Build the Request in an Assignment Element

```
Set Request Properties:
- opportunityId = {!recordId}
- companyId = "YOUR_COMPANY_ID" (or use a variable)
- lineItems = {!Line_Items_Collection}
- discountAmount = {!Discount_Amount}
- applyTaxAfterDiscount = true
- estimateDate = {!TODAY()}
- expirationDate = {!TODAY() + 30}  # or {!Expiration_Date}
- customerMemo = "Thank you for your business"
```

### Step 5: Call the Invocable Method

Add an **Action** element:
- Search for: "Create QuickBooks Estimate"
- Select: `QuickBooksAPIService.createEstimate`

**Input:**
```
Estimate Request = {!EstimateRequest}
```

**Output Assignments:**
```
Store Result in Variable: {!EstimateResult}
```

### Step 6: Handle Success/Failure

Add a **Decision** element:
```
Condition: {!EstimateResult.success} equals true

True Path: Proceed to Send Email (Optional) or Show Success
False Path: Show error message - {!EstimateResult.message}
```

### Step 7: Send Estimate via Email (Optional)

To email the estimate immediately after creation:

1. Add another **Action** element after the "Create QuickBooks Estimate" step (on the Success path).
2. Search for: "Send QuickBooks Estimate"
3. Select: `QuickBooksEstimateSendInvocable.sendEstimate`
4. **Input:**
   - Company ID: `{!Company_ID}` (or your constant)
   - QuickBooks Estimate ID: `{!EstimateResult.quickBooksEstimateId}`
   - Email Address: `{!Customer_Email}` (optional - overrides customer's default email)

---

## Example Flow XML (Simplified)

Here's what the invocable action call looks like in XML:

```xml
<actionCalls>
    <name>Create_QB_Estimate</name>
    <label>Create QuickBooks Estimate</label>
    <locationX>400</locationX>
    <locationY>500</locationY>
    <actionName>QuickBooksAPIService.createEstimate</actionName>
    <actionType>apex</actionType>
    <inputParameters>
        <name>requests</name>
        <value>
            <elementReference>EstimateRequest</elementReference>
        </value>
    </inputParameters>
    <outputParameters>
        <name>result</name>
        <assignToReference>EstimateResult</assignToReference>
    </outputParameters>
</actionCalls>
```

---

## Real-World Example: Your OXYCELL Estimate

For the estimate in your PDF (`Estimate 0000006.pdf`), the Flow would:

### Build Line Items Loop:
```
1. Oxycell OxyPro Ultra 6500
   - Qty: 1
   - Unit Price: $78,900.00
   - Amount: $78,900.00

2. Power Chair Upgrade
   - Qty: 2  (you had 1 in PDF, but could be 2)
   - Unit Price: $1,799.00
   - Amount: $3,598.00

3. Starry Roof Liner
   - Qty: 1
   - Unit Price: $2,400.00
   - Amount: $2,400.00

... (continue for all 9 items)
```

### Set Discount:
```
discountAmount = 15092.00
applyTaxAfterDiscount = true
```

### Result:
```
QB Estimate created with ID: djQuMTo5MTMwMzU1...
QB Estimate Number: 0000006
Success: true
```

---

## Key Features

✅ **Multiple Line Items** - Add as many items as needed from Flow
✅ **Discount Support** - Single discount amount applied to entire estimate
✅ **Flexible Dates** - Custom estimate and expiration dates
✅ **Auto-Customer Creation** - Creates QB customer if not already synced
✅ **Error Handling** - Returns detailed error messages on failure
✅ **Logging** - Logs errors to Integration_Log__c for debugging

---

## How Line Items Work

The API supports two modes:

### Mode 1: Use OpportunityLineItems (Default)
If you don't pass `lineItems`, it automatically uses the Opportunity's OpportunityLineItems:

```apex
EstimateRequest req = new EstimateRequest();
req.opportunityId = '006xx000003DLVAA2';
req.companyId = '1234567890';
// lineItems is null - uses Opportunity line items
```

### Mode 2: Custom Line Items from Flow
Pass custom line items directly from Flow (useful for quotes not based on Opportunities):

```apex
List<EstimateLineItem> items = new List<EstimateLineItem>();
EstimateLineItem item1 = new EstimateLineItem();
item1.description = 'Product 1';
item1.quantity = 1;
item1.unitPrice = 100;
item1.amount = 100;
item1.quickBooksItemId = 'qb_item_123';
items.add(item1);

EstimateRequest req = new EstimateRequest();
req.lineItems = items;  // Uses custom items instead
```

---

## Custom Fields You Should Add to Opportunity

To make this work better in Flows, consider adding these fields:

1. **QuickBooks_Estimate_Id__c** (Text)
2. **QuickBooks_Estimate_Number__c** (Text)
3. **Estimate_Discount_Amount__c** (Currency)
4. **Estimate_Expiration_Date__c** (Date)

These are created automatically when you run the action, but adding them to the Opportunity object schema makes them visible in Flow Builder.

---

## Testing

### Quick Test in Anonymous Apex:

```apex
// Create a test estimate request
QuickBooksAPIService.EstimateLineItem item =
    new QuickBooksAPIService.EstimateLineItem();
item.description = 'Test Product';
item.quantity = 1;
item.unitPrice = 100;
item.amount = 100;

QuickBooksAPIService.EstimateRequest req =
    new QuickBooksAPIService.EstimateRequest();
req.opportunityId = '006xx000003DLVAA2'; // Your opportunity ID
req.companyId = '1234567890'; // Your QB company ID
req.lineItems = new List<QuickBooksAPIService.EstimateLineItem>{item};
req.discountAmount = 10;

List<QuickBooksAPIService.EstimateResponse> responses =
    QuickBooksAPIService.createEstimate(new List<QuickBooksAPIService.EstimateRequest>{req});

System.debug(responses[0]);
```

---

## API Details

**Endpoint:** `POST https://quickbooks.api.intuit.com/v3/company/{realmId}/estimate`

**Request Body Structure:**
```json
{
  "CustomerRef": {
    "value": "qb_customer_id"
  },
  "TxnDate": "2025-11-07",
  "ExpirationDate": "2025-12-07",
  "itemLines": [
    {
      "sequence": "1",
      "amount": 78900.00,
      "description": "Oxycell Product",
      "quantity": 1,
      "unitPrice": 78900.00,
      "item": {
        "value": "qb_item_id"
      }
    }
  ],
  "discount": {
    "amount": {
      "value": 15092.00
    },
    "applyTaxAfterDiscount": true
  }
}
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Customer not synced" | Make sure Account has QuickBooks_Customer_Id__c field populated. Run "Create QuickBooks Customer" action first. |
| "Line items not appearing" | Check that quickBooksItemId matches actual QB Item IDs. If blank, QB uses line description. |
| "Discount not applied" | Ensure discountAmount > 0 and is a valid Decimal. |
| "401 Unauthorized" | Check that QuickBooks auth token is valid. Review QB OAuth setup. |
| "Item not found" | Verify QB Item IDs exist in your QB company and Product2.QuickBooks_Item_Id__c is populated. |

---

## Next Steps

1. ✅ Deploy the updated QuickBooksAPIService class
2. ✅ Create your Lightning Flow using Flow Builder
3. ✅ Test with a sample Opportunity
4. ✅ Add the flow to your record page as a quick action
5. ✅ Train your team on using the estimate action

Enjoy creating QB estimates directly from Salesforce! 🚀
