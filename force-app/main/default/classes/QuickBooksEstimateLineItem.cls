/**
 * QuickBooks Estimate Line Item
 * Represents a single line item in an estimate
 */
public class QuickBooksEstimateLineItem {
    @AuraEnabled public String description;
    @AuraEnabled public String itemName;
    @AuraEnabled public String itemRef; // QuickBooks Item ID
    @AuraEnabled public Decimal quantity;
    @AuraEnabled public Decimal unitPrice;
    @AuraEnabled public Decimal amount;
    @AuraEnabled public String taxCodeRef;
    @AuraEnabled public Decimal discountPercent;
    @AuraEnabled public Decimal discountAmount;
    @AuraEnabled public String detailType; // SalesItemLineDetail, GroupLineDetail, SubTotalLineDetail, or DiscountLineDetail
    @AuraEnabled public Integer lineNum;

    // Constructor
    public QuickBooksEstimateLineItem() {
        this.quantity = 1;
        this.detailType = 'SalesItemLineDetail';
    }

    // Constructor with parameters
    public QuickBooksEstimateLineItem(String description, Decimal quantity, Decimal unitPrice, String itemRef) {
        this.description = description;
        this.quantity = quantity;
        this.unitPrice = unitPrice;
        this.itemRef = itemRef;
        this.amount = quantity * unitPrice;
        this.detailType = 'SalesItemLineDetail';
    }

    // Calculate amount based on quantity and unit price
    public void calculateAmount() {
        if (this.quantity != null && this.unitPrice != null) {
            this.amount = this.quantity * this.unitPrice;
        }
    }
}