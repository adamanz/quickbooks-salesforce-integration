/**
 * Simplified QuickBooks API Service for deployment
 */
public with sharing class QuickBooksAPIServiceSimple {

    /**
     * Create Customer from Account - Simple Implementation
     */
    public static List<QuickBooksCustomerResponse> createCustomer(List<QuickBooksCustomerRequest> requests) {
        List<QuickBooksCustomerResponse> responses = new List<QuickBooksCustomerResponse>();

        for (QuickBooksCustomerRequest request : requests) {
            QuickBooksCustomerResponse response = new QuickBooksCustomerResponse();
            response.salesforceAccountId = request.accountId;

            try {
                // Log all customer details for debugging
                System.debug('Creating QuickBooks Customer with:');
                System.debug('- Full Name: ' + request.fullName);
                System.debug('- Display Name: ' + request.displayName);
                System.debug('- First Name: ' + request.firstName);
                System.debug('- Last Name: ' + request.lastName);
                System.debug('- Company: ' + request.companyName);
                System.debug('- Email: ' + request.email);
                System.debug('- Phone: ' + request.phone);

                // For now, create a mock response
                response.quickBooksCustomerId = 'QB-' + DateTime.now().getTime();
                response.success = true;
                response.message = 'Customer created successfully (Mock) - ' +
                    'Name: ' + (String.isNotBlank(request.displayName) ? request.displayName : request.fullName);

                // Update Account with QB ID if field exists
                if (request.accountId != null) {
                    Account acc = new Account(Id = request.accountId);
                    acc.put('QuickBooks_Customer_Id__c', response.quickBooksCustomerId);
                    update acc;
                }
            } catch (Exception e) {
                response.success = false;
                response.message = 'Error: ' + e.getMessage();
            }

            responses.add(response);
        }

        return responses;
    }

    /**
     * Create Estimate - Simple Implementation with line items support
     */
    public static List<QuickBooksEstimateResponse> createEstimate(List<QuickBooksEstimateRequest> requests) {
        List<QuickBooksEstimateResponse> responses = new List<QuickBooksEstimateResponse>();

        for (QuickBooksEstimateRequest request : requests) {
            QuickBooksEstimateResponse response = new QuickBooksEstimateResponse();
            response.salesforceOpportunityId = request.opportunityId;

            try {
                // Parse line items if JSON provided
                if (String.isNotBlank(request.lineItemsJson)) {
                    request.parseLineItems();
                }

                // Log estimate details
                System.debug('Creating Estimate with ' +
                    (request.lineItems != null ? request.lineItems.size() : 0) + ' line items');

                // Mock response
                response.quickBooksEstimateId = 'EST-' + DateTime.now().getTime();
                response.quickBooksEstimateNumber = 'EST-' + String.valueOf(Math.random()).substring(2, 8);
                response.success = true;
                response.message = 'Estimate created successfully (Mock) for Customer: ' + request.customerRef;
            } catch (Exception e) {
                response.success = false;
                response.message = 'Error: ' + e.getMessage();
            }

            responses.add(response);
        }

        return responses;
    }

    /**
     * Create Invoice - Simple Implementation
     */
    public static QuickBooksInvoiceResponse createInvoice(QuickBooksInvoiceRequest request) {
        QuickBooksInvoiceResponse response = new QuickBooksInvoiceResponse();
        response.salesforceOpportunityId = request.opportunityId;

        try {
            // Mock response
            response.quickBooksInvoiceId = 'INV-' + DateTime.now().getTime();
            response.quickBooksInvoiceNumber = 'INV-0000001';
            response.success = true;
            response.message = 'Invoice created successfully (Mock)';
        } catch (Exception e) {
            response.success = false;
            response.message = 'Error: ' + e.getMessage();
        }

        return response;
    }
}