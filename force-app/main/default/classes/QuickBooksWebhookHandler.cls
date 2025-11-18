/**
 * QuickBooks Webhook Handler
 * Processes real-time notifications from QuickBooks when data changes
 * Enables bi-directional sync without constant polling
 */
@RestResource(urlMapping='/quickbooks/webhook/*')
global with sharing class QuickBooksWebhookHandler {

    /**
     * HTTP POST handler for incoming webhook notifications
     * QuickBooks sends notifications when entities (Customer, Invoice, Payment, etc.) change
     */
    @HttpPost
    global static void handleWebhook() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            // Verify webhook signature for security
            if (!verifyWebhookSignature(req)) {
                res.statusCode = 401;
                res.responseBody = Blob.valueOf('Unauthorized: Invalid signature');
                return;
            }

            // Parse the webhook payload
            String requestBody = req.requestBody.toString();
            WebhookPayload payload = (WebhookPayload) JSON.deserialize(
                requestBody, WebhookPayload.class
            );

            // Process each event notification
            if (payload.eventNotifications != null) {
                for (EventNotification notification : payload.eventNotifications) {
                    processNotification(notification);
                }
            }

            // Return success response
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('Webhook processed successfully');

        } catch (Exception e) {
            // Log error
            logWebhookError(e.getMessage(), req.requestBody.toString());

            // Return error response
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Internal Server Error: ' + e.getMessage());
        }
    }

    /**
     * Verify webhook signature using HMAC-SHA256
     * QuickBooks includes 'intuit-signature' header for security
     */
    private static Boolean verifyWebhookSignature(RestRequest req) {
        String signature = req.headers.get('intuit-signature');
        if (String.isBlank(signature)) {
            return false;
        }

        // Get verifier token from custom metadata
        QuickBooks_Config__mdt config = QuickBooks_Config__mdt.getInstance('Default');
        String verifierToken = config.Webhook_Verifier_Token__c;

        if (String.isBlank(verifierToken)) {
            System.debug('Warning: Webhook verifier token not configured');
            return false;
        }

        // Calculate expected signature
        Blob hmacData = Crypto.generateMac(
            'HmacSHA256',
            req.requestBody,
            Blob.valueOf(verifierToken)
        );
        String expectedSignature = EncodingUtil.base64Encode(hmacData);

        // Compare signatures
        return signature.equals(expectedSignature);
    }

    /**
     * Process individual event notification
     */
    private static void processNotification(EventNotification notification) {
        System.debug('Processing webhook notification: ' + notification);

        // Handle different entity types
        switch on notification.dataChangeEvent.entities[0].name.toLowerCase() {
            when 'customer' {
                handleCustomerChange(notification);
            }
            when 'invoice' {
                handleInvoiceChange(notification);
            }
            when 'payment' {
                handlePaymentChange(notification);
            }
            when 'item' {
                handleItemChange(notification);
            }
            when 'salesreceipt' {
                handleSalesReceiptChange(notification);
            }
            when 'estimate' {
                handleEstimateChange(notification);
            }
            when else {
                System.debug('Unhandled entity type: ' +
                           notification.dataChangeEvent.entities[0].name);
            }
        }
    }

    /**
     * Handle Customer entity changes
     */
    private static void handleCustomerChange(EventNotification notification) {
        List<String> customerIds = new List<String>();

        for (Entity entity : notification.dataChangeEvent.entities) {
            customerIds.add(entity.id);
        }

        // Queue job to sync customer data
        if (!customerIds.isEmpty()) {
            QuickBooksSyncQueueable job = new QuickBooksSyncQueueable(
                'Customer',
                customerIds,
                notification.realmId
            );
            System.enqueueJob(job);
        }
    }

    /**
     * Handle Invoice entity changes
     */
    private static void handleInvoiceChange(EventNotification notification) {
        List<String> invoiceIds = new List<String>();

        for (Entity entity : notification.dataChangeEvent.entities) {
            invoiceIds.add(entity.id);

            // If invoice is deleted, update related Opportunity
            if (entity.operation == 'Delete') {
                updateOpportunityStatus(entity.id, 'Invoice Deleted');
            }
        }

        // Queue job to sync invoice data
        if (!invoiceIds.isEmpty() &&
            notification.dataChangeEvent.entities[0].operation != 'Delete') {
            QuickBooksSyncQueueable job = new QuickBooksSyncQueueable(
                'Invoice',
                invoiceIds,
                notification.realmId
            );
            System.enqueueJob(job);
        }
    }

    /**
     * Handle Payment entity changes
     */
    private static void handlePaymentChange(EventNotification notification) {
        List<String> paymentIds = new List<String>();

        for (Entity entity : notification.dataChangeEvent.entities) {
            paymentIds.add(entity.id);
        }

        // Queue job to sync payment data
        if (!paymentIds.isEmpty()) {
            QuickBooksSyncQueueable job = new QuickBooksSyncQueueable(
                'Payment',
                paymentIds,
                notification.realmId
            );
            System.enqueueJob(job);
        }
    }

    /**
     * Handle Item entity changes
     */
    private static void handleItemChange(EventNotification notification) {
        List<String> itemIds = new List<String>();

        for (Entity entity : notification.dataChangeEvent.entities) {
            itemIds.add(entity.id);
        }

        // Queue job to sync item data
        if (!itemIds.isEmpty()) {
            QuickBooksSyncQueueable job = new QuickBooksSyncQueueable(
                'Item',
                itemIds,
                notification.realmId
            );
            System.enqueueJob(job);
        }
    }

    /**
     * Handle Sales Receipt entity changes
     */
    private static void handleSalesReceiptChange(EventNotification notification) {
        // Implementation for sales receipt sync
        System.debug('Sales Receipt changed: ' + notification);
    }

    /**
     * Handle Estimate entity changes
     */
    private static void handleEstimateChange(EventNotification notification) {
        // Implementation for estimate sync
        System.debug('Estimate changed: ' + notification);
    }

    /**
     * Update Opportunity status when invoice is deleted
     */
    private static void updateOpportunityStatus(String invoiceId, String status) {
        List<Opportunity> opps = [
            SELECT Id, QuickBooks_Sync_Status__c
            FROM Opportunity
            WHERE QuickBooks_Invoice_Id__c = :invoiceId
            LIMIT 1
        ];

        if (!opps.isEmpty()) {
            opps[0].QuickBooks_Sync_Status__c = status;
            opps[0].QuickBooks_Invoice_Id__c = null;
            update opps[0];
        }
    }

    /**
     * Log webhook error
     */
    private static void logWebhookError(String errorMessage, String payload) {
        Integration_Log__c log = new Integration_Log__c(
            Integration_Type__c = 'QuickBooks Webhook',
            Context__c = 'Webhook Processing',
            Error_Message__c = errorMessage + '\n\nPayload: ' + payload,
            Timestamp__c = DateTime.now()
        );
        insert log;
    }

    // ==================== Webhook Data Classes ====================

    /**
     * Main webhook payload structure
     */
    global class WebhookPayload {
        public List<EventNotification> eventNotifications;
    }

    /**
     * Event notification structure
     */
    global class EventNotification {
        public String realmId;  // QuickBooks Company ID
        public DataChangeEvent dataChangeEvent;
    }

    /**
     * Data change event structure
     */
    global class DataChangeEvent {
        public List<Entity> entities;
    }

    /**
     * Entity structure
     */
    global class Entity {
        public String name;      // Entity type (Customer, Invoice, etc.)
        public String id;         // Entity ID in QuickBooks
        public String operation;  // Create, Update, Delete, Merge, Void
        public DateTime lastUpdated;
    }

    /**
     * Webhook registration response
     */
    global class WebhookVerification {
        public String verifierToken;
        public String webhookUri;
        public Boolean isActive;
    }

    /**
     * Method to verify webhook endpoint (called by QuickBooks during setup)
     */
    @HttpGet
    global static void verifyEndpoint() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        // QuickBooks sends a challenge parameter during verification
        String challenge = req.params.get('challenge');

        if (String.isNotBlank(challenge)) {
            // Echo back the challenge to verify the endpoint
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(challenge);
        } else {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('Missing challenge parameter');
        }
    }
}