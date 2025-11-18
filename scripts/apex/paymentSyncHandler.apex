/**
 * Payment Sync Handler
 * Add this method to your QuickBooksSyncQueueable class
 * This processes payment webhooks and updates related Opportunities
 */

// Add this method to QuickBooksSyncQueueable.cls:

private void syncPayments() {
    for (String paymentId : entityIds) {
        try {
            // Fetch payment details from QuickBooks
            String endpoint = '/v3/company/' + companyId + '/payment/' + paymentId;
            HttpResponse response = QuickBooksAPIService.makeAPICall('GET', endpoint, null);

            if (response.getStatusCode() == 200) {
                Map<String, Object> payment = (Map<String, Object>)
                    JSON.deserializeUntyped(response.getBody());

                processPayment(payment);
            }
        } catch (Exception e) {
            logError('Payment Sync', e.getMessage(), paymentId);
        }
    }
}

/**
 * Process individual payment and update related records
 */
private void processPayment(Map<String, Object> paymentData) {
    // Extract payment details
    String paymentId = String.valueOf(paymentData.get('Id'));
    Decimal totalAmount = (Decimal) paymentData.get('TotalAmt');
    String txnDate = (String) paymentData.get('TxnDate');
    String paymentMethod = (String) paymentData.get('PaymentMethodRef');

    // Get linked invoices from Line items
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

                    // If this payment is linked to an Invoice
                    if (txnType == 'Invoice') {
                        updateOpportunityWithPayment(txnId, paymentData);
                    }
                }
            }
        }
    }

    // Log the payment sync
    Integration_Log__c log = new Integration_Log__c(
        Integration_Type__c = 'QuickBooks Payment Sync',
        Context__c = 'Payment ID: ' + paymentId,
        Error_Message__c = 'Payment of ' + totalAmount + ' processed successfully',
        Timestamp__c = DateTime.now()
    );
    insert log;
}

/**
 * Update Opportunity when payment is received
 */
private void updateOpportunityWithPayment(String invoiceId, Map<String, Object> paymentData) {
    // Find the Opportunity with this invoice
    List<Opportunity> opps = [
        SELECT Id, Name, StageName, Amount,
               QuickBooks_Invoice_Id__c, QuickBooks_Sync_Status__c
        FROM Opportunity
        WHERE QuickBooks_Invoice_Id__c = :invoiceId
        LIMIT 1
    ];

    if (!opps.isEmpty()) {
        Opportunity opp = opps[0];

        // Update opportunity to reflect payment
        opp.StageName = 'Closed Won';  // or your preferred stage
        opp.QuickBooks_Sync_Status__c = 'Invoice Paid';
        opp.CloseDate = Date.today();
        opp.Description = (opp.Description != null ? opp.Description + '\n\n' : '') +
                         'Payment received on ' + DateTime.now().format() +
                         '\nPayment ID: ' + paymentData.get('Id') +
                         '\nAmount: $' + paymentData.get('TotalAmt');

        update opp;

        // Optional: Create a Task to record the payment
        Task paymentTask = new Task(
            Subject = 'Payment Received - $' + paymentData.get('TotalAmt'),
            WhatId = opp.Id,
            Status = 'Completed',
            Priority = 'Normal',
            ActivityDate = Date.today(),
            Description = 'QuickBooks Payment ID: ' + paymentData.get('Id') + '\n' +
                         'Payment Method: ' + paymentData.get('PaymentMethodRef') + '\n' +
                         'Transaction Date: ' + paymentData.get('TxnDate')
        );
        insert paymentTask;
    }
}