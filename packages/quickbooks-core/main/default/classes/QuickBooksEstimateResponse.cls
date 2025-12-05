public class QuickBooksEstimateResponse {
    @InvocableVariable(label='Success') @AuraEnabled public Boolean success;
    @InvocableVariable(label='Message') @AuraEnabled public String message;
    @InvocableVariable(label='QuickBooks Estimate ID') @AuraEnabled public String quickBooksEstimateId;
    @InvocableVariable(label='QuickBooks Estimate Number') @AuraEnabled public String quickBooksEstimateNumber;
    @InvocableVariable(label='Salesforce Opportunity ID') @AuraEnabled public Id salesforceOpportunityId;
}