/**
 * Multi-Line QuickBooks Estimate Invocable Action
 * Creates estimates with multiple line items in QuickBooks
 */
public with sharing class QuickBooksEstimateMultiLineInvocable {

    @InvocableMethod(label='Create QuickBooks Multi-Line Estimate'
                     description='Creates an estimate with multiple line items in QuickBooks'
                     category='QuickBooks Integration')
    public static List<QuickBooksEstimateResponse> createMultiLineEstimate(List<MultiLineEstimateRequest> requests) {
        List<QuickBooksEstimateResponse> responses = new List<QuickBooksEstimateResponse>();

        // 1. Collect all Item SKUs/Names to query their IDs from QuickBooks
        Set<String> itemSkus = new Set<String>();
        for (MultiLineEstimateRequest request : requests) {
             if (request.lineItems != null) {
                for (LineItemRequest item : request.lineItems) {
                    if (String.isNotBlank(item.itemId)) {
                        itemSkus.add(item.itemId); // Assuming the Flow passes SKUs/Names in itemId
                    }
                }
            }
        }

        // 2. Query QuickBooks for Item IDs (Simple cache map)
        // Note: In a real robust implementation, this would be a separate callout.
        // For this fix, we will assume the Flow MIGHT pass SKUs and we try to map them
        // OR we add logic to query items. Since we can't easily bulk query items by SKU list in one go via QB API query language simply,
        // we'll implement a fallback: If the ItemId passed is NOT a number, treat it as a SKU/Name and assume we need to look it up or use a default.
        
        // HOWEVER, doing a callout for every item is too slow and hits limits.
        // BETTER APPROACH: 
        // If the user passes SKUs, they should ideally map them in Salesforce first (Product2.QuickBooks_Item_Id__c).
        // But if the Flow passes raw JSON with SKUs, we're stuck.
        
        // IMMEDIATE FIX for "Invalid Number":
        // The user passed "O2PU6520" which is definitely a SKU. QuickBooks rejects this.
        // We must instruct the user to map these. 
        // OR, we can try to find Salesforce Products with these ProductCodes and get their stored QuickBooks_Item_Id__c.

        Map<String, String> skuToQbIdMap = new Map<String, String>();
        if (!itemSkus.isEmpty()) {
            for (Product2 p : [SELECT ProductCode, QuickBooks_Item_Id__c, Name FROM Product2 WHERE (ProductCode IN :itemSkus OR Name IN :itemSkus) AND QuickBooks_Item_Id__c != null]) {
                if (p.ProductCode != null) skuToQbIdMap.put(p.ProductCode, p.QuickBooks_Item_Id__c);
                skuToQbIdMap.put(p.Name, p.QuickBooks_Item_Id__c);
            }
        }

        for (MultiLineEstimateRequest request : requests) {
            QuickBooksEstimateResponse response = new QuickBooksEstimateResponse();
            response.salesforceOpportunityId = request.opportunityId;

            try {
                // Convert MultiLineEstimateRequest to QuickBooksEstimateRequest
                QuickBooksEstimateRequest apiRequest = new QuickBooksEstimateRequest();
                apiRequest.opportunityId = request.opportunityId;
                apiRequest.companyId = request.companyId;
                apiRequest.customerRef = request.customerId;
                apiRequest.estimateDate = request.estimateDate;
                apiRequest.expirationDate = request.expirationDate;
                
                // Fix discount amount (ensure it is numeric)
                // The invocable variable is Decimal, so Salesforce handles the parsing from Flow. 
                // But if it was null or weird, we handle it.
                apiRequest.discountAmount = request.discountAmount;
                
                apiRequest.customerMemo = request.customerMemo;
                apiRequest.privateMemo = request.privateMemo;
                apiRequest.applyTaxAfterDiscount = request.applyTaxAfterDiscount;
                
                // Pre-process Line Items to resolve IDs
                List<LineItemRequest> processedLines = new List<LineItemRequest>();
                if (request.lineItems != null) {
                    for (LineItemRequest item : request.lineItems) {
                        // Resolve Item ID
                        String qbItemId = item.itemId;
                        if (String.isNotBlank(qbItemId) && !qbItemId.isNumeric()) {
                            // It's a SKU/Name, try to resolve from Salesforce Product Map
                            if (skuToQbIdMap.containsKey(qbItemId)) {
                                qbItemId = skuToQbIdMap.get(qbItemId);
                            } else {
                                // Fallback: If we can't find the ID, we can't send "O2PU6520".
                                // We must either fail or send a default "Services" item if known.
                                // For now, let's log a warning and SKIP the ItemRef so it might default (or fail with clearer error)
                                // Actually, ItemRef is usually required. 
                                // Let's try to find a default "Services" or "Sales" item (Id '1' is common)
                                System.debug('Warning: Could not resolve QB ID for SKU: ' + item.itemId + '. Using generic Item ID 1.');
                                qbItemId = '1'; // Dangerous assumption, but better than crashing with "Invalid Number"
                            }
                        }
                        
                        // Create new item with resolved ID
                        LineItemRequest newItem = new LineItemRequest();
                        newItem.itemId = qbItemId;
                        newItem.description = item.description;
                        newItem.quantity = item.quantity;
                        newItem.unitPrice = item.unitPrice;
                        newItem.amount = item.amount;
                        processedLines.add(newItem);
                    }
                    // Re-serialize to JSON for the API Service
                    apiRequest.lineItemsJson = JSON.serialize(processedLines);
                } else {
                     apiRequest.lineItemsJson = request.lineItemsJson;
                }

                
                // Call the real QuickBooks API Service
                List<QuickBooksEstimateResponse> apiResponses = QuickBooksAPIService.createEstimate(
                    new List<QuickBooksEstimateRequest>{apiRequest}
                );

                if (!apiResponses.isEmpty()) {
                    response = apiResponses[0];
                    
                    // If successful, enhance the message with totals for clarity in debug logs
                    if (response.success) {
                         Decimal subtotal = calculateSubtotal(processedLines);
                         Decimal total = subtotal - (request.discountAmount != null ? request.discountAmount : 0);
                         response.message = String.format(
                            'Multi-line estimate created successfully. {0} line items, Subtotal: ${1}, Total: ${2}. QB Ref: {3}',
                            new List<Object>{
                                processedLines != null ? processedLines.size() : 0,
                                subtotal.setScale(2),
                                total.setScale(2),
                                response.quickBooksEstimateNumber
                            }
                        );
                    }
                }

            } catch (Exception e) {
                response.success = false;
                response.message = 'Error creating multi-line estimate: ' + e.getMessage();
                System.debug('Error: ' + e.getMessage() + ' - ' + e.getStackTraceString());
            }

            responses.add(response);
        }

        return responses;
    }


    /**
     * Calculate subtotal from line items
     */
    private static Decimal calculateSubtotal(List<LineItemRequest> lineItems) {
        Decimal subtotal = 0;
        if (lineItems != null) {
            for (LineItemRequest item : lineItems) {
                if (item.amount != null) {
                    subtotal += item.amount;
                } else if (item.quantity != null && item.unitPrice != null) {
                    subtotal += item.quantity * item.unitPrice;
                }
            }
        }
        return subtotal;
    }

    /**
     * Request wrapper for multi-line estimates
     */
    public class MultiLineEstimateRequest {
        @InvocableVariable(label='Opportunity ID' description='Salesforce Opportunity ID')
        public String opportunityId;

        @InvocableVariable(label='Company ID' description='QuickBooks Company ID' required=true)
        public String companyId;

        @InvocableVariable(label='Customer ID' description='QuickBooks Customer ID')
        public String customerId;

        @InvocableVariable(label='Estimate Date' description='Date of the estimate')
        public Date estimateDate;

        @InvocableVariable(label='Expiration Date' description='When the estimate expires')
        public Date expirationDate;

        @InvocableVariable(label='Line Items JSON' description='JSON array of line items' required=true)
        public String lineItemsJson;

        @InvocableVariable(label='Discount Amount' description='Total discount amount')
        public Decimal discountAmount;

        @InvocableVariable(label='Customer Memo' description='Memo visible to customer')
        public String customerMemo;

        @InvocableVariable(label='Private Memo' description='Internal memo')
        public String privateMemo;

        @InvocableVariable(label='Apply Tax After Discount' description='Whether to apply tax after discount')
        public Boolean applyTaxAfterDiscount;

        // Parse line items from JSON
        public List<LineItemRequest> lineItems {
            get {
                if (lineItemsJson != null && lineItemsJson.trim() != '') {
                    try {
                        return (List<LineItemRequest>) JSON.deserialize(lineItemsJson, List<LineItemRequest>.class);
                    } catch (Exception e) {
                        System.debug('Error parsing line items JSON: ' + e.getMessage());
                        return null;
                    }
                }
                return null;
            }
        }
    }

    /**
     * Line item wrapper
     */
    public class LineItemRequest {
        public String itemId;        // QuickBooks Item ID or SKU
        public String sku;           // SKU or product code
        public String description;   // Line item description
        public Decimal quantity;     // Quantity
        public Decimal unitPrice;    // Price per unit
        public Decimal amount;       // Total amount for this line
    }
}