/**
 * QuickBooks API Service
 * Provides integration with QuickBooks Online API
 * Service methods are called by specific Invocable classes
 */
public with sharing class QuickBooksAPIService {

    private static final String API_VERSION = '/v3/company/';
    private static final String BASE_URL_SANDBOX = 'https://sandbox-quickbooks.api.intuit.com';
    private static final String BASE_URL_PRODUCTION = 'https://quickbooks.api.intuit.com';

    /**
     * Create a QuickBooks customer from Salesforce Account
     */
    public static List<QuickBooksCustomerResponse> createCustomer(List<QuickBooksCustomerRequest> requests) {
        List<QuickBooksCustomerResponse> responses = new List<QuickBooksCustomerResponse>();
        Map<Id, Account> accountsToUpdate = new Map<Id, Account>();
        List<Integration_Log__c> logsToInsert = new List<Integration_Log__c>();
        
        // Manage Auth Updates to prevent "Uncommitted Work" error
        // We use a map to ensure we only update once per company if multiple requests
        Map<Id, QuickBooks_Auth__c> authsToUpdate = new Map<Id, QuickBooks_Auth__c>();

        // 1. Collect Account IDs
        Set<Id> accountIds = new Set<Id>();
        for (QuickBooksCustomerRequest req : requests) {
            if (req.accountId != null) accountIds.add(req.accountId);
        }

        // 2. Query Accounts in bulk
        Map<Id, Account> accountMap = new Map<Id, Account>([
            SELECT Id, Name, BillingStreet, BillingCity, BillingState,
                   BillingPostalCode, BillingCountry, Phone, Website,
                   AccountNumber, Type, Industry, QuickBooks_Customer_Id__c
            FROM Account
            WHERE Id IN :accountIds
        ]);

        // 3. Process Requests
        for (QuickBooksCustomerRequest request : requests) {
            QuickBooksCustomerResponse response = new QuickBooksCustomerResponse();
            response.salesforceAccountId = request.accountId;

            try {
                Account acc = accountMap.get(request.accountId);
                if (acc == null) {
                    throw new QuickBooksException('Account not found: ' + request.accountId);
                }

                // Retrieve Token (Deferred DML)
                QuickBooks_Auth__c auth = QuickBooksAuthProvider.getValidAuthState(request.companyId, false);
                authsToUpdate.put(auth.Id, auth);

                // Perform Callout using the token
                String qbCustomerId = createCustomerCallout(acc, request.companyId, auth.Access_Token__c);

                response.quickBooksCustomerId = qbCustomerId;
                response.success = true;
                response.message = 'Customer created successfully';

                // Queue Account Update
                Account accUpdate = new Account(
                    Id = acc.Id,
                    QuickBooks_Customer_Id__c = qbCustomerId,
                    QuickBooks_Sync_Status__c = 'Synced',
                    QuickBooks_Last_Sync__c = DateTime.now()
                );
                accountsToUpdate.put(acc.Id, accUpdate);

            } catch (Exception e) {
                response.success = false;
                response.message = 'Error: ' + e.getMessage();
                logsToInsert.add(createErrorLog('Create Customer', e.getMessage(), request.accountId));
            }
            responses.add(response);
        }

        // 4. Perform DML
        if (!authsToUpdate.isEmpty()) {
             update authsToUpdate.values(); // Update Auth tokens if they were refreshed
        }
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate.values();
        }
        if (!logsToInsert.isEmpty()) {
            insert logsToInsert;
        }

        return responses;
    }

    /**
     * Create QuickBooks invoice
     */
    public static List<QuickBooksInvoiceResponse> createInvoice(List<QuickBooksInvoiceRequest> requests) {
        List<QuickBooksInvoiceResponse> responses = new List<QuickBooksInvoiceResponse>();
        Map<Id, Account> accountsToUpdate = new Map<Id, Account>();
        Map<Id, Opportunity> oppsToUpdate = new Map<Id, Opportunity>();
        List<Integration_Log__c> logsToInsert = new List<Integration_Log__c>();
        Map<Id, QuickBooks_Auth__c> authsToUpdate = new Map<Id, QuickBooks_Auth__c>();

        // 1. Collect Opportunity IDs
        Set<Id> oppIds = new Set<Id>();
        for (QuickBooksInvoiceRequest req : requests) {
            if (req.opportunityId != null) oppIds.add(req.opportunityId);
        }

        // 2. Query Opportunities with Line Items and Account info
        Map<Id, Opportunity> oppMap = getOpportunitiesWithLineItems(oppIds);

        // 3. Process Requests
        for (QuickBooksInvoiceRequest request : requests) {
            QuickBooksInvoiceResponse response = new QuickBooksInvoiceResponse();
            response.salesforceOpportunityId = request.opportunityId;

            try {
                Opportunity opp = oppMap.get(request.opportunityId);
                if (opp == null) throw new QuickBooksException('Opportunity not found');
                
                // Retrieve Token (Deferred DML)
                QuickBooks_Auth__c auth = QuickBooksAuthProvider.getValidAuthState(request.companyId, false);
                authsToUpdate.put(auth.Id, auth);
                String accessToken = auth.Access_Token__c;

                String qbCustomerId = opp.Account.QuickBooks_Customer_Id__c;

                // Check if we need to create the customer first
                if (String.isBlank(qbCustomerId)) {
                    if (accountsToUpdate.containsKey(opp.AccountId)) {
                        qbCustomerId = accountsToUpdate.get(opp.AccountId).QuickBooks_Customer_Id__c;
                    } else {
                        // Create customer via API (using passed token)
                        qbCustomerId = createCustomerCallout(opp.Account, request.companyId, accessToken);
                        
                        Account accUpdate = new Account(
                            Id = opp.AccountId,
                            QuickBooks_Customer_Id__c = qbCustomerId,
                            QuickBooks_Sync_Status__c = 'Synced',
                            QuickBooks_Last_Sync__c = DateTime.now()
                        );
                        accountsToUpdate.put(opp.AccountId, accUpdate);
                    }
                }

                // Build and create Invoice
                Map<String, Object> invoiceData = buildInvoiceData(opp, qbCustomerId);
                Map<String, Object> invoiceResult = postToQuickBooks(
                    'invoice', 
                    invoiceData, 
                    request.companyId,
                    accessToken
                );
                
                Map<String, Object> invoice = (Map<String, Object>) invoiceResult.get('Invoice');
                
                response.quickBooksInvoiceId = (String) invoice.get('Id');
                response.quickBooksInvoiceNumber = (String) invoice.get('DocNumber');
                response.success = true;
                response.message = 'Invoice created successfully';

                // Queue Opportunity Update
                Opportunity oppUpdate = new Opportunity(
                    Id = opp.Id,
                    QuickBooks_Invoice_Id__c = response.quickBooksInvoiceId,
                    QuickBooks_Invoice_Number__c = response.quickBooksInvoiceNumber,
                    QuickBooks_Sync_Status__c = 'Synced',
                    QuickBooks_Last_Sync__c = DateTime.now()
                );
                oppsToUpdate.put(opp.Id, oppUpdate);

            } catch (Exception e) {
                response.success = false;
                response.message = 'Error: ' + e.getMessage();
                logsToInsert.add(createErrorLog('Create Invoice', e.getMessage(), request.opportunityId));
            }
            responses.add(response);
        }

        // 4. Perform DML (Auths first, then others)
        if (!authsToUpdate.isEmpty()) update authsToUpdate.values();
        if (!accountsToUpdate.isEmpty()) update accountsToUpdate.values();
        if (!oppsToUpdate.isEmpty()) update oppsToUpdate.values();
        if (!logsToInsert.isEmpty()) insert logsToInsert;

        return responses;
    }

    /**
     * Create QuickBooks estimate with multiple line items
     */
    public static List<QuickBooksEstimateResponse> createEstimate(List<QuickBooksEstimateRequest> requests) {
        List<QuickBooksEstimateResponse> responses = new List<QuickBooksEstimateResponse>();
        Map<Id, Opportunity> oppsToUpdate = new Map<Id, Opportunity>();
        List<Integration_Log__c> logsToInsert = new List<Integration_Log__c>();
        Map<Id, QuickBooks_Auth__c> authsToUpdate = new Map<Id, QuickBooks_Auth__c>();

        for (QuickBooksEstimateRequest request : requests) {
            QuickBooksEstimateResponse response = new QuickBooksEstimateResponse();
            response.salesforceOpportunityId = request.opportunityId;

            try {
                // Retrieve Token (Deferred DML)
                QuickBooks_Auth__c auth = QuickBooksAuthProvider.getValidAuthState(request.companyId, false);
                authsToUpdate.put(auth.Id, auth);
                String accessToken = auth.Access_Token__c;
                
                Map<String, Object> estimateData = buildEstimateData(request);
                
                Map<String, Object> result = postToQuickBooks(
                    'estimate', 
                    estimateData, 
                    request.companyId,
                    accessToken
                );
                
                Map<String, Object> estimate = (Map<String, Object>) result.get('Estimate');

                response.quickBooksEstimateId = String.valueOf(estimate.get('Id'));
                response.quickBooksEstimateNumber = String.valueOf(estimate.get('DocNumber'));
                response.success = true;
                response.message = 'Estimate created successfully';

                if (request.opportunityId != null) {
                    Opportunity oppUpdate = new Opportunity(
                        Id = request.opportunityId,
                        QuickBooks_Estimate_Id__c = response.quickBooksEstimateId,
                        QuickBooks_Estimate_Number__c = response.quickBooksEstimateNumber,
                        QuickBooks_Last_Sync__c = DateTime.now()
                    );
                    oppsToUpdate.put(request.opportunityId, oppUpdate);
                }

            } catch (Exception e) {
                response.success = false;
                response.message = 'Error creating estimate: ' + e.getMessage();
                logsToInsert.add(createErrorLog('Create Estimate', e.getMessage(), request.opportunityId));
            }
            responses.add(response);
        }

        if (!authsToUpdate.isEmpty()) update authsToUpdate.values();
        if (!oppsToUpdate.isEmpty()) update oppsToUpdate.values();
        if (!logsToInsert.isEmpty()) insert logsToInsert;

        return responses;
    }

    // ==================== Helper Methods ====================

    /**
     * Internal helper to create a customer via API.
     * Does NOT perform DML. Returns the QuickBooks Customer Id.
     */
    private static String createCustomerCallout(Account acc, String companyId, String accessToken) {
        Map<String, Object> customerData = buildCustomerData(acc);
        // Use the version of postToQuickBooks that accepts a token
        Map<String, Object> result = postToQuickBooks('customer', customerData, companyId, accessToken);
        Map<String, Object> customer = (Map<String, Object>) result.get('Customer');
        return (String) customer.get('Id');
    }
    
    // Overload for backwards compatibility/internal calls if needed, 
    // but deprecated as it triggers DML in getValidAccessToken
    private static String createCustomerCallout(Account acc, String companyId) {
         // Retrieve token with deferred DML, but we can't defer DML here easily without passing auth object out.
         // Used only by legacy logic? In this class, we updated callers.
         // Safe fallback:
         return createCustomerCallout(acc, companyId, QuickBooksAuthProvider.getValidAccessToken(companyId));
    }

    /**
     * Generic helper to POST to QuickBooks
     * NEW SIGNATURE: Accepts Access Token
     */
    private static Map<String, Object> postToQuickBooks(String resource, Map<String, Object> data, String companyId, String accessToken) {
        String endpoint = getBaseUrl(companyId) + API_VERSION + companyId + '/' + resource;
        
        HttpResponse httpResponse = makeAPICallWithToken(
            'POST',
            endpoint,
            JSON.serialize(data),
            accessToken
        );

        if (httpResponse.getStatusCode() == 200) {
            return (Map<String, Object>) JSON.deserializeUntyped(httpResponse.getBody());
        } else {
            throw new QuickBooksException(parseAPIError(httpResponse));
        }
    }

    // OLD SIGNATURE for compatibility (uses auto-refresh which might cause DML error)
    private static Map<String, Object> postToQuickBooks(String resource, Map<String, Object> data, String companyId) {
        return postToQuickBooks(resource, data, companyId, QuickBooksAuthProvider.getValidAccessToken(companyId));
    }

    private static HttpResponse makeAPICallWithToken(String method, String endpoint, String body, String accessToken) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();

        request.setEndpoint(endpoint);
        request.setMethod(method);
        request.setHeader('Accept', 'application/json');
        request.setHeader('Content-Type', 'application/json');

        request.setHeader('Authorization', 'Bearer ' + accessToken);

        if (body != null) {
            request.setBody(body);
        }

        request.setTimeout(120000);
        return http.send(request);
    }
    
    // OLD SIGNATURE
    private static HttpResponse makeAPICall(String method, String endpoint, String body, String companyId) {
        return makeAPICallWithToken(method, endpoint, body, QuickBooksAuthProvider.getValidAccessToken(companyId));
    }

    private static Map<String, Object> buildCustomerData(Account acc) {
        Map<String, Object> customer = new Map<String, Object>();
        customer.put('DisplayName', acc.Name);
        customer.put('CompanyName', acc.Name);

        Map<String, Object> billAddr = new Map<String, Object>();
        billAddr.put('Line1', acc.BillingStreet);
        billAddr.put('City', acc.BillingCity);
        billAddr.put('CountrySubDivisionCode', acc.BillingState);
        billAddr.put('PostalCode', acc.BillingPostalCode);
        billAddr.put('Country', acc.BillingCountry);
        customer.put('BillAddr', billAddr);

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

    private static Map<String, Object> buildInvoiceData(Opportunity opp, String qbCustomerId) {
        Map<String, Object> invoice = new Map<String, Object>();

        Map<String, Object> customerRef = new Map<String, Object>();
        customerRef.put('value', qbCustomerId);
        invoice.put('CustomerRef', customerRef);

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
        invoice.put('DueDate', Date.today().addDays(30).format());
        invoice.put('TxnDate', Date.today().format());
        
        // Custom Field for SF Id
        Map<String, Object> customField = new Map<String, Object>();
        customField.put('DefinitionId', '1'); // Note: This ID might need configuration
        customField.put('Name', 'Salesforce Opportunity');
        customField.put('Type', 'StringType');
        customField.put('StringValue', opp.Id);
        invoice.put('CustomField', new List<Object>{customField});

        return invoice;
    }
    
    private static Map<String, Object> buildEstimateData(QuickBooksEstimateRequest request) {
        Map<String, Object> estimateData = new Map<String, Object>();

        // Customer reference
        if (request.customerRef != null) {
            Map<String, Object> customerRef = new Map<String, Object>();
            customerRef.put('value', request.customerRef);
            estimateData.put('CustomerRef', customerRef);
        }

        // Dates
        if (request.estimateDate != null) estimateData.put('TxnDate', request.estimateDate.format());
        if (request.expirationDate != null) estimateData.put('ExpirationDate', request.expirationDate.format());

        // Line items - support both individual fields and lineItemsJson
        List<Map<String, Object>> lines = new List<Map<String, Object>>();

        // Check if lineItemsJson is provided (for multi-line estimates)
        if (String.isNotBlank(request.lineItemsJson)) {
            try {
                List<Object> parsedItems = (List<Object>) JSON.deserializeUntyped(request.lineItemsJson);
                for (Object item : parsedItems) {
                    Map<String, Object> lineItem = (Map<String, Object>) item;
                    Map<String, Object> line = new Map<String, Object>();
                    line.put('DetailType', 'SalesItemLineDetail');

                    if (lineItem.containsKey('amount')) line.put('Amount', lineItem.get('amount'));
                    if (lineItem.containsKey('description')) line.put('Description', lineItem.get('description'));

                    // Build SalesItemLineDetail
                    Map<String, Object> salesDetail = new Map<String, Object>();
                    if (lineItem.containsKey('itemId')) {
                        Map<String, Object> itemRef = new Map<String, Object>();
                        itemRef.put('value', lineItem.get('itemId'));
                        salesDetail.put('ItemRef', itemRef);
                    }
                    if (lineItem.containsKey('quantity')) salesDetail.put('Qty', lineItem.get('quantity'));
                    if (lineItem.containsKey('unitPrice')) salesDetail.put('UnitPrice', lineItem.get('unitPrice'));

                    line.put('SalesItemLineDetail', salesDetail);
                    lines.add(line);
                }
            } catch (Exception e) {
                System.debug('Error parsing lineItemsJson: ' + e.getMessage());
            }
        }

        // If no line items from JSON, try to create from other fields (Fallback/Simple mode)
        if (lines.isEmpty()) {
            Map<String, Object> line = new Map<String, Object>();
            line.put('DetailType', 'SalesItemLineDetail');
            line.put('Amount', 100.00); // Placeholder default
            line.put('Description', 'Service');
            Map<String, Object> salesDetail = new Map<String, Object>();
            salesDetail.put('Qty', 1);
            line.put('SalesItemLineDetail', salesDetail);
            lines.add(line);
        }

        // Add discount line if specified
        if (request.discountAmount != null && request.discountAmount > 0) {
            Map<String, Object> discountLine = new Map<String, Object>();
            discountLine.put('DetailType', 'DiscountLineDetail');
            discountLine.put('Amount', request.discountAmount);
            Map<String, Object> discountDetail = new Map<String, Object>();
            discountDetail.put('PercentBased', false);
            discountLine.put('DiscountLineDetail', discountDetail);
            lines.add(discountLine);
        }

        estimateData.put('Line', lines);

        // Memos
        if (request.customerMemo != null) {
            Map<String, Object> customerMemo = new Map<String, Object>();
            customerMemo.put('value', request.customerMemo);
            estimateData.put('CustomerMemo', customerMemo);
        }
        if (request.privateMemo != null) {
            estimateData.put('PrivateNote', request.privateMemo);
        }

        // Tax settings
        if (request.applyTaxAfterDiscount != null) {
            estimateData.put('ApplyTaxAfterDiscount', request.applyTaxAfterDiscount);
        }
        
        return estimateData;
    }

    private static Map<Id, Opportunity> getOpportunitiesWithLineItems(Set<Id> oppIds) {
        if (oppIds.isEmpty()) return new Map<Id, Opportunity>();
        return new Map<Id, Opportunity>([
            SELECT Id, Name, AccountId, Amount, CloseDate, StageName,
                   Account.Name, Account.BillingStreet, Account.BillingCity, 
                   Account.BillingState, Account.BillingPostalCode, Account.BillingCountry,
                   Account.Phone, Account.Website, Account.QuickBooks_Customer_Id__c,
                   (SELECT Id, Product2Id, Product2.Name, Product2.QuickBooks_Item_Id__c,
                           Quantity, UnitPrice, TotalPrice
                    FROM OpportunityLineItems)
            FROM Opportunity
            WHERE Id IN :oppIds
        ]);
    }

    private static String parseAPIError(HttpResponse response) {
        Map<String, Object> error = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
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
        return errorMessage;
    }

    private static String getBaseUrl(String companyId) {
        QuickBooks_Config__mdt config = QuickBooks_Config__mdt.getInstance('Default');
        return config.Is_Sandbox__c ? BASE_URL_SANDBOX : BASE_URL_PRODUCTION;
    }

    private static Integration_Log__c createErrorLog(String context, String message, Id recordId) {
        return new Integration_Log__c(
            Integration_Type__c = 'QuickBooks',
            Context__c = context,
            Error_Message__c = message,
            Record_Id__c = recordId,
            Timestamp__c = DateTime.now()
        );
    }
    
    public class QuickBooksException extends Exception {}
}