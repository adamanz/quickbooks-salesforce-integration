/**
 * QuickBooks Estimate Invocable Service
 * Provides invocable action for creating QuickBooks Estimates from Salesforce Flow
 * Separated into its own class to comply with Salesforce's one @InvocableMethod per class requirement
 */
public with sharing class QuickBooksEstimateInvocable {

    /**
     * Invocable method to create QuickBooks estimates
     * Callable directly from Lightning Flow Builder
     */
    @InvocableMethod(label='Create QuickBooks Estimate'
                     description='Creates an estimate in QuickBooks with multiple line items'
                     category='QuickBooks')
    public static List<EstimateResponse> createEstimate(List<EstimateRequest> requests) {
        List<EstimateResponse> responses = new List<EstimateResponse>();

        for (EstimateRequest request : requests) {
            EstimateResponse response = new EstimateResponse();
            response.salesforceOpportunityId = request.opportunityId;

            try {
                // Get Opportunity and related data
                Opportunity opp = getOpportunityWithLineItems(request.opportunityId);

                // For now, assume customer is already created in QB
                // If customer ID is not present, this will fail at API call time
                String customerIdValue = getCustomerIdFromAccount(opp.AccountId);
                if (String.isBlank(customerIdValue)) {
                    throw new QuickBooksException('Account must have a QuickBooks Customer ID. Please create the customer first using "Create QuickBooks Customer" action.');
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
    private static Map<String, Object> buildEstimateData(Opportunity opp, EstimateRequest request, String customerId) {
        Map<String, Object> estimate = new Map<String, Object>();

        // Customer reference
        Map<String, Object> customerRef = new Map<String, Object>();
        customerRef.put('value', customerId);
        estimate.put('CustomerRef', customerRef);

        // Line items from Opportunity or from request
        List<Map<String, Object>> itemLines = new List<Map<String, Object>>();

        if (request.lineItems != null && !request.lineItems.isEmpty()) {
            // Use line items passed from Flow
            Integer sequence = 1;
            for (EstimateLineItem lineItem : request.lineItems) {
                Map<String, Object> line = buildEstimateLineItem(lineItem, sequence);
                itemLines.add(line);
                sequence++;
            }
        } else {
            // Fall back to Opportunity line items
            Integer sequence = 1;
            for (OpportunityLineItem oli : opp.OpportunityLineItems) {
                Map<String, Object> line = new Map<String, Object>();
                line.put('sequence', String.valueOf(sequence));
                line.put('amount', oli.TotalPrice);
                line.put('description', oli.Product2.Name);
                line.put('quantity', oli.Quantity);
                line.put('unitPrice', oli.UnitPrice);

                // Try to get QB Item ID if it exists
                try {
                    Map<String, Object> prodFields = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(oli.Product2));
                    Object qbItemId = prodFields.get('QuickBooks_Item_Id__c');
                    if (qbItemId != null) {
                        Map<String, Object> itemRef = new Map<String, Object>();
                        itemRef.put('value', qbItemId);
                        line.put('item', itemRef);
                    }
                } catch (Exception e) {
                    System.debug('Note: Could not get QB Item ID: ' + e.getMessage());
                }

                itemLines.add(line);
                sequence++;
            }
        }

        estimate.put('itemLines', itemLines);

        // Handle discount
        if (request.discountAmount != null && request.discountAmount > 0) {
            Map<String, Object> discount = new Map<String, Object>();
            Map<String, Object> discountAmount = new Map<String, Object>();
            discountAmount.put('value', request.discountAmount);
            discount.put('amount', discountAmount);
            discount.put('applyTaxAfterDiscount', request.applyTaxAfterDiscount != null ?
                                                 request.applyTaxAfterDiscount : true);
            estimate.put('discount', discount);
        }

        // Transaction date
        if (request.estimateDate != null) {
            estimate.put('TxnDate', request.estimateDate.format());
        } else {
            estimate.put('TxnDate', Date.today().format());
        }

        // Expiration date (default: 30 days)
        if (request.expirationDate != null) {
            estimate.put('ExpirationDate', request.expirationDate.format());
        } else {
            estimate.put('ExpirationDate', Date.today().addDays(30).format());
        }

        // Reference number (optional)
        if (String.isNotBlank(request.referenceNumber)) {
            estimate.put('DocNumber', request.referenceNumber);
        }

        // Customer memo (optional)
        if (String.isNotBlank(request.customerMemo)) {
            estimate.put('CustomerMemo', request.customerMemo);
        }

        // Private memo (optional)
        if (String.isNotBlank(request.privateMemo)) {
            estimate.put('PrivateMemo', request.privateMemo);
        }

        // Shipping address (optional)
        if (String.isNotBlank(request.shipToAddress)) {
            Map<String, Object> shipping = new Map<String, Object>();
            Map<String, Object> shipAddr = new Map<String, Object>();
            shipAddr.put('Line1', request.shipToAddress);
            shipping.put('ShipAddress', shipAddr);
            estimate.put('Shipping', shipping);
        }

        return estimate;
    }

    /**
     * Build individual estimate line item
     */
    private static Map<String, Object> buildEstimateLineItem(EstimateLineItem lineItem, Integer sequence) {
        Map<String, Object> line = new Map<String, Object>();

        line.put('sequence', String.valueOf(sequence));
        line.put('amount', lineItem.amount);
        line.put('description', lineItem.description);
        line.put('quantity', lineItem.quantity);
        line.put('unitPrice', lineItem.unitPrice);

        // Item reference (QB Item ID)
        if (String.isNotBlank(lineItem.quickBooksItemId)) {
            Map<String, Object> itemRef = new Map<String, Object>();
            itemRef.put('value', lineItem.quickBooksItemId);
            line.put('item', itemRef);
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
    private static void handleAPIError(HttpResponse response, EstimateResponse responseObj) {
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

    // ==================== Request/Response Classes ====================

    /**
     * Estimate creation request - supports multiple line items
     */
    public class EstimateRequest {
        @InvocableVariable(label='Salesforce Opportunity ID' required=true)
        public Id opportunityId;

        @InvocableVariable(label='QuickBooks Company ID' required=true)
        public String companyId;

        @InvocableVariable(label='Estimate Line Items')
        public List<EstimateLineItem> lineItems;

        @InvocableVariable(label='Discount Amount')
        public Decimal discountAmount;

        @InvocableVariable(label='Apply Tax After Discount')
        public Boolean applyTaxAfterDiscount;

        @InvocableVariable(label='Estimate Date')
        public Date estimateDate;

        @InvocableVariable(label='Expiration Date')
        public Date expirationDate;

        @InvocableVariable(label='Reference Number')
        public String referenceNumber;

        @InvocableVariable(label='Customer Memo')
        public String customerMemo;

        @InvocableVariable(label='Private Memo')
        public String privateMemo;

        @InvocableVariable(label='Ship To Address')
        public String shipToAddress;
    }

    /**
     * Estimate line item for Flow input
     */
    public class EstimateLineItem {
        @InvocableVariable(label='Description' required=true)
        public String description;

        @InvocableVariable(label='Quantity' required=true)
        public Decimal quantity;

        @InvocableVariable(label='Unit Price' required=true)
        public Decimal unitPrice;

        @InvocableVariable(label='Amount' required=true)
        public Decimal amount;

        @InvocableVariable(label='QuickBooks Item ID')
        public String quickBooksItemId;
    }

    /**
     * Estimate creation response
     */
    public class EstimateResponse {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='QuickBooks Estimate ID')
        public String quickBooksEstimateId;

        @InvocableVariable(label='QuickBooks Estimate Number')
        public String quickBooksEstimateNumber;

        @InvocableVariable(label='Salesforce Opportunity ID')
        public Id salesforceOpportunityId;
    }

    /**
     * Custom exception class
     */
    public class QuickBooksException extends Exception {}
}
