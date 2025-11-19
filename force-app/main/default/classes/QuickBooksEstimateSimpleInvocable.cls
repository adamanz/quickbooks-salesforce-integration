/**
 * Simplified QuickBooks Estimate Invocable for testing
 * Mock implementation that doesn't require actual API calls
 */
public with sharing class QuickBooksEstimateSimpleInvocable {

    @InvocableMethod(label='Create QuickBooks Estimate (Simple)'
                     description='Creates an estimate in QuickBooks with line items (Mock)'
                     category='QuickBooks Integration')
    public static List<QuickBooksEstimateResponse> createEstimate(List<QuickBooksEstimateRequest> requests) {
        List<QuickBooksEstimateResponse> responses = new List<QuickBooksEstimateResponse>();

        for (QuickBooksEstimateRequest request : requests) {
            QuickBooksEstimateResponse response = new QuickBooksEstimateResponse();
            response.salesforceOpportunityId = request.opportunityId;

            try {
                // Parse line items from JSON if provided
                if (String.isNotBlank(request.lineItemsJson)) {
                    request.parseLineItems();
                }

                // Log estimate details
                System.debug('Creating QuickBooks Estimate:');
                System.debug('- Opportunity ID: ' + request.opportunityId);
                System.debug('- Customer Ref: ' + request.customerRef);
                System.debug('- Customer Name: ' + request.customerName);
                System.debug('- Estimate Date: ' + request.estimateDate);
                System.debug('- Expiration Date: ' + request.expirationDate);

                // Log line items
                if (request.lineItems != null && !request.lineItems.isEmpty()) {
                    System.debug('Line Items (' + request.lineItems.size() + ' items):');
                    Decimal totalAmount = 0;
                    for (QuickBooksEstimateLineItem item : request.lineItems) {
                        item.calculateAmount();
                        System.debug('  - ' + item.description + ': Qty ' + item.quantity +
                                   ' x $' + item.unitPrice + ' = $' + item.amount);
                        totalAmount += item.amount != null ? item.amount : 0;
                    }
                    System.debug('Subtotal: $' + totalAmount);

                    // Apply discount
                    if (request.discountPercent != null && request.discountPercent > 0) {
                        Decimal discount = totalAmount * (request.discountPercent / 100);
                        totalAmount -= discount;
                        System.debug('Discount (' + request.discountPercent + '%): -$' + discount);
                    } else if (request.discountAmount != null && request.discountAmount > 0) {
                        totalAmount -= request.discountAmount;
                        System.debug('Discount: -$' + request.discountAmount);
                    }
                    System.debug('Total: $' + totalAmount);
                }

                // Create mock response
                response.quickBooksEstimateId = 'EST-' + DateTime.now().getTime();
                response.quickBooksEstimateNumber = 'EST-' + String.valueOf(Math.random()).substring(2, 8);
                response.success = true;
                response.message = 'Estimate created successfully (Mock) - Customer: ' +
                    (String.isNotBlank(request.customerName) ? request.customerName : request.customerRef);

                // Update Opportunity with estimate ID if field exists
                if (request.opportunityId != null) {
                    try {
                        Opportunity opp = new Opportunity(Id = request.opportunityId);
                        opp.put('QuickBooks_Estimate_Id__c', response.quickBooksEstimateId);
                        update opp;
                    } catch (Exception e) {
                        System.debug('Note: Could not update Opportunity with estimate ID: ' + e.getMessage());
                    }
                }

                // Log success
                logIntegration('Create Estimate', 'Success', request.opportunityId, response.message);

            } catch (Exception e) {
                response.success = false;
                response.message = 'Error: ' + e.getMessage();
                logIntegration('Create Estimate', 'Error', request.opportunityId, e.getMessage());
            }

            responses.add(response);
        }

        return responses;
    }

    /**
     * Log integration activity
     */
    private static void logIntegration(String context, String status, Id recordId, String message) {
        try {
            Integration_Log__c log = new Integration_Log__c();
            log.put('Integration_Type__c', 'QuickBooks');
            log.put('Context__c', context);
            log.put('Status__c', status);
            log.put('Record_Id__c', recordId);
            log.put('Error_Message__c', message);
            log.put('Timestamp__c', DateTime.now());
            insert log;
        } catch (Exception e) {
            System.debug('Could not create integration log: ' + e.getMessage());
        }
    }
}