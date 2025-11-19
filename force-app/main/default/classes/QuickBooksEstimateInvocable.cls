/**
 * QuickBooks Estimate Invocable Service
 * Provides invocable action for creating QuickBooks Estimates from Salesforce Flow
 */
public with sharing class QuickBooksEstimateInvocable {

    /**
     * Invocable method to create QuickBooks estimates
     * Callable directly from Lightning Flow Builder
     */
    @InvocableMethod(label='Create QuickBooks Estimate'
                     description='Creates an estimate in QuickBooks with multiple line items'
                     category='QuickBooks')
    public static List<QuickBooksEstimateResponse> createEstimate(List<QuickBooksEstimateRequest> requests) {
        List<QuickBooksEstimateResponse> responses = new List<QuickBooksEstimateResponse>();

        for (QuickBooksEstimateRequest request : requests) {
            QuickBooksEstimateResponse response = new QuickBooksEstimateResponse();
            response.salesforceOpportunityId = request.opportunityId;

            try {
                // Get Opportunity and related data
                Opportunity opp = getOpportunityWithLineItems(request.opportunityId);

                // Get customer ID from Account field or from request
                String customerIdValue = getCustomerIdFromAccount(opp.AccountId);

                // Allow request.customerRef to override if Account field is not set
                if (String.isBlank(customerIdValue) && String.isNotBlank(request.customerRef)) {
                    customerIdValue = request.customerRef;
                }

                if (String.isBlank(customerIdValue)) {
                    throw new QuickBooksException('Must provide customerRef in request or Account must have QuickBooks_Customer_Id__c field set. Please create the customer first using "Create QuickBooks Customer" action.');
                }

                // Build estimate data with line items
                Map<String, Object> estimateData = buildEstimateData(opp, request, customerIdValue);

                // Make API call
                String endpoint = getBaseUrl(request.companyId) + '/v3/company/' +
                                request.companyId + '/estimate';

                HttpResponse httpResponse = makeAPICall(
                    'POST',
                    endpoint,
                    JSON.serialize(estimateData),
                    request.companyId
                );

                if (httpResponse.getStatusCode() == 200) {
                    Map<String, Object> result = (Map<String, Object>)
                        JSON.deserializeUntyped(httpResponse.getBody());
                    Map<String, Object> estimate = (Map<String, Object>) result.get('Estimate');

                    response.quickBooksEstimateId = (String) estimate.get('Id');
                    response.quickBooksEstimateNumber = (String) estimate.get('DocNumber');
                    response.success = true;
                    response.message = 'Estimate created successfully';
                } else {
                    handleAPIError(httpResponse, response);
                }
            } catch (Exception e) {
                response.success = false;
                response.message = 'Error: ' + e.getMessage();
                logError('Create Estimate', e.getMessage(), request.opportunityId);
            }

            responses.add(response);
        }

        return responses;
    }

    /**
     * Get customer ID from Account with graceful fallback
     */
    private static String getCustomerIdFromAccount(Id accountId) {
        try {
            Account acc = [SELECT Id FROM Account WHERE Id = :accountId LIMIT 1];
            // Try to access the field - if it doesn't exist in org, return null gracefully
            Map<String, Object> accFields = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(acc));
            Object custId = accFields.get('QuickBooks_Customer_Id__c');
            return custId != null ? String.valueOf(custId) : null;
        } catch (Exception e) {
            System.debug('Error getting customer ID: ' + e.getMessage());
            return null;
        }
    }

    /**
     * Build estimate data for QuickBooks API with line items and discount
     */
    private static Map<String, Object> buildEstimateData(Opportunity opp, QuickBooksEstimateRequest request, String customerId) {
        Map<String, Object> estimate = new Map<String, Object>();

        // Customer reference
        Map<String, Object> customerRef = new Map<String, Object>();
        customerRef.put('value', customerId);
        if (String.isNotBlank(request.customerName)) {
            customerRef.put('name', request.customerName);
        }
        estimate.put('CustomerRef', customerRef);

        // Line items array - QuickBooks expects 'Line' not 'itemLines'
        List<Map<String, Object>> lines = new List<Map<String, Object>>();
        Decimal subtotal = 0;

        // Parse line items from JSON if provided
        if (String.isNotBlank(request.lineItemsJson)) {
            request.parseLineItems();
        }

        if (request.lineItems != null && !request.lineItems.isEmpty()) {
            // Use line items passed from Flow
            Integer lineNum = 1;
            for (QuickBooksEstimateLineItem lineItem : request.lineItems) {
                Map<String, Object> line = buildQuickBooksLineItem(lineItem, lineNum);
                lines.add(line);
                subtotal += lineItem.amount != null ? lineItem.amount : (lineItem.quantity * lineItem.unitPrice);
                lineNum++;
            }
        } else if (opp.OpportunityLineItems != null && !opp.OpportunityLineItems.isEmpty()) {
            // Fall back to Opportunity line items
            Integer lineNum = 1;
            for (OpportunityLineItem oli : opp.OpportunityLineItems) {
                Map<String, Object> line = new Map<String, Object>();
                line.put('LineNum', lineNum);
                line.put('Amount', oli.TotalPrice);
                line.put('Description', oli.Product2.Name);
                line.put('DetailType', 'SalesItemLineDetail');

                Map<String, Object> detail = new Map<String, Object>();
                detail.put('Qty', oli.Quantity);
                detail.put('UnitPrice', oli.UnitPrice);

                // Try to get QB Item ID if it exists
                try {
                    Map<String, Object> prodFields = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(oli.Product2));
                    Object qbItemId = prodFields.get('QuickBooks_Item_Id__c');
                    if (qbItemId != null) {
                        Map<String, Object> itemRef = new Map<String, Object>();
                        itemRef.put('value', qbItemId);
                        itemRef.put('name', oli.Product2.Name);
                        detail.put('ItemRef', itemRef);
                    }
                } catch (Exception e) {
                    System.debug('Note: Could not get QB Item ID: ' + e.getMessage());
                }

                // Tax code reference
                if (String.isNotBlank(request.taxCodeRef)) {
                    Map<String, Object> taxCodeRef = new Map<String, Object>();
                    taxCodeRef.put('value', request.taxCodeRef);
                    detail.put('TaxCodeRef', taxCodeRef);
                }

                line.put('SalesItemLineDetail', detail);
                lines.add(line);
                subtotal += oli.TotalPrice;
                lineNum++;
            }
        }

        // Add SubTotal line
        if (!lines.isEmpty()) {
            Map<String, Object> subTotalLine = new Map<String, Object>();
            subTotalLine.put('DetailType', 'SubTotalLineDetail');
            subTotalLine.put('Amount', subtotal);
            subTotalLine.put('SubTotalLineDetail', new Map<String, Object>());
            lines.add(subTotalLine);
        }

        // Add Discount line if applicable
        if ((request.discountPercent != null && request.discountPercent > 0) ||
            (request.discountAmount != null && request.discountAmount > 0)) {
            Map<String, Object> discountLine = new Map<String, Object>();
            discountLine.put('DetailType', 'DiscountLineDetail');

            Map<String, Object> discountDetail = new Map<String, Object>();

            if (request.discountPercent != null && request.discountPercent > 0) {
                discountDetail.put('PercentBased', true);
                discountDetail.put('DiscountPercent', request.discountPercent);
                discountLine.put('Amount', subtotal * request.discountPercent / 100);
            } else {
                discountDetail.put('PercentBased', false);
                discountLine.put('Amount', request.discountAmount);
            }

            discountLine.put('DiscountLineDetail', discountDetail);
            lines.add(discountLine);
        }

        estimate.put('Line', lines);

        // Apply Tax After Discount setting
        if (request.applyTaxAfterDiscount != null) {
            estimate.put('ApplyTaxAfterDiscount', request.applyTaxAfterDiscount);
        }

        // Transaction date
        if (request.estimateDate != null) {
            estimate.put('TxnDate', String.valueOf(request.estimateDate));
        } else {
            estimate.put('TxnDate', String.valueOf(Date.today()));
        }

        // Expiration date (default: 30 days)
        if (request.expirationDate != null) {
            estimate.put('ExpirationDate', String.valueOf(request.expirationDate));
        } else {
            estimate.put('ExpirationDate', String.valueOf(Date.today().addDays(30)));
        }

        // Reference number (optional)
        if (String.isNotBlank(request.referenceNumber)) {
            estimate.put('DocNumber', request.referenceNumber);
        }

        // Customer memo (optional)
        if (String.isNotBlank(request.customerMemo)) {
            Map<String, Object> memo = new Map<String, Object>();
            memo.put('value', request.customerMemo);
            estimate.put('CustomerMemo', memo);
        }

        // Private memo (optional)
        if (String.isNotBlank(request.privateMemo)) {
            Map<String, Object> memo = new Map<String, Object>();
            memo.put('value', request.privateMemo);
            estimate.put('PrivateMemo', memo);
        }

        // Bill Email (optional)
        if (String.isNotBlank(request.customerEmail)) {
            Map<String, Object> billEmail = new Map<String, Object>();
            billEmail.put('Address', request.customerEmail);
            estimate.put('BillEmail', billEmail);
        }

        // Billing address (optional)
        if (String.isNotBlank(request.billToAddress)) {
            Map<String, Object> billAddr = new Map<String, Object>();
            // Parse address if it contains multiple parts separated by comma
            String[] addressParts = request.billToAddress.split(',');
            if (addressParts.size() > 0) billAddr.put('Line1', addressParts[0].trim());
            if (addressParts.size() > 1) billAddr.put('City', addressParts[1].trim());
            if (addressParts.size() > 2) billAddr.put('CountrySubDivisionCode', addressParts[2].trim());
            if (addressParts.size() > 3) billAddr.put('PostalCode', addressParts[3].trim());
            estimate.put('BillAddr', billAddr);
        }

        // Shipping address (optional)
        if (String.isNotBlank(request.shipToAddress)) {
            Map<String, Object> shipAddr = new Map<String, Object>();
            // Parse address if it contains multiple parts separated by comma
            String[] addressParts = request.shipToAddress.split(',');
            if (addressParts.size() > 0) shipAddr.put('Line1', addressParts[0].trim());
            if (addressParts.size() > 1) shipAddr.put('City', addressParts[1].trim());
            if (addressParts.size() > 2) shipAddr.put('CountrySubDivisionCode', addressParts[2].trim());
            if (addressParts.size() > 3) shipAddr.put('PostalCode', addressParts[3].trim());
            estimate.put('ShipAddr', shipAddr);
        }

        // Currency reference (for multi-currency companies)
        if (String.isNotBlank(request.currencyRef)) {
            Map<String, Object> currencyRef = new Map<String, Object>();
            currencyRef.put('value', request.currencyRef);
            estimate.put('CurrencyRef', currencyRef);
        }

        // Tax detail (if needed)
        Map<String, Object> txnTaxDetail = new Map<String, Object>();
        txnTaxDetail.put('TotalTax', 0); // You can calculate this if needed
        estimate.put('TxnTaxDetail', txnTaxDetail);

        return estimate;
    }

    /**
     * Build individual QuickBooks line item with proper format
     */
    private static Map<String, Object> buildQuickBooksLineItem(QuickBooksEstimateLineItem lineItem, Integer lineNum) {
        Map<String, Object> line = new Map<String, Object>();

        line.put('LineNum', lineNum);
        line.put('Amount', lineItem.amount != null ? lineItem.amount : (lineItem.quantity * lineItem.unitPrice));

        if (String.isNotBlank(lineItem.description)) {
            line.put('Description', lineItem.description);
        }

        // Determine detail type
        String detailType = String.isNotBlank(lineItem.detailType) ? lineItem.detailType : 'SalesItemLineDetail';
        line.put('DetailType', detailType);

        // Build the detail object based on type
        if (detailType == 'SalesItemLineDetail') {
            Map<String, Object> detail = new Map<String, Object>();
            detail.put('Qty', lineItem.quantity != null ? lineItem.quantity : 1);
            detail.put('UnitPrice', lineItem.unitPrice != null ? lineItem.unitPrice : 0);

            // Item reference
            if (String.isNotBlank(lineItem.itemRef)) {
                Map<String, Object> itemRef = new Map<String, Object>();
                itemRef.put('value', lineItem.itemRef);
                if (String.isNotBlank(lineItem.itemName)) {
                    itemRef.put('name', lineItem.itemName);
                }
                detail.put('ItemRef', itemRef);
            }

            // Tax code reference
            if (String.isNotBlank(lineItem.taxCodeRef)) {
                Map<String, Object> taxCodeRef = new Map<String, Object>();
                taxCodeRef.put('value', lineItem.taxCodeRef);
                detail.put('TaxCodeRef', taxCodeRef);
            }

            line.put('SalesItemLineDetail', detail);
        } else if (detailType == 'GroupLineDetail') {
            Map<String, Object> detail = new Map<String, Object>();
            // Add group-specific fields as needed
            line.put('GroupLineDetail', detail);
        }

        return line;
    }

    /**
     * Make HTTP callout to QuickBooks API
     */
    private static HttpResponse makeAPICall(String method, String endpoint,
                                           String body, String companyId) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();

        request.setEndpoint(endpoint);
        request.setMethod(method);
        request.setHeader('Accept', 'application/json');
        request.setHeader('Content-Type', 'application/json');

        // Get valid access token
        String accessToken = QuickBooksAuthProvider.getValidAccessToken(companyId);
        request.setHeader('Authorization', 'Bearer ' + accessToken);

        if (body != null) {
            request.setBody(body);
        }

        request.setTimeout(120000); // 2 minutes timeout

        return http.send(request);
    }

    /**
     * Get Opportunity with line items
     */
    private static Opportunity getOpportunityWithLineItems(Id oppId) {
        return [
            SELECT Id, Name, AccountId, Amount, CloseDate, StageName,
                   (SELECT Id, Product2Id, Product2.Name,
                           Quantity, UnitPrice, TotalPrice
                    FROM OpportunityLineItems)
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];
    }

    /**
     * Handle API error response
     */
    private static void handleAPIError(HttpResponse response, QuickBooksEstimateResponse responseObj) {
        Map<String, Object> error = (Map<String, Object>)
            JSON.deserializeUntyped(response.getBody());

        String errorMessage = 'API Error: ' + response.getStatus() + ' - ';

        if (error.containsKey('Fault')) {
            Map<String, Object> fault = (Map<String, Object>) error.get('Fault');
            if (fault.containsKey('Error')) {
                List<Object> errors = (List<Object>) fault.get('Error');
                if (!errors.isEmpty()) {
                    Map<String, Object> firstError = (Map<String, Object>) errors[0];
                    errorMessage += firstError.get('Message');
                }
            }
        } else {
            errorMessage += response.getBody();
        }

        responseObj.success = false;
        responseObj.message = errorMessage;
    }

    /**
     * Get base URL based on environment
     */
    private static String getBaseUrl(String companyId) {
        QuickBooks_Config__mdt config = QuickBooks_Config__mdt.getInstance('Default');
        String baseUrl = config.Is_Sandbox__c ? 'https://sandbox-quickbooks.api.intuit.com' : 'https://quickbooks.api.intuit.com';
        return baseUrl;
    }

    /**
     * Log error to custom object
     */
    private static void logError(String context, String message, Id recordId) {
        Integration_Log__c log = new Integration_Log__c(
            Integration_Type__c = 'QuickBooks',
            Context__c = context,
            Error_Message__c = message,
            Record_Id__c = recordId,
            Timestamp__c = DateTime.now()
        );
        insert log;
    }

    public class QuickBooksException extends Exception {}
}