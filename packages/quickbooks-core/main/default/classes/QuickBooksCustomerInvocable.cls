/**
 * QuickBooks Customer Invocable Action
 * Wrapper for finding or creating customers via Flow
 * Returns existing customer ID if found, creates new if not
 */
public with sharing class QuickBooksCustomerInvocable {

    @InvocableMethod(label='Create QuickBooks Customer'
                     description='Finds existing or creates new customer in QuickBooks from Salesforce Account'
                     category='QuickBooks Integration')
    public static List<QuickBooksCustomerResponse> createCustomer(List<QuickBooksCustomerRequest> requests) {
        return QuickBooksAPIService.createCustomer(requests);
    }
}