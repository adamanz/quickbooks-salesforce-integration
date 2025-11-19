public class QuickBooksInvoiceResponse {
    @InvocableVariable(label='Success') @AuraEnabled public Boolean success;
    @InvocableVariable(label='Message') @AuraEnabled public String message;
    @InvocableVariable(label='QuickBooks Invoice ID') @AuraEnabled public String quickBooksInvoiceId;
    @InvocableVariable(label='QuickBooks Invoice Number') @AuraEnabled public String quickBooksInvoiceNumber;
    @InvocableVariable(label='Salesforce Opportunity ID') @AuraEnabled public Id salesforceOpportunityId;
}