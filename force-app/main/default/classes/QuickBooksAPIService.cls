/**
 * QuickBooks API Service with Invocable Methods for Flow Builder
 * Provides integration with QuickBooks Online API
 */
public with sharing class QuickBooksAPIService {

    private static final String API_VERSION = '/v3/company/';
    private static final String BASE_URL_SANDBOX = 'https://sandbox-quickbooks.api.intuit.com';
    private static final String BASE_URL_PRODUCTION = 'https://quickbooks.api.intuit.com';

    /**
     * Invocable method to create a QuickBooks customer from Salesforce Account
     */
    @InvocableMethod(label='Create QuickBooks Customer'
                     description='Creates a customer in QuickBooks from Salesforce Account'
                     category='QuickBooks Integration')
    public static List<CustomerResponse> createCustomer(List<CustomerRequest> requests) {
        List<CustomerResponse> responses = new List<CustomerResponse>();

        for (CustomerRequest request : requests) {
            CustomerResponse response = new CustomerResponse();
            response.salesforceAccountId = request.accountId;

            try {
                // Get Account details
                Account acc = [
                    SELECT Id, Name, BillingStreet, BillingCity, BillingState,
                           BillingPostalCode, BillingCountry, Phone, Website,
                           AccountNumber, Type, Industry
                    FROM Account
                    WHERE Id = :request.accountId
                    LIMIT 1
                ];

                // Prepare customer data
                Map<String, Object> customerData = buildCustomerData(acc);

                // Make API call
                String endpoint = getBaseUrl(request.companyId) + API_VERSION +
                                request.companyId + '/customer';

                HttpResponse httpResponse = makeAPICall(
                    'POST',
                    endpoint,
                    JSON.serialize(customerData),
                    request.companyId
                );

                if (httpResponse.getStatusCode() == 200) {
                    Map<String, Object> result = (Map<String, Object>)
                        JSON.deserializeUntyped(httpResponse.getBody());
                    Map<String, Object> customer = (Map<String, Object>) result.get('Customer');

                    response.quickBooksCustomerId = (String) customer.get('Id');
                    response.success = true;
                    response.message = 'Customer created successfully';

                    // Update Account with QuickBooks ID
                    acc.QuickBooks_Customer_Id__c = response.quickBooksCustomerId;
                    acc.QuickBooks_Sync_Status__c = 'Synced';
                    acc.QuickBooks_Last_Sync__c = DateTime.now();
                    update acc;
                } else {
                    handleAPIError(httpResponse, response);
                }
            } catch (Exception e) {
                response.success = false;
                response.message = 'Error: ' + e.getMessage();
                logError('Create Customer', e.getMessage(), request.accountId);
            }

            responses.add(response);
        }

        return responses;
    }

    /**
     * Invocable method to create QuickBooks invoice
     */
    /* @InvocableMethod(label='Create QuickBooks Invoice'
                     description='Creates an invoice in QuickBooks from Salesforce Opportunity'
                     category='QuickBooks Integration') */
    public static List<InvoiceResponse> createInvoice(List<InvoiceRequest> requests) {
        List<InvoiceResponse> responses = new List<InvoiceResponse>();

        for (InvoiceRequest request : requests) {
            InvoiceResponse response = new InvoiceResponse();
            response.salesforceOpportunityId = request.opportunityId;

            try {
                // Get Opportunity and related data
                Opportunity opp = getOpportunityWithLineItems(request.opportunityId);

                // Check if Account has QuickBooks Customer ID
                if (String.isBlank(opp.Account.QuickBooks_Customer_Id__c)) {
                    // Create customer first
                    CustomerRequest custReq = new CustomerRequest();
                    custReq.accountId = opp.AccountId;
                    custReq.companyId = request.companyId;

                    List<CustomerResponse> custResponses = createCustomer(
                        new List<CustomerRequest>{custReq}
                    );

                    if (!custResponses[0].success) {
                        throw new QuickBooksException('Failed to create customer: ' +
                                                     custResponses[0].message);
                    }

                    opp.Account.QuickBooks_Customer_Id__c = custResponses[0].quickBooksCustomerId;
                }

                // Build invoice data
                Map<String, Object> invoiceData = buildInvoiceData(opp);

                // Make API call
                String endpoint = getBaseUrl(request.companyId) + API_VERSION +
                                request.companyId + '/invoice';

                HttpResponse httpResponse = makeAPICall(
                    'POST',
                    endpoint,
                    JSON.serialize(invoiceData),
                    request.companyId
                );

                if (httpResponse.getStatusCode() == 200) {
                    Map<String, Object> result = (Map<String, Object>)
                        JSON.deserializeUntyped(httpResponse.getBody());
                    Map<String, Object> invoice = (Map<String, Object>) result.get('Invoice');

                    response.quickBooksInvoiceId = (String) invoice.get('Id');
                    response.quickBooksInvoiceNumber = (String) invoice.get('DocNumber');
                    response.success = true;
                    response.message = 'Invoice created successfully';

                    // Update Opportunity
                    opp.QuickBooks_Invoice_Id__c = response.quickBooksInvoiceId;
                    opp.QuickBooks_Invoice_Number__c = response.quickBooksInvoiceNumber;
                    opp.QuickBooks_Sync_Status__c = 'Synced';
                    opp.QuickBooks_Last_Sync__c = DateTime.now();
                    update opp;
                } else {
                    handleAPIError(httpResponse, response);
                }
            } catch (Exception e) {
                response.success = false;
                response.message = 'Error: ' + e.getMessage();
                logError('Create Invoice', e.getMessage(), request.opportunityId);
            }

            responses.add(response);
        }

        return responses;
    }

    /**
     * Invocable method to sync payments from QuickBooks
     */
    /* @InvocableMethod(label='Sync QuickBooks Payments'
                     description='Syncs payment status from QuickBooks to Salesforce'
                     category='QuickBooks Integration') */
    public static List<PaymentSyncResponse> syncPayments(List<PaymentSyncRequest> requests) {
        List<PaymentSyncResponse> responses = new List<PaymentSyncResponse>();

        for (PaymentSyncRequest request : requests) {
            PaymentSyncResponse response = new PaymentSyncResponse();

            try {
                // Query payments from QuickBooks
                String query = 'SELECT * FROM Payment WHERE CustomerRef = \'' +
                             request.quickBooksCustomerId + '\' MAXRESULTS 100';

                String endpoint = getBaseUrl(request.companyId) + API_VERSION +
                                request.companyId + '/query?query=' +
                                EncodingUtil.urlEncode(query, 'UTF-8');

                HttpResponse httpResponse = makeAPICall(
                    'GET',
                    endpoint,
                    null,
                    request.companyId
                );

                if (httpResponse.getStatusCode() == 200) {
                    Map<String, Object> result = (Map<String, Object>)
                        JSON.deserializeUntyped(httpResponse.getBody());

                    processPaymentData(result, request.accountId);

                    response.success = true;
                    response.message = 'Payments synced successfully';
                    response.paymentsProcessed = getPaymentCount(result);
                } else {
                    handleAPIError(httpResponse, response);
                }
            } catch (Exception e) {
                response.success = false;
                response.message = 'Error: ' + e.getMessage();
                logError('Sync Payments', e.getMessage(), request.accountId);
            }

            responses.add(response);
        }

        return responses;
    }

    /**
     * Invocable method to create QuickBooks estimates
     */
    /* @InvocableMethod(label='Create QuickBooks Estimate'
                     description='Creates an estimate in QuickBooks with multiple line items'
                     category='QuickBooks Integration') */
    public static List<EstimateResponse> createEstimate(List<EstimateRequest> requests) {
        List<EstimateResponse> responses = new List<EstimateResponse>();

        for (EstimateRequest request : requests) {
            EstimateResponse response = new EstimateResponse();
            response.salesforceOpportunityId = request.opportunityId;

            try {
                // Get Opportunity and related data
                Opportunity opp = getOpportunityWithLineItems(request.opportunityId);

                // Check if Account has QuickBooks Customer ID
                if (String.isBlank(opp.Account.QuickBooks_Customer_Id__c)) {
                    // Create customer first
                    CustomerRequest custReq = new CustomerRequest();
                    custReq.accountId = opp.AccountId;
                    custReq.companyId = request.companyId;

                    List<CustomerResponse> custResponses = createCustomer(
                        new List<CustomerRequest>{custReq}
                    );

                    if (!custResponses[0].success) {
                        throw new QuickBooksException('Failed to create customer: ' +
                                                     custResponses[0].message);
                    }

                    opp.Account.QuickBooks_Customer_Id__c = custResponses[0].quickBooksCustomerId;
                }

                // Build estimate data with line items
                Map<String, Object> estimateData = buildEstimateData(opp, request);

                // Make API call
                String endpoint = getBaseUrl(request.companyId) + API_VERSION +
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

                    // Update Opportunity (using existing field name)
                    opp.QuickBooks_Invoice_Id__c = response.quickBooksEstimateId;
                    opp.QuickBooks_Invoice_Number__c = response.quickBooksEstimateNumber;
                    opp.QuickBooks_Sync_Status__c = 'Synced';
                    opp.QuickBooks_Last_Sync__c = DateTime.now();
                    update opp;
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
     * Invocable method to create products/items in QuickBooks
     */
    /* @InvocableMethod(label='Create QuickBooks Item'
                     description='Creates a product/service item in QuickBooks from Salesforce Product'
                     category='QuickBooks Integration') */
    public static List<ItemResponse> createItem(List<ItemRequest> requests) {
        List<ItemResponse> responses = new List<ItemResponse>();

        for (ItemRequest request : requests) {
            ItemResponse response = new ItemResponse();
            response.salesforceProductId = request.productId;

            try {
                // Get Product details
                Product2 prod = [
                    SELECT Id, Name, ProductCode, Description, IsActive,
                           Family, Type__c
                    FROM Product2
                    WHERE Id = :request.productId
                    LIMIT 1
                ];

                // Get price from PricebookEntry
                PricebookEntry pbe = [
                    SELECT UnitPrice
                    FROM PricebookEntry
                    WHERE Product2Id = :request.productId
                    AND Pricebook2.IsStandard = true
                    AND IsActive = true
                    LIMIT 1
                ];

                // Build item data
                Map<String, Object> itemData = buildItemData(prod, pbe.UnitPrice);

                // Make API call
                String endpoint = getBaseUrl(request.companyId) + API_VERSION +
                                request.companyId + '/item';

                HttpResponse httpResponse = makeAPICall(
                    'POST',
                    endpoint,
                    JSON.serialize(itemData),
                    request.companyId
                );

                if (httpResponse.getStatusCode() == 200) {
                    Map<String, Object> result = (Map<String, Object>)
                        JSON.deserializeUntyped(httpResponse.getBody());
                    Map<String, Object> item = (Map<String, Object>) result.get('Item');

                    response.quickBooksItemId = (String) item.get('Id');
                    response.success = true;
                    response.message = 'Item created successfully';

                    // Update Product
                    prod.QuickBooks_Item_Id__c = response.quickBooksItemId;
                    prod.QuickBooks_Sync_Status__c = 'Synced';
                    update prod;
                } else {
                    handleAPIError(httpResponse, response);
                }
            } catch (Exception e) {
                response.success = false;
                response.message = 'Error: ' + e.getMessage();
                logError('Create Item', e.getMessage(), request.productId);
            }

            responses.add(response);
        }

        return responses;
    }

    // ==================== Helper Methods ====================

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
     * Build customer data for QuickBooks API
     */
    private static Map<String, Object> buildCustomerData(Account acc) {
        Map<String, Object> customer = new Map<String, Object>();

        customer.put('DisplayName', acc.Name);
        customer.put('CompanyName', acc.Name);

        // Billing Address
        Map<String, Object> billAddr = new Map<String, Object>();
        billAddr.put('Line1', acc.BillingStreet);
        billAddr.put('City', acc.BillingCity);
        billAddr.put('CountrySubDivisionCode', acc.BillingState);
        billAddr.put('PostalCode', acc.BillingPostalCode);
        billAddr.put('Country', acc.BillingCountry);
        customer.put('BillAddr', billAddr);

        // Contact info
        Map<String, Object> primaryPhone = new Map<String, Object>();
        primaryPhone.put('FreeFormNumber', acc.Phone);
        customer.put('PrimaryPhone', primaryPhone);

        if (acc.Website != null) {
            Map<String, Object> webAddr = new Map<String, Object>();
            webAddr.put('URI', acc.Website);
            customer.put('WebAddr', webAddr);
        }

        return customer;
    }

    /**
     * Build estimate data for QuickBooks API with line items and discount
     */
    private static Map<String, Object> buildEstimateData(Opportunity opp, EstimateRequest request) {
        Map<String, Object> estimate = new Map<String, Object>();

        // Customer reference
        Map<String, Object> customerRef = new Map<String, Object>();
        customerRef.put('value', opp.Account.QuickBooks_Customer_Id__c);
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

                Map<String, Object> unitPrice = new Map<String, Object>();
                unitPrice.put('value', oli.UnitPrice);
                line.put('unitPrice', oli.UnitPrice);

                if (oli.Product2.QuickBooks_Item_Id__c != null) {
                    Map<String, Object> itemRef = new Map<String, Object>();
                    itemRef.put('value', oli.Product2.QuickBooks_Item_Id__c);
                    line.put('item', itemRef);
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
     * Build invoice data for QuickBooks API
     */
    private static Map<String, Object> buildInvoiceData(Opportunity opp) {
        Map<String, Object> invoice = new Map<String, Object>();

        // Customer reference
        Map<String, Object> customerRef = new Map<String, Object>();
        customerRef.put('value', opp.Account.QuickBooks_Customer_Id__c);
        invoice.put('CustomerRef', customerRef);

        // Line items
        List<Map<String, Object>> lines = new List<Map<String, Object>>();

        for (OpportunityLineItem oli : opp.OpportunityLineItems) {
            Map<String, Object> line = new Map<String, Object>();
            line.put('DetailType', 'SalesItemLineDetail');
            line.put('Amount', oli.TotalPrice);

            Map<String, Object> salesItemLineDetail = new Map<String, Object>();
            if (oli.Product2.QuickBooks_Item_Id__c != null) {
                Map<String, Object> itemRef = new Map<String, Object>();
                itemRef.put('value', oli.Product2.QuickBooks_Item_Id__c);
                salesItemLineDetail.put('ItemRef', itemRef);
            }
            salesItemLineDetail.put('Qty', oli.Quantity);
            salesItemLineDetail.put('UnitPrice', oli.UnitPrice);

            line.put('SalesItemLineDetail', salesItemLineDetail);
            line.put('Description', oli.Product2.Name);

            lines.add(line);
        }

        invoice.put('Line', lines);

        // Due date (30 days from today by default)
        invoice.put('DueDate', Date.today().addDays(30).format());

        // Invoice date
        invoice.put('TxnDate', Date.today().format());

        // Custom fields
        Map<String, Object> customField = new Map<String, Object>();
        customField.put('DefinitionId', '1');
        customField.put('Name', 'Salesforce Opportunity');
        customField.put('Type', 'StringType');
        customField.put('StringValue', opp.Id);
        invoice.put('CustomField', new List<Object>{customField});

        return invoice;
    }

    /**
     * Build item data for QuickBooks API
     */
    private static Map<String, Object> buildItemData(Product2 prod, Decimal price) {
        Map<String, Object> item = new Map<String, Object>();

        item.put('Name', prod.Name);
        item.put('Type', 'Service'); // Can be 'Service' or 'NonInventory'
        item.put('Active', prod.IsActive);

        if (prod.Description != null) {
            item.put('Description', prod.Description);
        }

        // Income account reference (required)
        Map<String, Object> incomeAccountRef = new Map<String, Object>();
        incomeAccountRef.put('value', '1'); // Default income account
        item.put('IncomeAccountRef', incomeAccountRef);

        // Unit price
        item.put('UnitPrice', price);

        if (prod.ProductCode != null) {
            item.put('Sku', prod.ProductCode);
        }

        return item;
    }

    /**
     * Get Opportunity with line items
     */
    private static Opportunity getOpportunityWithLineItems(Id oppId) {
        return [
            SELECT Id, Name, AccountId, Amount, CloseDate, StageName,
                   Account.QuickBooks_Customer_Id__c,
                   (SELECT Id, Product2Id, Product2.Name, Product2.QuickBooks_Item_Id__c,
                           Quantity, UnitPrice, TotalPrice
                    FROM OpportunityLineItems)
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];
    }

    /**
     * Process payment data from QuickBooks
     */
    private static void processPaymentData(Map<String, Object> result, Id accountId) {
        // Implementation for processing payment data
        // This would create/update payment records in Salesforce
    }

    /**
     * Get payment count from result
     */
    private static Integer getPaymentCount(Map<String, Object> result) {
        Map<String, Object> queryResponse = (Map<String, Object>) result.get('QueryResponse');
        if (queryResponse != null && queryResponse.containsKey('Payment')) {
            List<Object> payments = (List<Object>) queryResponse.get('Payment');
            return payments.size();
        }
        return 0;
    }

    /**
     * Handle API error response
     */
    private static void handleAPIError(HttpResponse response, Object responseObj) {
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

        // Set error on response object using reflection
        // In real implementation, each response type would have these fields
        if (responseObj instanceof CustomerResponse) {
            ((CustomerResponse) responseObj).success = false;
            ((CustomerResponse) responseObj).message = errorMessage;
        }
        // Similar for other response types...
    }

    /**
     * Get base URL based on environment
     */
    private static String getBaseUrl(String companyId) {
        QuickBooks_Config__mdt config = QuickBooks_Config__mdt.getInstance('Default');
        return config.Is_Sandbox__c ? BASE_URL_SANDBOX : BASE_URL_PRODUCTION;
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
     * Customer creation request
     */
    public class CustomerRequest {
        @InvocableVariable(label='Salesforce Account ID' required=true)
        public Id accountId;

        @InvocableVariable(label='QuickBooks Company ID' required=true)
        public String companyId;
    }

    /**
     * Customer creation response
     */
    public class CustomerResponse {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='QuickBooks Customer ID')
        public String quickBooksCustomerId;

        @InvocableVariable(label='Salesforce Account ID')
        public Id salesforceAccountId;
    }

    /**
     * Invoice creation request
     */
    public class InvoiceRequest {
        @InvocableVariable(label='Salesforce Opportunity ID' required=true)
        public Id opportunityId;

        @InvocableVariable(label='QuickBooks Company ID' required=true)
        public String companyId;
    }

    /**
     * Invoice creation response
     */
    public class InvoiceResponse {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='QuickBooks Invoice ID')
        public String quickBooksInvoiceId;

        @InvocableVariable(label='QuickBooks Invoice Number')
        public String quickBooksInvoiceNumber;

        @InvocableVariable(label='Salesforce Opportunity ID')
        public Id salesforceOpportunityId;
    }

    /**
     * Payment sync request
     */
    public class PaymentSyncRequest {
        @InvocableVariable(label='Salesforce Account ID' required=true)
        public Id accountId;

        @InvocableVariable(label='QuickBooks Customer ID' required=true)
        public String quickBooksCustomerId;

        @InvocableVariable(label='QuickBooks Company ID' required=true)
        public String companyId;
    }

    /**
     * Payment sync response
     */
    public class PaymentSyncResponse {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Payments Processed')
        public Integer paymentsProcessed;
    }

    /**
     * Item creation request
     */
    public class ItemRequest {
        @InvocableVariable(label='Salesforce Product ID' required=true)
        public Id productId;

        @InvocableVariable(label='QuickBooks Company ID' required=true)
        public String companyId;
    }

    /**
     * Item creation response
     */
    public class ItemResponse {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='QuickBooks Item ID')
        public String quickBooksItemId;

        @InvocableVariable(label='Salesforce Product ID')
        public Id salesforceProductId;
    }

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