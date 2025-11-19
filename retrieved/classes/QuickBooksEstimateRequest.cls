public class QuickBooksEstimateRequest {
    @InvocableVariable(label='Salesforce Opportunity ID' required=true) @AuraEnabled public Id opportunityId;
    @InvocableVariable(label='QuickBooks Company ID' required=true) @AuraEnabled public String companyId;
    // Line items are not supported in invocable variables - will be handled separately
    @InvocableVariable(label='Discount Amount') @AuraEnabled public Decimal discountAmount;
    @InvocableVariable(label='Apply Tax After Discount') @AuraEnabled public Boolean applyTaxAfterDiscount;
    @InvocableVariable(label='Estimate Date') @AuraEnabled public Date estimateDate;
    @InvocableVariable(label='Expiration Date') @AuraEnabled public Date expirationDate;
    @InvocableVariable(label='Reference Number') @AuraEnabled public String referenceNumber;
    @InvocableVariable(label='Customer Memo') @AuraEnabled public String customerMemo;
    @InvocableVariable(label='Private Memo') @AuraEnabled public String privateMemo;
    @InvocableVariable(label='Ship To Address') @AuraEnabled public String shipToAddress;
}