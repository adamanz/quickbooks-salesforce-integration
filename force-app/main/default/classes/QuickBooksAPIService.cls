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
     * Find or create a QuickBooks customer from Salesforce Account
     * Returns existing customer ID if found, creates new if not
     */
    public static List<QuickBooksCustomerResponse> createCustomer(List<QuickBooksCustomerRequest> requests) {
        List<QuickBooksCustomerResponse> responses = new List<QuickBooksCustomerResponse>();
        Map<Id, Account> accountsToUpdate = new Map<Id, Account>();
        List<Integration_Log__c> logsToInsert = new List<Integration_Log__c>();

        // Manage Auth Updates to prevent "Uncommitted Work" error
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
                String accessToken = auth.Access_Token__c;

                // Find existing or create new customer
                String qbCustomerId = findOrCreateCustomer(acc, request, request.companyId, accessToken);

                // Check if this was an existing customer or newly created
                Boolean wasExisting = (acc.QuickBooks_Customer_Id__c == qbCustomerId);

                response.quickBooksCustomerId = qbCustomerId;
                response.success = true;
                response.message = wasExisting
                    ? 'Found existing customer: ' + qbCustomerId
                    : 'Customer created successfully: ' + qbCustomerId;

                // Queue Account Update (always update to ensure sync status is current)
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
             update authsToUpdate.values();
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

    /**
     * Send Estimate via Email
     */
    public static void sendEstimate(String estimateId, String emailAddress, String companyId) {
        QuickBooks_Auth__c auth = QuickBooksAuthProvider.getValidAuthState(companyId, false);
        String accessToken = auth.Access_Token__c;
        
        String endpoint = getBaseUrl(companyId) + API_VERSION + companyId + '/estimate/' + estimateId + '/send';
        if (String.isNotBlank(emailAddress)) {
            endpoint += '?sendTo=' + EncodingUtil.urlEncode(emailAddress, 'UTF-8');
        }

        // Manual request build to control headers for this specific endpoint
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('POST');
        request.setHeader('Authorization', 'Bearer ' + accessToken);
        request.setHeader('Accept', 'application/json');
        // Set Content-Type to application/octet-stream for empty body POSTs
        request.setHeader('Content-Type', 'application/octet-stream');
        
        HttpResponse response = http.send(request);
        
        if (response.getStatusCode() != 200) {
            throw new QuickBooksException(parseAPIError(response));
        }
        
        // If token was refreshed, we should update it
        if (auth.Access_Token__c != accessToken) { 
             update auth;
        }
    }

    /**
     * Uploads a file to QuickBooks and attaches it to a record
     */
    public static void uploadAttachment(String recordId, String recordType, String fileName, String contentType, Blob fileContent, String companyId) {
        QuickBooks_Auth__c auth = QuickBooksAuthProvider.getValidAuthState(companyId, false);
        String accessToken = auth.Access_Token__c;
        
        String endpoint = getBaseUrl(companyId) + API_VERSION + companyId + '/upload';
        
        String boundary = '----------------------------' + String.valueOf(DateTime.now().getTime());
        
        // 1. Metadata Part
        String metadataJson = '{' +
            '"AttachableRef": [' +
                '{' +
                    '"EntityRef": {' +
                        '"type": "' + recordType + '",' +
                        '"value": "' + recordId + '"' +
                    '}' +
                '}' +
            '],' +
            '"FileName": "' + fileName + '",' +
            '"ContentType": "' + contentType + '"' +
        '}';

        String bodyStart = '--' + boundary + '\r\n' +
            'Content-Disposition: form-data; name="file_metadata_01"; filename="metadata.json"\r\n' +
            'Content-Type: application/json\r\n\r\n' +
            metadataJson + '\r\n' +
            '--' + boundary + '\r\n' +
            'Content-Disposition: form-data; name="file_content_01"; filename="' + fileName + '"\r\n' +
            'Content-Type: ' + contentType + '\r\n\r\n';
            
        String bodyEnd = '\r\n--' + boundary + '--';
        
        // Construct the body using the Blob/Hex hack to merge String and Blob
        String bodyStartHex = EncodingUtil.convertToHex(Blob.valueOf(bodyStart));
        String fileHex = EncodingUtil.convertToHex(fileContent);
        String bodyEndHex = EncodingUtil.convertToHex(Blob.valueOf(bodyEnd));
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        req.setHeader('Accept', 'application/json');
        
        req.setBodyAsBlob(EncodingUtil.convertFromHex(bodyStartHex + fileHex + bodyEndHex));
        req.setTimeout(120000);
        
        Http http = new Http();
        HttpResponse response = http.send(req);
        
        if (response.getStatusCode() != 200) {
            throw new QuickBooksException(parseAPIError(response));
        }
        
        // Token maintenance
        if (auth.Access_Token__c != accessToken) {
             update auth;
        }
    }

    // ==================== Helper Methods ====================

    public static String findCustomerByName(String displayName, String companyId, String accessToken) {
        if (String.isBlank(displayName)) return null;

        String escapedName = displayName.replace('\'', '\\\'');
        String query = 'SELECT Id, DisplayName FROM Customer WHERE DisplayName = \'' + escapedName + '\'';
        String endpoint = getBaseUrl(companyId) + API_VERSION + companyId + '/query?query=' +
            EncodingUtil.urlEncode(query, 'UTF-8');

        HttpResponse response = makeAPICall('GET', endpoint, null, accessToken);
        if (response.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            Map<String, Object> queryResponse = (Map<String, Object>) result.get('QueryResponse');
            if (queryResponse != null && queryResponse.containsKey('Customer')) {
                List<Object> customers = (List<Object>) queryResponse.get('Customer');
                if (!customers.isEmpty()) {
                    return String.valueOf(((Map<String, Object>) customers[0]).get('Id'));
                }
            }
        }
        return null;
    }

    public static String findOrCreateCustomer(Account acc, QuickBooksCustomerRequest request, String companyId, String accessToken) {
        String displayName = String.isNotBlank(request?.displayName) ? request.displayName : acc.Name;
        String existingCustomerId = findCustomerByName(displayName, companyId, accessToken);
        if (existingCustomerId != null) {
            return existingCustomerId;
        }
        return createCustomerCallout(acc, request, companyId, accessToken);
    }

    private static String createCustomerCallout(Account acc, QuickBooksCustomerRequest request, String companyId, String accessToken) {
        Map<String, Object> customerData = buildCustomerData(acc, request);
        Map<String, Object> result = postToQuickBooks('customer', customerData, companyId, accessToken);
        Map<String, Object> customer = (Map<String, Object>) result.get('Customer');
        return String.valueOf(customer.get('Id'));
    }

    private static String createCustomerCallout(Account acc, String companyId, String accessToken) {
        return createCustomerCallout(acc, null, companyId, accessToken);
    }

    private static Map<String, Object> postToQuickBooks(String resource, Map<String, Object> data, String companyId, String accessToken) {
        String endpoint = getBaseUrl(companyId) + API_VERSION + companyId + '/' + resource;
        HttpResponse httpResponse = makeAPICall('POST', endpoint, JSON.serialize(data), accessToken);
        if (httpResponse.getStatusCode() == 200) {
            return (Map<String, Object>) JSON.deserializeUntyped(httpResponse.getBody());
        }
        throw new QuickBooksException(parseAPIError(httpResponse));
    }

    private static HttpResponse makeAPICall(String method, String endpoint, String body, String accessToken) {
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

    private static Map<String, Object> buildCustomerData(Account acc, QuickBooksCustomerRequest request) {
        Map<String, Object> customer = new Map<String, Object>();

        customer.put('DisplayName', String.isNotBlank(request?.displayName) ? request.displayName : acc.Name);
        customer.put('CompanyName', String.isNotBlank(request?.companyName) ? request.companyName : acc.Name);

        if (request != null && String.isNotBlank(request.firstName)) {
            customer.put('GivenName', request.firstName);
        }
        if (request != null && String.isNotBlank(request.lastName)) {
            customer.put('FamilyName', request.lastName);
        }
        if (request != null && String.isNotBlank(request.email)) {
            customer.put('PrimaryEmailAddr', new Map<String, Object>{'Address' => request.email});
        }

        String phone = (request != null && String.isNotBlank(request.phone)) ? request.phone : acc.Phone;
        if (String.isNotBlank(phone)) {
            customer.put('PrimaryPhone', new Map<String, Object>{'FreeFormNumber' => phone});
        }

        customer.put('BillAddr', new Map<String, Object>{
            'Line1' => acc.BillingStreet,
            'City' => acc.BillingCity,
            'CountrySubDivisionCode' => acc.BillingState,
            'PostalCode' => acc.BillingPostalCode,
            'Country' => acc.BillingCountry
        });

        if (String.isNotBlank(acc.Website)) {
            customer.put('WebAddr', new Map<String, Object>{'URI' => acc.Website});
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
        
        // ALWAYS include Salesforce Opportunity ID in PrivateNote for payment tracing
        // This creates a reliable chain: Payment → Invoice → Estimate → Opportunity
        String privateNote = request.privateMemo != null ? request.privateMemo + '\n' : '';
        if (request.opportunityId != null) {
            privateNote += 'SF-Opp:' + request.opportunityId;
        }
        if (String.isNotBlank(privateNote)) {
            estimateData.put('PrivateNote', privateNote.trim());
        }

        // Tax settings
        if (request.applyTaxAfterDiscount != null) {
            estimateData.put('ApplyTaxAfterDiscount', request.applyTaxAfterDiscount);
        }

        // Force TotalTax to 0
        Map<String, Object> txnTaxDetail = new Map<String, Object>();
        txnTaxDetail.put('TotalTax', 0);
        estimateData.put('TxnTaxDetail', txnTaxDetail);
        
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
