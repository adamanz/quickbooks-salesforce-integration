public class QuickBooksCustomerResponse {
    @InvocableVariable(label='Success') @AuraEnabled public Boolean success;
    @InvocableVariable(label='Message') @AuraEnabled public String message;
    @InvocableVariable(label='QuickBooks Customer ID') @AuraEnabled public String quickBooksCustomerId;
    @InvocableVariable(label='Salesforce Account ID') @AuraEnabled public Id salesforceAccountId;
}