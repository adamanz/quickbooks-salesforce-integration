/**
 * QuickBooks Customer Invocable Action
 * Wrapper for creating customers via Flow
 */
public with sharing class QuickBooksCustomerInvocable {

    @InvocableMethod(label='Create QuickBooks Customer'
                     description='Creates a customer in QuickBooks from Salesforce Account'
                     category='QuickBooks Integration')
    public static List<QuickBooksCustomerResponse> createCustomer(List<QuickBooksCustomerRequest> requests) {
        return QuickBooksAPIServiceSimple.createCustomer(requests);
    }
}