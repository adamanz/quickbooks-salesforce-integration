/**
 * Simplified QuickBooks Estimate Invocable Action
 * Uses existing QuickBooksAPIServiceSimple for API calls
 */
public with sharing class QuickBooksEstimateSimpleInvocable {

    @InvocableMethod(label='Create QuickBooks Estimate (Simple)'
                     description='Creates an estimate in QuickBooks from Opportunity'
                     category='QuickBooks Integration')
    public static List<QuickBooksEstimateResponse> createEstimate(List<EstimateRequest> requests) {
        List<QuickBooksEstimateResponse> responses = new List<QuickBooksEstimateResponse>();

        for (EstimateRequest req : requests) {
            QuickBooksEstimateResponse response = new QuickBooksEstimateResponse();

            try {
                // Build estimate body
                Map<String, Object> estimateData = new Map<String, Object>{
                    'CustomerRef' => new Map<String, Object>{'value' => req.customerId},
                    'Line' => new List<Map<String, Object>>{
                        new Map<String, Object>{
                            'Amount' => req.amount,
                            'DetailType' => 'SalesItemLineDetail',
                            'SalesItemLineDetail' => new Map<String, Object>{
                                'ItemRef' => new Map<String, Object>{'value' => '1'} // Default item
                            }
                        }
                    }
                };

                if (String.isNotBlank(req.customerMemo)) {
                    estimateData.put('CustomerMemo', new Map<String, Object>{'value' => req.customerMemo});
                }

                // Create estimate using existing API service
                String jsonBody = JSON.serialize(estimateData);
                HttpResponse apiResponse = QuickBooksAPIServiceSimple.makeAPICall(
                    'POST',
                    'estimate',
                    jsonBody,
                    req.companyId
                );

                if (apiResponse.getStatusCode() == 200 || apiResponse.getStatusCode() == 201) {
                    Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(apiResponse.getBody());
                    Map<String, Object> estimate = (Map<String, Object>) result.get('Estimate');

                    response.success = true;
                    response.quickBooksEstimateId = String.valueOf(estimate.get('Id'));
                    response.quickBooksEstimateNumber = String.valueOf(estimate.get('DocNumber'));
                    response.message = 'Estimate created successfully';
                } else {
                    response.success = false;
                    response.message = 'API Error: ' + apiResponse.getBody();
                }

            } catch (Exception e) {
                response.success = false;
                response.message = 'Error: ' + e.getMessage();
            }

            responses.add(response);
        }

        return responses;
    }

    // Input wrapper class
    public class EstimateRequest {
        @InvocableVariable(label='Company ID' required=true)
        public String companyId;

        @InvocableVariable(label='Customer ID' required=true)
        public String customerId;

        @InvocableVariable(label='Amount' required=true)
        public Decimal amount;

        @InvocableVariable(label='Customer Memo')
        public String customerMemo;

        @InvocableVariable(label='Opportunity ID')
        public String opportunityId;
    }
}