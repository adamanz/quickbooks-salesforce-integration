public class QuickBooksInvoiceRequest {
    @InvocableVariable(label='Salesforce Opportunity ID' required=true) @AuraEnabled public Id opportunityId;
    @InvocableVariable(label='QuickBooks Company ID' required=true) @AuraEnabled public String companyId;
}