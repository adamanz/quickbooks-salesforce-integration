/**
 * QuickBooks Estimate Request
 * Used for creating estimates in QuickBooks
 */
public class QuickBooksEstimateRequest {
    @InvocableVariable(label='Salesforce Opportunity ID' required=true) @AuraEnabled public Id opportunityId;
    @InvocableVariable(label='QuickBooks Company ID' required=true) @AuraEnabled public String companyId;
    @InvocableVariable(label='QuickBooks Customer ID' required=true) @AuraEnabled public String customerRef;
    @InvocableVariable(label='Customer Name') @AuraEnabled public String customerName;

    // Line items - JSON string that will be parsed
    @InvocableVariable(label='Line Items JSON') @AuraEnabled public String lineItemsJson;

    // Discount fields
    @InvocableVariable(label='Discount Percent') @AuraEnabled public Decimal discountPercent;
    @InvocableVariable(label='Discount Amount') @AuraEnabled public Decimal discountAmount;
    @InvocableVariable(label='Apply Tax After Discount') @AuraEnabled public Boolean applyTaxAfterDiscount;

    // Date fields
    @InvocableVariable(label='Estimate Date') @AuraEnabled public Date estimateDate;
    @InvocableVariable(label='Expiration Date') @AuraEnabled public Date expirationDate;

    // Reference fields
    @InvocableVariable(label='Reference Number') @AuraEnabled public String referenceNumber;
    @InvocableVariable(label='Customer Memo') @AuraEnabled public String customerMemo;
    @InvocableVariable(label='Private Memo') @AuraEnabled public String privateMemo;

    // Address fields
    @InvocableVariable(label='Bill To Address') @AuraEnabled public String billToAddress;
    @InvocableVariable(label='Ship To Address') @AuraEnabled public String shipToAddress;
    @InvocableVariable(label='Email') @AuraEnabled public String customerEmail;

    // Currency and tax
    @InvocableVariable(label='Currency Code') @AuraEnabled public String currencyRef;
    @InvocableVariable(label='Tax Code') @AuraEnabled public String taxCodeRef;

    // Transient property for line items (not invocable)
    public transient List<QuickBooksEstimateLineItem> lineItems;

    // Method to parse line items from JSON
    public void parseLineItems() {
        if (String.isNotBlank(this.lineItemsJson)) {
            try {
                this.lineItems = (List<QuickBooksEstimateLineItem>)
                    JSON.deserialize(this.lineItemsJson, List<QuickBooksEstimateLineItem>.class);
            } catch (Exception e) {
                System.debug('Error parsing line items: ' + e.getMessage());
                this.lineItems = new List<QuickBooksEstimateLineItem>();
            }
        }
    }
}