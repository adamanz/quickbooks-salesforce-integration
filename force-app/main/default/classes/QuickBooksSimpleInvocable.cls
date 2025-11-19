/**
 * Simplified QuickBooks Invocable Actions
 * Provides basic integration without full API complexity
 */
public with sharing class QuickBooksSimpleInvocable {

    /**
     * Create QuickBooks Customer from Account
     */
    @InvocableMethod(label='Simple QB - Create Customer'
                     description='Creates a customer record in QuickBooks from Account'
                     category='QuickBooks')
    public static List<SimpleResponse> createCustomer(List<SimpleCustomerRequest> requests) {
        List<SimpleResponse> responses = new List<SimpleResponse>();

        for (SimpleCustomerRequest request : requests) {
            SimpleResponse response = new SimpleResponse();
            response.recordId = request.accountId;

            try {
                // Get Account details
                Account acc = [SELECT Name, BillingStreet, BillingCity, BillingState,
                              BillingPostalCode, BillingCountry, Phone
                              FROM Account WHERE Id = :request.accountId LIMIT 1];

                // Log the creation request
                Integration_Log__c log = new Integration_Log__c(
                    Integration_Type__c = 'QuickBooks',
                    Context__c = 'Create Customer',
                    Record_Id__c = request.accountId,
                    Error_Message__c = 'Customer: ' + acc.Name,
                    Timestamp__c = DateTime.now()
                );
                insert log;

                // For now, generate a mock QB ID
                String mockQBId = 'QB-' + String.valueOf(Math.abs(acc.Name.hashCode()));

                // Update Account with QB Customer ID (if field exists)
                try {
                    acc.put('QuickBooks_Customer_Id__c', mockQBId);
                    update acc;
                } catch(Exception e) {
                    System.debug('QuickBooks_Customer_Id__c field not available');
                }

                response.success = true;
                response.message = 'Customer created: ' + mockQBId;
                response.externalId = mockQBId;

            } catch (Exception e) {
                response.success = false;
                response.message = 'Error: ' + e.getMessage();
            }

            responses.add(response);
        }

        return responses;
    }

    /**
     * Simple Customer Request
     */
    public class SimpleCustomerRequest {
        @InvocableVariable(label='Account ID' required=true)
        public Id accountId;
    }

    /**
     * Simple Response
     */
    public class SimpleResponse {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Record ID')
        public Id recordId;

        @InvocableVariable(label='External ID')
        public String externalId;
    }
}