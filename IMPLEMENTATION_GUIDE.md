# QuickBooks-Salesforce Integration Implementation Guide

## Overview
Complete bi-directional integration between Salesforce Opportunities and QuickBooks sales cycle (Customer → Estimate → Invoice → Payment).

---

## Architecture Flow

```
SALESFORCE → QUICKBOOKS (Outbound via Invocable Actions)
├─ 1. Create Customer in QuickBooks (from Account)
├─ 2. Create Estimate in QuickBooks (from Opportunity)
├─ 3. Convert Estimate to Invoice (when Opp progresses)
└─ 4. Send Invoice to customer

QUICKBOOKS → SALESFORCE (Inbound via Webhooks)
├─ Customer changes → Update Account
├─ Estimate changes → Update Opportunity
├─ Invoice changes → Update Opportunity
└─ Payment received → Create Payment__c → Trigger Flow → Close Opp as Won
```

---

## Custom Objects Required

### 1. Payment__c (NEW - Must Create)
Stores payment records from QuickBooks.

**Fields:**
- `Name` (Auto Number): PAY-{0000}
- `QuickBooks_Payment_Id__c` (Text 255, External ID, Unique)
- `QuickBooks_Invoice_Id__c` (Text 255)
- `Related_Opportunity__c` (Lookup to Opportunity)
- `Related_Account__c` (Lookup to Account)
- `Payment_Amount__c` (Currency)
- `Payment_Date__c` (Date)
- `Payment_Method__c` (Text 100)
- `Transaction_Date__c` (DateTime)
- `Payment_Reference_Number__c` (Text 100)
- `Notes__c` (Long Text Area)
- `QuickBooks_Sync_Status__c` (Text 50)

### 2. Estimate__c (NEW - Must Create)
Stores estimate/quote records from QuickBooks.

**Fields:**
- `Name` (Auto Number): EST-{0000}
- `QuickBooks_Estimate_Id__c` (Text 255, External ID, Unique)
- `QuickBooks_Estimate_Number__c` (Text 100)
- `Related_Opportunity__c` (Lookup to Opportunity)
- `Related_Account__c` (Lookup to Account)
- `Estimate_Amount__c` (Currency)
- `Estimate_Date__c` (Date)
- `Expiration_Date__c` (Date)
- `Status__c` (Picklist: Pending, Accepted, Rejected, Converted to Invoice)
- `QuickBooks_Sync_Status__c` (Text 50)
- `QuickBooks_Last_Sync__c` (DateTime)

### 3. Existing Objects to Enhance

**Account Fields (if not already present):**
- `QuickBooks_Customer_Id__c` (Text 255, External ID, Unique)
- `QuickBooks_Sync_Status__c` (Text 50)
- `QuickBooks_Last_Sync__c` (DateTime)

**Opportunity Fields (if not already present):**
- `QuickBooks_Estimate_Id__c` (Text 255)
- `QuickBooks_Estimate_Number__c` (Text 100)
- `QuickBooks_Invoice_Id__c` (Text 255)
- `QuickBooks_Invoice_Number__c` (Text 100)
- `QuickBooks_Sync_Status__c` (Text 50)
- `QuickBooks_Last_Sync__c` (DateTime)

---

## Invocable Apex Actions Required

### 1. Create Customer in QuickBooks
**Class:** `QuickBooksInvocableActions.createCustomer`

**Input:**
- Account ID

**Process:**
1. Get Account details (Name, BillingAddress, Phone, Email)
2. Check if QuickBooks_Customer_Id__c already exists
3. If exists → Update customer in QuickBooks
4. If not → Create new customer in QuickBooks
5. Store returned Customer ID in Account.QuickBooks_Customer_Id__c
6. Update Account.QuickBooks_Sync_Status__c = "Synced"

**Output:**
- Success/Error message
- QuickBooks Customer ID

---

### 2. Create Estimate in QuickBooks
**Class:** `QuickBooksInvocableActions.createEstimate`

**Input:**
- Opportunity ID

**Process:**
1. Get Opportunity details (Amount, Products, Account)
2. Verify Account has QuickBooks_Customer_Id__c
3. If not → Create customer first (call createCustomer)
4. Build estimate payload with line items
5. Create estimate in QuickBooks
6. Create Estimate__c record in Salesforce
7. Link Estimate__c to Opportunity
8. Update Opportunity.QuickBooks_Estimate_Id__c
9. Update Opportunity.QuickBooks_Sync_Status__c = "Estimate Created"

**Output:**
- Success/Error message
- QuickBooks Estimate ID
- Estimate__c record ID

---

### 3. Create Invoice from Estimate
**Class:** `QuickBooksInvocableActions.createInvoiceFromEstimate`

**Input:**
- Opportunity ID (or Estimate__c ID)

**Process:**
1. Get Estimate ID from Opportunity.QuickBooks_Estimate_Id__c
2. Verify estimate exists in QuickBooks
3. Create invoice in QuickBooks (can reference estimate or copy line items)
4. Update Opportunity.QuickBooks_Invoice_Id__c
5. Update Opportunity.QuickBooks_Invoice_Number__c
6. Update Opportunity.QuickBooks_Sync_Status__c = "Invoice Created"
7. Update Estimate__c.Status__c = "Converted to Invoice"
8. Update Opportunity.StageName (e.g., "Invoice Sent")

**Output:**
- Success/Error message
- QuickBooks Invoice ID

---

### 4. Send Invoice to Customer
**Class:** `QuickBooksInvocableActions.sendInvoice`

**Input:**
- Opportunity ID (or Invoice ID)

**Process:**
1. Get Invoice ID from Opportunity.QuickBooks_Invoice_Id__c
2. Call QuickBooks API to send invoice via email
3. Update Opportunity.QuickBooks_Sync_Status__c = "Invoice Sent"
4. Log activity on Opportunity

**Output:**
- Success/Error message
- Email sent status

---

## Salesforce Flows

### Flow 1: Create QuickBooks Customer
**Trigger:** Record-Triggered Flow on Account
**When:** After Save, Record is Created or Updated
**Conditions:** QuickBooks_Customer_Id__c IS NULL

**Steps:**
1. Decision: Check if Account has required fields (Name, BillingStreet, etc.)
2. Action: Call Invocable Apex → createCustomer
3. Update Account with result

---

### Flow 2: Create Estimate When Opportunity Reaches Stage
**Trigger:** Record-Triggered Flow on Opportunity
**When:** After Save, Record is Updated
**Conditions:**
- StageName = "Proposal/Price Quote" (or your stage)
- QuickBooks_Estimate_Id__c IS NULL

**Steps:**
1. Get Account → Verify QuickBooks_Customer_Id__c exists
2. If NULL → Call createCustomer first
3. Call Invocable Apex → createEstimate
4. Update Opportunity with result
5. Create Task: "Estimate sent to customer"

---

### Flow 3: Create Invoice When Opportunity Progresses
**Trigger:** Record-Triggered Flow on Opportunity
**When:** After Save, Record is Updated
**Conditions:**
- StageName = "Negotiation/Review" or "Closed Won" (your choice)
- QuickBooks_Estimate_Id__c IS NOT NULL
- QuickBooks_Invoice_Id__c IS NULL

**Steps:**
1. Call Invocable Apex → createInvoiceFromEstimate
2. Update Opportunity with result
3. Decision: Auto-send invoice?
   - Yes → Call sendInvoice
   - No → Create Task: "Invoice ready - send to customer"

---

### Flow 4: Mark Opportunity Closed Won on Payment
**Trigger:** Record-Triggered Flow on Payment__c
**When:** After Save, Record is Created
**Conditions:** Payment_Amount__c > 0

**Steps:**
1. Get Related Opportunity (via Related_Opportunity__c)
2. Decision: Is payment amount >= Opportunity.Amount?
   - Full payment → Update Opp:
     - StageName = "Closed Won"
     - CloseDate = Payment.Payment_Date__c
     - QuickBooks_Sync_Status__c = "Paid in Full"
   - Partial payment → Update Opp:
     - QuickBooks_Sync_Status__c = "Partial Payment Received"
3. Create Task on Opportunity: "Payment received: $X on [date]"
4. Optional: Send email notification to owner

---

## Webhook Handlers (Inbound from QuickBooks)

### Update QuickBooksWebhookHandler.cls

Add these methods to handle estimates and payments properly:

#### Handle Estimate Changes
```apex
private static void handleEstimateChange(EventNotification notification) {
    List<String> estimateIds = new List<String>();

    for (Entity entity : notification.dataChangeEvent.entities) {
        estimateIds.add(entity.id);
    }

    if (!estimateIds.isEmpty()) {
        QuickBooksSyncQueueable job = new QuickBooksSyncQueueable(
            'Estimate',
            estimateIds,
            notification.realmId
        );
        System.enqueueJob(job);
    }
}
```

#### Handle Payment Changes (Updated)
```apex
private static void handlePaymentChange(EventNotification notification) {
    List<String> paymentIds = new List<String>();

    for (Entity entity : notification.dataChangeEvent.entities) {
        paymentIds.add(entity.id);
    }

    if (!paymentIds.isEmpty()) {
        QuickBooksSyncQueueable job = new QuickBooksSyncQueueable(
            'Payment',
            paymentIds,
            notification.realmId
        );
        System.enqueueJob(job);
    }
}
```

---

## Update QuickBooksSyncQueueable.cls

### Add Estimate Sync Method
```apex
private void syncEstimates() {
    for (String estimateId : entityIds) {
        try {
            Map<String, Object> estimateData = fetchEntityFromQuickBooks('estimate', estimateId);

            if (estimateData != null) {
                processEstimateData(estimateData);
            }
        } catch (Exception e) {
            logError('Estimate sync failed: ' + estimateId, e.getMessage());
        }
    }
}

private void processEstimateData(Map<String, Object> estimateData) {
    String qbEstimateId = (String) estimateData.get('Id');

    // Find or create Estimate__c record
    List<Estimate__c> estimates = [
        SELECT Id, Related_Opportunity__c, QuickBooks_Estimate_Id__c
        FROM Estimate__c
        WHERE QuickBooks_Estimate_Id__c = :qbEstimateId
        LIMIT 1
    ];

    Estimate__c estimate;
    if (!estimates.isEmpty()) {
        estimate = estimates[0];
    } else {
        estimate = new Estimate__c();
        estimate.QuickBooks_Estimate_Id__c = qbEstimateId;

        // Try to find related Opportunity
        String customerRefId = getCustomerRefId(estimateData);
        if (customerRefId != null) {
            estimate.Related_Account__c = findAccountByQBCustomerId(customerRefId);
        }
    }

    // Update fields
    estimate.QuickBooks_Estimate_Number__c = (String) estimateData.get('DocNumber');
    estimate.Estimate_Amount__c = (Decimal) estimateData.get('TotalAmt');
    estimate.Estimate_Date__c = Date.valueOf((String) estimateData.get('TxnDate'));
    estimate.Status__c = mapEstimateStatus((String) estimateData.get('TxnStatus'));
    estimate.QuickBooks_Sync_Status__c = 'Synced';
    estimate.QuickBooks_Last_Sync__c = DateTime.now();

    upsert estimate QuickBooks_Estimate_Id__c;

    // Update related Opportunity if exists
    if (estimate.Related_Opportunity__c != null) {
        updateOpportunityWithEstimate(estimate.Related_Opportunity__c, estimateData);
    }
}
```

### Update Payment Sync Method (Replace existing)
```apex
private void syncPayments() {
    for (String paymentId : entityIds) {
        try {
            Map<String, Object> paymentData = fetchEntityFromQuickBooks('payment', paymentId);

            if (paymentData != null) {
                createPaymentRecord(paymentData);
            }
        } catch (Exception e) {
            logError('Payment sync failed: ' + paymentId, e.getMessage());
        }
    }
}

private void createPaymentRecord(Map<String, Object> paymentData) {
    String qbPaymentId = (String) paymentData.get('Id');

    // Find or create Payment__c record
    List<Payment__c> payments = [
        SELECT Id FROM Payment__c
        WHERE QuickBooks_Payment_Id__c = :qbPaymentId
        LIMIT 1
    ];

    Payment__c payment;
    if (!payments.isEmpty()) {
        payment = payments[0];
    } else {
        payment = new Payment__c();
        payment.QuickBooks_Payment_Id__c = qbPaymentId;
    }

    // Extract payment details
    payment.Payment_Amount__c = (Decimal) paymentData.get('TotalAmt');
    payment.Payment_Date__c = Date.valueOf((String) paymentData.get('TxnDate'));
    payment.Transaction_Date__c = DateTime.now();

    // Get payment method
    Map<String, Object> paymentMethodRef = (Map<String, Object>) paymentData.get('PaymentMethodRef');
    if (paymentMethodRef != null) {
        payment.Payment_Method__c = (String) paymentMethodRef.get('name');
    }

    // Get reference number
    payment.Payment_Reference_Number__c = (String) paymentData.get('PaymentRefNum');

    // Find linked invoice and opportunity
    List<Object> lines = (List<Object>) paymentData.get('Line');
    if (lines != null && !lines.isEmpty()) {
        for (Object lineObj : lines) {
            Map<String, Object> line = (Map<String, Object>) lineObj;
            List<Object> linkedTxns = (List<Object>) line.get('LinkedTxn');

            if (linkedTxns != null) {
                for (Object txnObj : linkedTxns) {
                    Map<String, Object> txn = (Map<String, Object>) txnObj;
                    String txnType = (String) txn.get('TxnType');
                    String txnId = (String) txn.get('TxnId');

                    if (txnType == 'Invoice') {
                        payment.QuickBooks_Invoice_Id__c = txnId;

                        // Find related Opportunity
                        List<Opportunity> opps = [
                            SELECT Id, AccountId
                            FROM Opportunity
                            WHERE QuickBooks_Invoice_Id__c = :txnId
                            LIMIT 1
                        ];

                        if (!opps.isEmpty()) {
                            payment.Related_Opportunity__c = opps[0].Id;
                            payment.Related_Account__c = opps[0].AccountId;
                        }

                        break; // Only process first invoice
                    }
                }
            }
        }
    }

    payment.QuickBooks_Sync_Status__c = 'Synced';

    upsert payment QuickBooks_Payment_Id__c;

    // Log success
    System.debug('Payment record created/updated: ' + payment.Id);
}
```

---

## Implementation Checklist

### Phase 1: Setup Custom Objects
- [ ] Create Payment__c custom object with all fields
- [ ] Create Estimate__c custom object with all fields
- [ ] Add missing fields to Account object
- [ ] Add missing fields to Opportunity object
- [ ] Deploy all custom objects to org

### Phase 2: Create Invocable Apex Actions
- [ ] Create QuickBooksInvocableActions.cls
- [ ] Implement createCustomer method
- [ ] Implement createEstimate method
- [ ] Implement createInvoiceFromEstimate method
- [ ] Implement sendInvoice method
- [ ] Write test class with 75%+ coverage
- [ ] Deploy Apex classes

### Phase 3: Update Webhook Handlers
- [ ] Update QuickBooksWebhookHandler.cls
  - [ ] Update handleEstimateChange method
  - [ ] Update handlePaymentChange method
- [ ] Update QuickBooksSyncQueueable.cls
  - [ ] Add syncEstimates method
  - [ ] Update syncPayments method
  - [ ] Add processEstimateData method
  - [ ] Add createPaymentRecord method
- [ ] Add 'Estimate' case to execute() switch statement
- [ ] Deploy updated classes

### Phase 4: Create Flows
- [ ] Create "Create QuickBooks Customer" flow
- [ ] Create "Create Estimate" flow
- [ ] Create "Create Invoice from Estimate" flow
- [ ] Create "Mark Opportunity Closed Won on Payment" flow
- [ ] Activate all flows
- [ ] Test each flow individually

### Phase 5: QuickBooks Configuration
- [ ] Ensure OAuth connection is active
- [ ] Verify webhook is configured with entities:
  - Customer
  - Estimate
  - Invoice
  - Payment
- [ ] Test webhook endpoint with QuickBooks test tool
- [ ] Verify signature validation working

### Phase 6: End-to-End Testing
- [ ] Test Case 1: New Account → Create Customer in QB
- [ ] Test Case 2: Opp reaches stage → Create Estimate
- [ ] Test Case 3: Estimate approved → Create Invoice
- [ ] Test Case 4: Payment in QB → Create Payment__c → Close Opp
- [ ] Test Case 5: Webhook updates from QB → Salesforce sync
- [ ] Test Case 6: Error handling and logging

### Phase 7: Documentation & Training
- [ ] Document the complete flow for users
- [ ] Create troubleshooting guide
- [ ] Train sales team on the process
- [ ] Set up monitoring for Integration_Log__c errors

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                          SALESFORCE                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. Account Created                                                 │
│     ↓                                                               │
│  Flow: Create QuickBooks Customer                                   │
│     ↓                                                               │
│  Invocable: createCustomer() ──────────────┐                       │
│                                             │                       │
│  2. Opportunity → "Proposal" Stage          │                       │
│     ↓                                       │                       │
│  Flow: Create Estimate                      │                       │
│     ↓                                       │                       │
│  Invocable: createEstimate() ──────────────┤                       │
│     ↓                                       │                       │
│  Estimate__c Created                        │                       │
│                                             │                       │
│  3. Opportunity → "Negotiation" Stage       │                       │
│     ↓                                       │                       │
│  Flow: Create Invoice                       │                       │
│     ↓                                       │                       │
│  Invocable: createInvoiceFromEstimate() ───┤                       │
│                                             │                       │
│  4. Webhook: Payment Received ◄─────────────┼───────────────┐       │
│     ↓                                       │               │       │
│  QuickBooksWebhookHandler                   │               │       │
│     ↓                                       │               │       │
│  QuickBooksSyncQueueable (Payment)          │               │       │
│     ↓                                       │               │       │
│  Payment__c Created ◄───────────────────────┘               │       │
│     ↓                                                       │       │
│  Flow: Mark Opp Closed Won                                  │       │
│     ↓                                                       │       │
│  Opportunity.StageName = "Closed Won"                       │       │
│                                                             │       │
└─────────────────────────────────────────────────────────────┼───────┘
                                                              │
                          ▲                                   │
                          │                                   │
                          │                                   ▼
┌─────────────────────────┼───────────────────────────────────────────┐
│                         │           QUICKBOOKS                      │
├─────────────────────────┼───────────────────────────────────────────┤
│                         │                                           │
│  Customer Created ◄─────┤                                           │
│                         │                                           │
│  Estimate Created ◄─────┤                                           │
│                         │                                           │
│  Invoice Created ◄──────┘                                           │
│                                                                     │
│  Payment Received ──────────────────────────────────────────────┐   │
│     │                                                           │   │
│     └─→ Webhook Notification ─────────────────────────────────►│   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Error Handling Strategy

1. **All Invocable Actions:**
   - Wrap in try-catch
   - Log to Integration_Log__c
   - Return clear error messages to Flow
   - Don't throw exceptions (let Flow handle)

2. **All Webhook Handlers:**
   - Verify signature first (security)
   - Log all incoming webhooks
   - Queue async jobs (avoid timeout)
   - Return 200 even if processing fails later

3. **Queueable Jobs:**
   - Individual try-catch per entity
   - Continue processing even if one fails
   - Log each error separately
   - Create audit trail in Integration_Log__c

4. **Flows:**
   - Add fault paths for all actions
   - Send email alerts on critical errors
   - Create tasks for manual review when needed
   - Never fail silently

---

## Monitoring & Maintenance

### Daily Monitoring
- Check Integration_Log__c for errors
- Review failed webhook notifications
- Monitor queueable job failures

### Weekly Review
- Review Payment__c records for orphans (no Related_Opportunity__c)
- Check for Opportunities stuck in stages
- Verify sync status fields are accurate

### Monthly Audit
- Compare QuickBooks data vs Salesforce
- Review sync success rate
- Check for duplicate customer records
- Update documentation as needed

---

## Next Steps

1. Review this implementation guide
2. Confirm custom object field requirements
3. Prioritize which invocable actions to build first
4. Set up development sandbox for testing
5. Start with Phase 1 (Custom Objects)

**Estimated Implementation Time:** 3-4 weeks
- Week 1: Custom objects, fields, and basic Apex
- Week 2: Invocable actions and webhook updates
- Week 3: Flows and integration testing
- Week 4: UAT and deployment to production
