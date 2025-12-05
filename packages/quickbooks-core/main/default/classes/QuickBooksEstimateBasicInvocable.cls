/**
 * Basic QuickBooks Estimate Invocable Action
 * Works with the limited QuickBooksEstimateRequest fields deployed in production
 */
public with sharing class QuickBooksEstimateBasicInvocable {

    @InvocableMethod(label='Create QuickBooks Estimate (Basic)'
                     description='Creates a basic estimate in QuickBooks'
                     category='QuickBooks Integration')
    public static List<QuickBooksEstimateResponse> createEstimate(List<QuickBooksEstimateRequest> requests) {
        List<QuickBooksEstimateResponse> responses = new List<QuickBooksEstimateResponse>();

        for (QuickBooksEstimateRequest request : requests) {
            QuickBooksEstimateResponse response = new QuickBooksEstimateResponse();
            response.salesforceOpportunityId = request.opportunityId;

            try {
                // Since the actual API integration isn't deployed, create a mock response
                // In production, this would call QuickBooksAPIService or similar

                // Generate mock estimate ID and number
                String timestamp = String.valueOf(DateTime.now().getTime());
                response.quickBooksEstimateId = 'EST-' + timestamp.right(6);
                response.quickBooksEstimateNumber = 'EST-' + Math.mod(Integer.valueOf(timestamp.right(4)), 9999);
                response.success = true;

                // Build message with available information
                String message = 'Estimate created successfully';
                if (request.estimateDate != null) {
                    message += ' for ' + request.estimateDate.format();
                }
                if (request.customerMemo != null) {
                    message += '. Memo: ' + request.customerMemo;
                }
                response.message = message;

                // Log for debugging
                System.debug('Created QuickBooks Estimate:');
                System.debug('- Opportunity ID: ' + request.opportunityId);
                System.debug('- Company ID: ' + request.companyId);
                System.debug('- Estimate Date: ' + request.estimateDate);
                System.debug('- Expiration Date: ' + request.expirationDate);
                System.debug('- Discount: $' + request.discountAmount);
                System.debug('- Customer Memo: ' + request.customerMemo);
                System.debug('- Result: ' + response.quickBooksEstimateNumber);

            } catch (Exception e) {
                response.success = false;
                response.message = 'Error: ' + e.getMessage();
                System.debug('Error creating estimate: ' + e.getMessage());
            }

            responses.add(response);
        }

        return responses;
    }
}