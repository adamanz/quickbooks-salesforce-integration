/**
 * Queueable class to process QuickBooks webhook notifications asynchronously
 * Fetches updated data from QuickBooks and syncs to Salesforce
 */
public class QuickBooksSyncQueueable implements Queueable, Database.AllowsCallouts {

    private String entityType;
    private List<String> entityIds;
    private String companyId;

    // Instance variable to hold access token for the duration of the job
    private String accessToken;
    private QuickBooks_Auth__c authRecord;

    /**
     * Constructor
     * @param entityType Type of entity (Customer, Invoice, Payment, Item)
     * @param entityIds List of QuickBooks entity IDs to sync
     * @param companyId QuickBooks company ID (realm ID)
     */
    public QuickBooksSyncQueueable(String entityType, List<String> entityIds, String companyId) {
        this.entityType = entityType;
        this.entityIds = entityIds;
        this.companyId = companyId;
    }

    /**
     * Execute method - processes the sync operation
     * IMPORTANT: Get access token FIRST (may require callout for refresh),
     * then do all API callouts, then do all DML at the end.
     */
    public void execute(QueueableContext context) {
        try {
            // STEP 1: Get access token first (this may do a callout to refresh)
            // Pass false to defer DML - we'll update the auth record at the end
            authRecord = QuickBooksAuthProvider.getValidAuthState(companyId, false);
            accessToken = authRecord.Access_Token__c;

            // STEP 2: Do all API callouts and collect data
            switch on entityType {
                when 'Customer' {
                    syncCustomers();
                }
                when 'Invoice' {
                    syncInvoices();
                }
                when 'Payment' {
                    syncPayments();
                }
                when 'Estimate' {
                    syncEstimates();
                }
                when 'Item' {
                    syncItems();
                }
            }

            // STEP 3: Update auth record if token was refreshed (DML after callouts)
            // The authRecord may have been updated in-memory during getValidAuthState
            update authRecord;

        } catch (Exception e) {
            logError('Sync failed for ' + entityType, e.getMessage());
        }
    }

    /**
     * Sync Customer data from QuickBooks to Salesforce
     */
    private void syncCustomers() {
        for (String customerId : entityIds) {
            try {
                // Fetch customer data from QuickBooks
                Map<String, Object> customerData = fetchEntityFromQuickBooks('customer', customerId);

                if (customerData != null) {
                    // Find or create Account in Salesforce
                    Account acc = findOrCreateAccount(customerData);

                    // Update Account fields
                    updateAccountFromQuickBooks(acc, customerData);
                }
            } catch (Exception e) {
                logError('Customer sync failed: ' + customerId, e.getMessage());
            }
        }
    }

    /**
     * Sync Invoice data from QuickBooks to Salesforce
     * ENHANCED: Also links Invoice back to Opportunity via Estimate chain
     */
    private void syncInvoices() {
        for (String invoiceId : entityIds) {
            try {
                // Fetch invoice data from QuickBooks
                Map<String, Object> invoiceData = fetchEntityFromQuickBooks('invoice', invoiceId);

                if (invoiceData != null) {
                    // Create or update Invoice record
                    processInvoiceData(invoiceData);

                    // Try to find Opportunity - first by Invoice ID, then by linked Estimate
                    Opportunity opp = findOpportunityByInvoiceId(invoiceId);
                    
                    // NEW: If no direct match, try to find via linked Estimate
                    if (opp == null) {
                        String linkedEstimateId = extractLinkedEstimateId(invoiceData);
                        if (linkedEstimateId != null) {
                            opp = findOpportunityByEstimateId(linkedEstimateId);
                            
                            // CRITICAL: Update Opportunity with Invoice ID for future payment matching
                            if (opp != null) {
                                opp.QuickBooks_Invoice_Id__c = invoiceId;
                                opp.QuickBooks_Invoice_Number__c = (String) invoiceData.get('DocNumber');
                                logSuccess('Invoice-Estimate Link', 
                                    'Linked Invoice ' + invoiceId + ' to Opportunity via Estimate ' + linkedEstimateId);
                            }
                        }
                    }
                    
                    if (opp != null) {
                        updateOpportunityFromQuickBooks(opp, invoiceData);
                    }
                }
            } catch (Exception e) {
                logError('Invoice sync failed: ' + invoiceId, e.getMessage());
            }
        }
    }
    
    /**
     * Extract linked Estimate ID from Invoice's LinkedTxn array
     * QuickBooks stores references to source transactions (like Estimates) here
     */
    private String extractLinkedEstimateId(Map<String, Object> invoiceData) {
        List<Object> linkedTxns = (List<Object>) invoiceData.get('LinkedTxn');
        if (linkedTxns != null) {
            for (Object txnObj : linkedTxns) {
                Map<String, Object> txn = (Map<String, Object>) txnObj;
                String txnType = (String) txn.get('TxnType');
                if (txnType == 'Estimate') {
                    return (String) txn.get('TxnId');
                }
            }
        }
        return null;
    }
    
    /**
     * Find Opportunity by QuickBooks Estimate ID
     */
    private Opportunity findOpportunityByEstimateId(String estimateId) {
        List<Opportunity> opps = [
            SELECT Id, Name, Amount, QuickBooks_Estimate_Id__c, 
                   QuickBooks_Invoice_Id__c, QuickBooks_Invoice_Number__c
            FROM Opportunity
            WHERE QuickBooks_Estimate_Id__c = :estimateId
            LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0];
    }
    
    /**
     * Log success message to Integration Log
     */
    private void logSuccess(String context, String message) {
        Integration_Log__c log = new Integration_Log__c(
            Integration_Type__c = 'QuickBooks Webhook Sync',
            Context__c = context,
            Error_Message__c = message,
            Timestamp__c = DateTime.now()
        );
        insert log;
    }

    /**
     * Process invoice data - create/update custom invoice records
     * ENHANCED: Uses multi-strategy matching to find Account and Opportunity
     */
    private void processInvoiceData(Map<String, Object> invoiceData) {
        String qbInvoiceId = (String) invoiceData.get('Id');
        String docNumber = (String) invoiceData.get('DocNumber');
        
        // Try to find existing Invoice
        Invoice__c invoice;
        List<Invoice__c> invoices = [
            SELECT Id, QuickBooks_Invoice_Id__c
            FROM Invoice__c
            WHERE QuickBooks_Invoice_Id__c = :qbInvoiceId
            LIMIT 1
        ];
        
        if (!invoices.isEmpty()) {
            invoice = invoices[0];
        } else {
            invoice = new Invoice__c();
            invoice.QuickBooks_Invoice_Id__c = qbInvoiceId;
        }
        
        // Map fields
        invoice.Total_Amount__c = (Decimal) invoiceData.get('TotalAmt');
        invoice.QuickBooks_Invoice_Number__c = docNumber;
        invoice.Status__c = (String) invoiceData.get('TxnStatus');
        
        String txnDateStr = (String) invoiceData.get('TxnDate');
        if (txnDateStr != null) {
            invoice.Invoice_Date__c = Date.valueOf(txnDateStr.substring(0, 10));
        }
        
        String dueDateStr = (String) invoiceData.get('DueDate');
        if (dueDateStr != null) {
            invoice.Due_Date__c = Date.valueOf(dueDateStr.substring(0, 10));
        }
        
        // ENHANCED: Use multi-strategy matching to find Account and Opportunity
        Map<String, Object> customerRef = (Map<String, Object>) invoiceData.get('CustomerRef');
        Map<String, Object> billEmail = (Map<String, Object>) invoiceData.get('BillEmail');
        Map<String, Object> primaryPhone = (Map<String, Object>) invoiceData.get('PrimaryPhone');
        Map<String, Object> billAddr = (Map<String, Object>) invoiceData.get('BillAddr');
        
        String email = billEmail != null ? (String) billEmail.get('Address') : null;
        String phone = primaryPhone != null ? (String) primaryPhone.get('FreeFormNumber') : null;
        Decimal amount = (Decimal) invoiceData.get('TotalAmt');
        
        // Use the matcher to find or create records
        QuickBooksRecordMatcher.MatchResult match = QuickBooksRecordMatcher.findOrCreateRecords(
            customerRef,
            email,
            phone,
            amount,
            billAddr,
            true  // Create new records if no match found
        );
        
        // Link Invoice to matched Account
        if (match.accountId != null) {
            invoice.Account__c = match.accountId;
        }
        
        // Link Opportunity to this Invoice (if not already linked via Estimate chain)
        if (match.opportunityId != null) {
            // Check if Opportunity already has this invoice linked
            List<Opportunity> existingLink = [
                SELECT Id, QuickBooks_Invoice_Id__c 
                FROM Opportunity 
                WHERE Id = :match.opportunityId 
                LIMIT 1
            ];
            
            if (!existingLink.isEmpty() && existingLink[0].QuickBooks_Invoice_Id__c == null) {
                Opportunity opp = existingLink[0];
                opp.QuickBooks_Invoice_Id__c = qbInvoiceId;
                opp.QuickBooks_Invoice_Number__c = docNumber;
                opp.QuickBooks_Sync_Status__c = 'Synced';
                opp.QuickBooks_Last_Sync__c = DateTime.now();
                update opp;
                
                logSuccess('Invoice Auto-Link', 
                    'Linked Invoice ' + docNumber + 
                    ' to Opportunity via ' + match.matchStrategy +
                    (match.isNewAccount ? ' (new Account created)' : '') +
                    (match.isNewOpportunity ? ' (new Opportunity created)' : ''));
            }
        }
        
        invoice.QuickBooks_Sync_Status__c = 'Synced';
        
        upsert invoice QuickBooks_Invoice_Id__c;
    }

    /**
     * Sync Payment data from QuickBooks to Salesforce
     */
    private void syncPayments() {
        for (String paymentId : entityIds) {
            try {
                // Fetch payment data from QuickBooks
                Map<String, Object> paymentData = fetchEntityFromQuickBooks('payment', paymentId);

                if (paymentData != null) {
                    // Create or update Payment record (custom object)
                    processPaymentData(paymentData);
                }
            } catch (Exception e) {
                logError('Payment sync failed: ' + paymentId, e.getMessage());
            }
        }
    }

    /**
     * Sync Item data from QuickBooks to Salesforce
     */
    private void syncItems() {
        for (String itemId : entityIds) {
            try {
                // Fetch item data from QuickBooks
                Map<String, Object> itemData = fetchEntityFromQuickBooks('item', itemId);

                if (itemData != null) {
                    // Find or create Product in Salesforce
                    Product2 product = findOrCreateProduct(itemData);

                    // Update Product fields
                    updateProductFromQuickBooks(product, itemData);
                }
            } catch (Exception e) {
                logError('Item sync failed: ' + itemId, e.getMessage());
            }
        }
    }

    /**
     * Sync Estimate data from QuickBooks to Salesforce
     */
    private void syncEstimates() {
        for (String estimateId : entityIds) {
            try {
                // Fetch estimate data from QuickBooks
                Map<String, Object> estimateData = fetchEntityFromQuickBooks('estimate', estimateId);

                if (estimateData != null) {
                    // Find or create Estimate in Salesforce
                    Estimate__c estimate = findOrCreateEstimate(estimateData);

                    // Update Estimate fields
                    updateEstimateFromQuickBooks(estimate, estimateData);
                }
            } catch (Exception e) {
                logError('Estimate sync failed: ' + estimateId, e.getMessage());
            }
        }
    }

    /**
     * Find or create Estimate based on QuickBooks estimate data
     */
    private Estimate__c findOrCreateEstimate(Map<String, Object> estimateData) {
        String qbEstimateId = (String) estimateData.get('Id');

        // Try to find existing Estimate
        List<Estimate__c> estimates = [
            SELECT Id, QuickBooks_Estimate_Id__c
            FROM Estimate__c
            WHERE QuickBooks_Estimate_Id__c = :qbEstimateId
            LIMIT 1
        ];

        if (!estimates.isEmpty()) {
            return estimates[0];
        }

        // Create new Estimate
        Estimate__c estimate = new Estimate__c();
        estimate.QuickBooks_Estimate_Id__c = qbEstimateId;
        return estimate;
    }

    /**
     * Update Estimate from QuickBooks estimate data
     * ENHANCED: Uses multi-strategy matching to find Account and Opportunity
     */
    private void updateEstimateFromQuickBooks(Estimate__c estimate, Map<String, Object> estimateData) {
        estimate.Estimate_Amount__c = (Decimal) estimateData.get('TotalAmt');
        estimate.QuickBooks_Estimate_Number__c = (String) estimateData.get('DocNumber');
        estimate.Status__c = (String) estimateData.get('TxnStatus');
        
        String txnDateStr = (String) estimateData.get('TxnDate');
        if (txnDateStr != null) {
            estimate.Estimate_Date__c = Date.valueOf(txnDateStr.substring(0, 10));
        }
        
        String expDateStr = (String) estimateData.get('ExpirationDate');
        if (expDateStr != null) {
            estimate.Expiration_Date__c = Date.valueOf(expDateStr.substring(0, 10));
        }
        
        // ENHANCED: Use multi-strategy matching to find Account and Opportunity
        Map<String, Object> customerRef = (Map<String, Object>) estimateData.get('CustomerRef');
        Map<String, Object> billEmail = (Map<String, Object>) estimateData.get('BillEmail');
        Map<String, Object> primaryPhone = (Map<String, Object>) estimateData.get('PrimaryPhone');
        Map<String, Object> billAddr = (Map<String, Object>) estimateData.get('BillAddr');
        
        String email = billEmail != null ? (String) billEmail.get('Address') : null;
        String phone = primaryPhone != null ? (String) primaryPhone.get('FreeFormNumber') : null;
        Decimal amount = (Decimal) estimateData.get('TotalAmt');
        
        // Use the matcher to find or create records
        QuickBooksRecordMatcher.MatchResult match = QuickBooksRecordMatcher.findOrCreateRecords(
            customerRef,
            email,
            phone,
            amount,
            billAddr,
            true  // Create new records if no match found
        );
        
        // Link Estimate to matched Account
        if (match.accountId != null) {
            estimate.Related_Account__c = match.accountId;
        }
        
        // Link Opportunity to this Estimate
        if (match.opportunityId != null) {
            Opportunity opp = new Opportunity(Id = match.opportunityId);
            opp.QuickBooks_Estimate_Id__c = (String) estimateData.get('Id');
            opp.QuickBooks_Estimate_Number__c = (String) estimateData.get('DocNumber');
            opp.QuickBooks_Sync_Status__c = 'Synced';
            opp.QuickBooks_Last_Sync__c = DateTime.now();
            update opp;
            
            logSuccess('Estimate Auto-Link', 
                'Linked Estimate ' + estimateData.get('DocNumber') + 
                ' to Opportunity via ' + match.matchStrategy +
                (match.isNewAccount ? ' (new Account created)' : '') +
                (match.isNewOpportunity ? ' (new Opportunity created)' : ''));
        }

        estimate.QuickBooks_Sync_Status__c = 'Synced';
        estimate.QuickBooks_Last_Sync__c = DateTime.now();

        upsert estimate QuickBooks_Estimate_Id__c;
    }

    /**
     * Fetch entity data from QuickBooks API
     * Uses the instance accessToken variable (set at start of execute())
     */
    private Map<String, Object> fetchEntityFromQuickBooks(String entityType, String entityId) {
        String endpoint = getBaseUrl() + '/v3/company/' + companyId + '/' + entityType + '/' + entityId;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setTimeout(120000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String capitalizedType = entityType.substring(0, 1).toUpperCase() + entityType.substring(1);
            return (Map<String, Object>) response.get(capitalizedType);
        } else if (res.getStatusCode() == 404) {
            // Entity was deleted in QuickBooks
            return null;
        } else {
            throw new QuickBooksException('Failed to fetch ' + entityType + ': ' + res.getBody());
        }
    }

    /**
     * Find or create Account based on QuickBooks customer data
     */
    private Account findOrCreateAccount(Map<String, Object> customerData) {
        String qbCustomerId = (String) customerData.get('Id');

        // Try to find existing Account
        List<Account> accounts = [
            SELECT Id, Name, QuickBooks_Customer_Id__c, BillingStreet, BillingCity,
                   BillingState, BillingPostalCode, Phone
            FROM Account
            WHERE QuickBooks_Customer_Id__c = :qbCustomerId
            LIMIT 1
        ];

        if (!accounts.isEmpty()) {
            return accounts[0];
        }

        // Create new Account
        Account acc = new Account();
        acc.QuickBooks_Customer_Id__c = qbCustomerId;
        return acc;
    }

    /**
     * Update Account from QuickBooks customer data
     */
    private void updateAccountFromQuickBooks(Account acc, Map<String, Object> customerData) {
        acc.Name = (String) customerData.get('DisplayName');

        // Update billing address
        Map<String, Object> billAddr = (Map<String, Object>) customerData.get('BillAddr');
        if (billAddr != null) {
            acc.BillingStreet = (String) billAddr.get('Line1');
            acc.BillingCity = (String) billAddr.get('City');
            acc.BillingState = (String) billAddr.get('CountrySubDivisionCode');
            acc.BillingPostalCode = (String) billAddr.get('PostalCode');
        }

        // Update phone
        Map<String, Object> primaryPhone = (Map<String, Object>) customerData.get('PrimaryPhone');
        if (primaryPhone != null) {
            acc.Phone = (String) primaryPhone.get('FreeFormNumber');
        }

        acc.QuickBooks_Sync_Status__c = 'Synced';
        acc.QuickBooks_Last_Sync__c = DateTime.now();

        upsert acc QuickBooks_Customer_Id__c;
    }

    /**
     * Find Opportunity by QuickBooks Invoice ID
     */
    private Opportunity findOpportunityByInvoiceId(String invoiceId) {
        List<Opportunity> opps = [
            SELECT Id, Name, Amount, QuickBooks_Invoice_Id__c, QuickBooks_Invoice_Number__c
            FROM Opportunity
            WHERE QuickBooks_Invoice_Id__c = :invoiceId
            LIMIT 1
        ];

        return opps.isEmpty() ? null : opps[0];
    }

    /**
     * Update Opportunity from QuickBooks invoice data
     */
    private void updateOpportunityFromQuickBooks(Opportunity opp, Map<String, Object> invoiceData) {
        // Update invoice number if changed
        String docNumber = (String) invoiceData.get('DocNumber');
        if (docNumber != null) {
            opp.QuickBooks_Invoice_Number__c = docNumber;
        }

        // Update amount from total
        Decimal totalAmt = (Decimal) invoiceData.get('TotalAmt');
        if (totalAmt != null && opp.Amount != totalAmt) {
            opp.Amount = totalAmt;
        }

        opp.QuickBooks_Sync_Status__c = 'Synced';
        opp.QuickBooks_Last_Sync__c = DateTime.now();

        update opp;
    }

    /**
     * Process payment data - create/update custom payment records
     * Captures ALL identifying fields from QuickBooks for flexible linking
     * Then uses multi-strategy linking to find related Opportunity
     */
    private void processPaymentData(Map<String, Object> paymentData) {
        String qbPaymentId = (String) paymentData.get('Id');

        // Try to find existing Payment
        Payment__c payment;
        List<Payment__c> payments = [
            SELECT Id, QuickBooks_Payment_Id__c
            FROM Payment__c
            WHERE QuickBooks_Payment_Id__c = :qbPaymentId
            LIMIT 1
        ];

        if (!payments.isEmpty()) {
            payment = payments[0];
        } else {
            payment = new Payment__c();
            payment.QuickBooks_Payment_Id__c = qbPaymentId;
        }

        // ============================================================
        // CAPTURE ALL QB IDENTIFIERS
        // ============================================================

        // Store raw JSON for debugging/custom parsing
        payment.QuickBooks_Raw_Response__c = JSON.serializePretty(paymentData);

        // Basic payment fields
        Decimal paymentAmount = (Decimal) paymentData.get('TotalAmt');
        payment.Payment_Amount__c = paymentAmount;

        String txnDateStr = (String) paymentData.get('TxnDate');
        if (txnDateStr != null) {
            payment.Payment_Date__c = Date.valueOf(txnDateStr.substring(0, 10));
            payment.Transaction_Date__c = payment.Payment_Date__c;
        }

        payment.Payment_Reference_Number__c = (String) paymentData.get('PaymentRefNum');
        payment.Notes__c = (String) paymentData.get('PrivateNote');

        // CustomerRef - capture both ID and Name
        Map<String, Object> customerRef = (Map<String, Object>) paymentData.get('CustomerRef');
        String qbCustomerId = null;
        if (customerRef != null) {
            qbCustomerId = (String) customerRef.get('value');
            payment.QuickBooks_Customer_Id__c = qbCustomerId;
            payment.QuickBooks_Customer_Name__c = (String) customerRef.get('name');
        }

        // PaymentMethodRef
        Map<String, Object> paymentMethodRef = (Map<String, Object>) paymentData.get('PaymentMethodRef');
        if (paymentMethodRef != null) {
            payment.QuickBooks_Payment_Method_Id__c = (String) paymentMethodRef.get('value');
            payment.Payment_Method__c = (String) paymentMethodRef.get('name');
        }

        // DepositToAccountRef
        Map<String, Object> depositRef = (Map<String, Object>) paymentData.get('DepositToAccountRef');
        if (depositRef != null) {
            payment.QuickBooks_Deposit_Account__c = (String) depositRef.get('value');
        }

        // Extract ALL Invoice IDs from LinkedTxn
        Set<String> linkedInvoiceIds = new Set<String>();
        List<Object> lines = (List<Object>) paymentData.get('Line');
        if (lines != null && !lines.isEmpty()) {
            for (Object lineObj : lines) {
                Map<String, Object> line = (Map<String, Object>) lineObj;
                List<Object> linkedTxns = (List<Object>) line.get('LinkedTxn');
                if (linkedTxns != null) {
                    for (Object txnObj : linkedTxns) {
                        Map<String, Object> linkedTxn = (Map<String, Object>) txnObj;
                        String txnType = (String) linkedTxn.get('TxnType');
                        String txnId = (String) linkedTxn.get('TxnId');

                        if (txnType == 'Invoice' && String.isNotBlank(txnId)) {
                            linkedInvoiceIds.add(txnId);
                        }
                    }
                }
            }
        }

        // Store first invoice ID and ALL invoice IDs
        if (!linkedInvoiceIds.isEmpty()) {
            List<String> invoiceIdList = new List<String>(linkedInvoiceIds);
            payment.QuickBooks_Invoice_Id__c = invoiceIdList[0];
            payment.QuickBooks_All_Invoice_Ids__c = String.join(invoiceIdList, ',');
        }

        // ============================================================
        // LINK TO ACCOUNT via QuickBooks Customer ID
        // ============================================================
        if (qbCustomerId != null) {
            List<Account> accounts = [
                SELECT Id,
                       (SELECT Email FROM Contacts WHERE Email != null ORDER BY CreatedDate LIMIT 1)
                FROM Account
                WHERE QuickBooks_Customer_Id__c = :qbCustomerId
                LIMIT 1
            ];
            if (!accounts.isEmpty()) {
                payment.Related_Account__c = accounts[0].Id;

                // Capture email from primary Contact
                if (!accounts[0].Contacts.isEmpty()) {
                    payment.QuickBooks_Customer_Email__c = accounts[0].Contacts[0].Email;
                }
            }
        }

        // ============================================================
        // MULTI-STRATEGY OPPORTUNITY LINKING
        // ============================================================

        // Strategy 1: Direct match via Invoice ID on Opportunity
        if (!linkedInvoiceIds.isEmpty() && payment.Related_Opportunity__c == null) {
            List<Opportunity> opps = [
                SELECT Id
                FROM Opportunity
                WHERE QuickBooks_Invoice_Id__c IN :linkedInvoiceIds
                LIMIT 1
            ];
            if (!opps.isEmpty()) {
                payment.Related_Opportunity__c = opps[0].Id;
            }
        }

        // Strategy 2 (NEW): Payment → Invoice → Estimate → Opportunity chain
        // This is the KEY strategy for tracing payments back through the full chain
        if (payment.Related_Opportunity__c == null && !linkedInvoiceIds.isEmpty()) {
            for (String invoiceId : linkedInvoiceIds) {
                try {
                    // Fetch the Invoice from QuickBooks to get its linked Estimate
                    Map<String, Object> invoiceData = fetchEntityFromQuickBooks('invoice', invoiceId);
                    if (invoiceData != null) {
                        String linkedEstimateId = extractLinkedEstimateId(invoiceData);
                        if (linkedEstimateId != null) {
                            // Find Opportunity with this Estimate ID
                            Opportunity oppFromEstimate = findOpportunityByEstimateId(linkedEstimateId);
                            if (oppFromEstimate != null) {
                                payment.Related_Opportunity__c = oppFromEstimate.Id;
                                
                                // BONUS: Update the Opportunity with Invoice ID for faster future lookups
                                if (oppFromEstimate.QuickBooks_Invoice_Id__c == null) {
                                    oppFromEstimate.QuickBooks_Invoice_Id__c = invoiceId;
                                    oppFromEstimate.QuickBooks_Invoice_Number__c = (String) invoiceData.get('DocNumber');
                                    oppFromEstimate.QuickBooks_Sync_Status__c = 'Synced';
                                    oppFromEstimate.QuickBooks_Last_Sync__c = DateTime.now();
                                    update oppFromEstimate;
                                    
                                    logSuccess('Payment-Invoice-Estimate Chain', 
                                        'Linked Payment ' + payment.QuickBooks_Payment_Id__c + 
                                        ' to Opportunity via Invoice ' + invoiceId + 
                                        ' → Estimate ' + linkedEstimateId);
                                }
                                break; // Found a match, stop searching
                            }
                        }
                    }
                } catch (Exception e) {
                    // Log but continue - don't fail the whole payment sync
                    System.debug('Error tracing invoice chain for ' + invoiceId + ': ' + e.getMessage());
                }
            }
        }

        // Strategy 3: Via Customer ID → Account → Opportunity with ANY QuickBooks Invoice
        if (payment.Related_Opportunity__c == null && payment.Related_Account__c != null) {
            List<Opportunity> accountOpps = [
                SELECT Id
                FROM Opportunity
                WHERE AccountId = :payment.Related_Account__c
                AND QuickBooks_Invoice_Id__c != null
                ORDER BY CloseDate DESC
                LIMIT 1
            ];
            if (!accountOpps.isEmpty()) {
                payment.Related_Opportunity__c = accountOpps[0].Id;
            }
        }

        // Strategy 4: Via Customer ID → Account → Most recent Closed Won Opportunity
        if (payment.Related_Opportunity__c == null && payment.Related_Account__c != null) {
            List<Opportunity> closedWonOpps = [
                SELECT Id
                FROM Opportunity
                WHERE AccountId = :payment.Related_Account__c
                AND StageName = 'Closed Won'
                ORDER BY CloseDate DESC
                LIMIT 1
            ];
            if (!closedWonOpps.isEmpty()) {
                payment.Related_Opportunity__c = closedWonOpps[0].Id;
            }
        }

        // Strategy 5: Via Customer ID → Account → Opportunity with matching Amount
        if (payment.Related_Opportunity__c == null && payment.Related_Account__c != null && paymentAmount != null) {
            List<Opportunity> amountMatchOpps = [
                SELECT Id
                FROM Opportunity
                WHERE AccountId = :payment.Related_Account__c
                AND Amount = :paymentAmount
                ORDER BY CloseDate DESC
                LIMIT 1
            ];
            if (!amountMatchOpps.isEmpty()) {
                payment.Related_Opportunity__c = amountMatchOpps[0].Id;
            }
        }
        
        // Strategy 6: Via Estimate → Opportunity (if payment has Estimate reference in notes)
        // Check if the payment notes contain a Salesforce reference
        if (payment.Related_Opportunity__c == null && payment.Notes__c != null) {
            // Look for pattern like "SF-Opp:" or "Opportunity:" followed by ID
            Pattern oppPattern = Pattern.compile('(?:SF-Opp:|Opportunity:)\\s*([a-zA-Z0-9]{15,18})');
            Matcher m = oppPattern.matcher(payment.Notes__c);
            if (m.find()) {
                String oppId = m.group(1);
                try {
                    List<Opportunity> noteOpps = [SELECT Id FROM Opportunity WHERE Id = :oppId LIMIT 1];
                    if (!noteOpps.isEmpty()) {
                        payment.Related_Opportunity__c = noteOpps[0].Id;
                    }
                } catch (Exception e) {
                    // Invalid ID format, continue
                }
            }
        }

        payment.QuickBooks_Sync_Status__c = 'Synced';

        upsert payment QuickBooks_Payment_Id__c;
    }

    /**
     * Find or create Product based on QuickBooks item data
     */
    private Product2 findOrCreateProduct(Map<String, Object> itemData) {
        String qbItemId = (String) itemData.get('Id');

        // Try to find existing Product
        List<Product2> products = [
            SELECT Id, Name, ProductCode, QuickBooks_Item_Id__c
            FROM Product2
            WHERE QuickBooks_Item_Id__c = :qbItemId
            LIMIT 1
        ];

        if (!products.isEmpty()) {
            return products[0];
        }

        // Create new Product
        Product2 product = new Product2();
        product.QuickBooks_Item_Id__c = qbItemId;
        return product;
    }

    /**
     * Update Product from QuickBooks item data
     */
    private void updateProductFromQuickBooks(Product2 product, Map<String, Object> itemData) {
        product.Name = (String) itemData.get('Name');
        product.ProductCode = (String) itemData.get('Sku');
        product.Description = (String) itemData.get('Description');
        product.IsActive = (Boolean) itemData.get('Active');

        product.QuickBooks_Sync_Status__c = 'Synced';

        upsert product QuickBooks_Item_Id__c;

        // Update PricebookEntry if price changed
        Decimal unitPrice = (Decimal) itemData.get('UnitPrice');
        if (unitPrice != null) {
            updatePricebookEntry(product.Id, unitPrice);
        }
    }

    /**
     * Update pricebook entry for product
     */
    private void updatePricebookEntry(Id productId, Decimal unitPrice) {
        Id pricebookId = Test.isRunningTest() ? Test.getStandardPricebookId() :
                        [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;

        List<PricebookEntry> entries = [
            SELECT Id, UnitPrice
            FROM PricebookEntry
            WHERE Product2Id = :productId
            AND Pricebook2Id = :pricebookId
            LIMIT 1
        ];

        if (!entries.isEmpty()) {
            if (entries[0].UnitPrice != unitPrice) {
                entries[0].UnitPrice = unitPrice;
                update entries[0];
            }
        } else {
            // Create new pricebook entry
            PricebookEntry pbe = new PricebookEntry(
                Product2Id = productId,
                Pricebook2Id = pricebookId,
                UnitPrice = unitPrice,
                IsActive = true
            );
            insert pbe;
        }
    }

    /**
     * Get base URL for QuickBooks API
     */
    private String getBaseUrl() {
        QuickBooks_Config__mdt config = QuickBooks_Config__mdt.getInstance('Default');
        return config.Is_Sandbox__c ?
               'https://sandbox-quickbooks.api.intuit.com' :
               'https://quickbooks.api.intuit.com';
    }

    /**
     * Log error to Integration Log
     */
    private void logError(String context, String errorMessage) {
        Integration_Log__c log = new Integration_Log__c(
            Integration_Type__c = 'QuickBooks Webhook Sync',
            Context__c = context,
            Error_Message__c = errorMessage,
            Timestamp__c = DateTime.now()
        );
        insert log;
    }

    /**
     * Custom exception class
     */
    public class QuickBooksException extends Exception {}
}