/**
 * QuickBooks Invoice Invocable Action
 * Wrapper for creating invoices via Flow
 */
public with sharing class QuickBooksInvoiceInvocable {

    @InvocableMethod(label='Create QuickBooks Invoice'
                     description='Creates an invoice in QuickBooks from Salesforce Opportunity'
                     category='QuickBooks Integration')
    public static List<QuickBooksInvoiceResponse> createInvoice(List<QuickBooksInvoiceRequest> requests) {
        return QuickBooksAPIService.createInvoice(requests);
    }
}