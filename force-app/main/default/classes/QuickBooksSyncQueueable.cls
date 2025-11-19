/**
 * Queueable class to process QuickBooks webhook notifications asynchronously
 * Fetches updated data from QuickBooks and syncs to Salesforce
 */
public class QuickBooksSyncQueueable implements Queueable, Database.AllowsCallouts {

    private String entityType;
    private List<String> entityIds;
    private String companyId;

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
     */
    public void execute(QueueableContext context) {
        try {
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
     */
    private void syncInvoices() {
        for (String invoiceId : entityIds) {
            try {
                // Fetch invoice data from QuickBooks
                Map<String, Object> invoiceData = fetchEntityFromQuickBooks('invoice', invoiceId);

                if (invoiceData != null) {
                    // Find related Opportunity
                    Opportunity opp = findOpportunityByInvoiceId(invoiceId);

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
        
        // Link to Account
        Map<String, Object> customerRef = (Map<String, Object>) estimateData.get('CustomerRef');
        if (customerRef != null) {
            String customerId = (String) customerRef.get('value');
            List<Account> accounts = [SELECT Id FROM Account WHERE QuickBooks_Customer_Id__c = :customerId LIMIT 1];
            if (!accounts.isEmpty()) {
                estimate.Related_Account__c = accounts[0].Id;
            }
        }

        estimate.QuickBooks_Sync_Status__c = 'Synced';
        estimate.QuickBooks_Last_Sync__c = DateTime.now();

        upsert estimate QuickBooks_Estimate_Id__c;
    }

    /**
     * Fetch entity data from QuickBooks API
     */
    private Map<String, Object> fetchEntityFromQuickBooks(String entityType, String entityId) {
        String endpoint = getBaseUrl() + '/v3/company/' + companyId + '/' + entityType + '/' + entityId;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + QuickBooksAuthProvider.getValidAccessToken(companyId));
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
        
        // Map fields
        payment.Payment_Amount__c = (Decimal) paymentData.get('TotalAmt');
        
        String txnDateStr = (String) paymentData.get('TxnDate');
        if (txnDateStr != null) {
            payment.Payment_Date__c = Date.valueOf(txnDateStr.substring(0, 10));
            payment.Transaction_Date__c = payment.Payment_Date__c;
        }
        
        payment.Payment_Reference_Number__c = (String) paymentData.get('PaymentRefNum');
        payment.Notes__c = (String) paymentData.get('PrivateNote');
        
        // Map Customer Reference to Account
        Map<String, Object> customerRef = (Map<String, Object>) paymentData.get('CustomerRef');
        if (customerRef != null) {
            String customerId = (String) customerRef.get('value');
            List<Account> accounts = [SELECT Id FROM Account WHERE QuickBooks_Customer_Id__c = :customerId LIMIT 1];
            if (!accounts.isEmpty()) {
                payment.Related_Account__c = accounts[0].Id;
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