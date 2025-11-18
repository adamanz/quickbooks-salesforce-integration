/**
 * Invocable Apex Actions for QuickBooks Integration
 * Provides methods that can be called from Salesforce Flows to interact with QuickBooks
 */
public with sharing class QuickBooksInvocableActions {

    /**
     * Create Customer in QuickBooks from Salesforce Account
     * Can be called from a Flow when an Account is created/updated
     */
    @InvocableMethod(label='Create QuickBooks Customer'
                     description='Creates or updates a customer in QuickBooks from a Salesforce Account'
                     category='QuickBooks')
    public static List<InvocableResult> createCustomer(List<InvocableRequest> requests) {
        List<InvocableResult> results = new List<InvocableResult>();

        for (InvocableRequest request : requests) {
            InvocableResult result = new InvocableResult();

            try {
                if (request.accountId == null) {
                    throw new QuickBooksException('Account ID is required');
                }

                // Get Account details
                Account acc = [
                    SELECT Id, Name, QuickBooks_Customer_Id__c, BillingStreet, BillingCity,
                           BillingState, BillingPostalCode, BillingCountry, Phone,
                           Fax, Website, Description
                    FROM Account
                    WHERE Id = :request.accountId
                    LIMIT 1
                ];

                // Get QuickBooks auth
                String accessToken = QuickBooksAuthProvider.getValidAccessToken();
                String companyId = QuickBooksAuthProvider.getCompanyId();

                // Check if customer already exists in QuickBooks
                if (String.isNotBlank(acc.QuickBooks_Customer_Id__c)) {
                    // Update existing customer
                    result.quickBooksId = updateCustomerInQuickBooks(acc, accessToken, companyId);
                    result.message = 'Customer updated successfully in QuickBooks';
                } else {
                    // Create new customer
                    result.quickBooksId = createCustomerInQuickBooks(acc, accessToken, companyId);
                    result.message = 'Customer created successfully in QuickBooks';

                    // Update Account with QB Customer ID
                    acc.QuickBooks_Customer_Id__c = result.quickBooksId;
                }

                // Update sync status
                acc.QuickBooks_Sync_Status__c = 'Synced';
                acc.QuickBooks_Last_Sync__c = DateTime.now();
                update acc;

                result.success = true;

            } catch (Exception e) {
                result.success = false;
                result.message = 'Error: ' + e.getMessage();
                logError('Create Customer', request.accountId, e.getMessage());
            }

            results.add(result);
        }

        return results;
    }

    /**
     * Create customer in QuickBooks API
     */
    private static String createCustomerInQuickBooks(Account acc, String accessToken, String companyId) {
        // Build customer JSON
        Map<String, Object> customer = new Map<String, Object>();
        customer.put('DisplayName', acc.Name);
        customer.put('CompanyName', acc.Name);

        // Add billing address if present
        if (String.isNotBlank(acc.BillingStreet)) {
            Map<String, Object> billAddr = new Map<String, Object>();
            billAddr.put('Line1', acc.BillingStreet);
            billAddr.put('City', acc.BillingCity);
            billAddr.put('CountrySubDivisionCode', acc.BillingState);
            billAddr.put('PostalCode', acc.BillingPostalCode);
            billAddr.put('Country', acc.BillingCountry);
            customer.put('BillAddr', billAddr);
        }

        // Add phone if present
        if (String.isNotBlank(acc.Phone)) {
            Map<String, Object> primaryPhone = new Map<String, Object>();
            primaryPhone.put('FreeFormNumber', acc.Phone);
            customer.put('PrimaryPhone', primaryPhone);
        }

        // Add notes
        if (String.isNotBlank(acc.Description)) {
            customer.put('Notes', acc.Description);
        }

        // Make API call
        String endpoint = getBaseUrl() + '/v3/company/' + companyId + '/customer';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setBody(JSON.serialize(customer));
        req.setTimeout(120000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new QuickBooksException('Failed to create customer: ' + res.getBody());
        }

        // Parse response and get customer ID
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Map<String, Object> createdCustomer = (Map<String, Object>) response.get('Customer');
        return (String) createdCustomer.get('Id');
    }

    /**
     * Update customer in QuickBooks API
     */
    private static String updateCustomerInQuickBooks(Account acc, String accessToken, String companyId) {
        // First, fetch the current customer to get SyncToken
        String endpoint = getBaseUrl() + '/v3/company/' + companyId + '/customer/' + acc.QuickBooks_Customer_Id__c;
        HttpRequest getReq = new HttpRequest();
        getReq.setEndpoint(endpoint);
        getReq.setMethod('GET');
        getReq.setHeader('Accept', 'application/json');
        getReq.setHeader('Authorization', 'Bearer ' + accessToken);
        getReq.setTimeout(120000);

        Http http = new Http();
        HttpResponse getRes = http.send(getReq);

        if (getRes.getStatusCode() != 200) {
            throw new QuickBooksException('Failed to fetch customer: ' + getRes.getBody());
        }

        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(getRes.getBody());
        Map<String, Object> existingCustomer = (Map<String, Object>) response.get('Customer');
        String syncToken = (String) existingCustomer.get('SyncToken');

        // Build updated customer
        Map<String, Object> customer = new Map<String, Object>();
        customer.put('Id', acc.QuickBooks_Customer_Id__c);
        customer.put('SyncToken', syncToken);
        customer.put('DisplayName', acc.Name);
        customer.put('CompanyName', acc.Name);

        // Add billing address
        if (String.isNotBlank(acc.BillingStreet)) {
            Map<String, Object> billAddr = new Map<String, Object>();
            billAddr.put('Line1', acc.BillingStreet);
            billAddr.put('City', acc.BillingCity);
            billAddr.put('CountrySubDivisionCode', acc.BillingState);
            billAddr.put('PostalCode', acc.BillingPostalCode);
            billAddr.put('Country', acc.BillingCountry);
            customer.put('BillAddr', billAddr);
        }

        // Add phone
        if (String.isNotBlank(acc.Phone)) {
            Map<String, Object> primaryPhone = new Map<String, Object>();
            primaryPhone.put('FreeFormNumber', acc.Phone);
            customer.put('PrimaryPhone', primaryPhone);
        }

        // Make update API call
        HttpRequest updateReq = new HttpRequest();
        updateReq.setEndpoint(getBaseUrl() + '/v3/company/' + companyId + '/customer');
        updateReq.setMethod('POST');
        updateReq.setHeader('Accept', 'application/json');
        updateReq.setHeader('Content-Type', 'application/json');
        updateReq.setHeader('Authorization', 'Bearer ' + accessToken);
        updateReq.setBody(JSON.serialize(customer));
        updateReq.setTimeout(120000);

        HttpResponse updateRes = http.send(updateReq);

        if (updateRes.getStatusCode() != 200) {
            throw new QuickBooksException('Failed to update customer: ' + updateRes.getBody());
        }

        return acc.QuickBooks_Customer_Id__c;
    }

    /**
     * Get QuickBooks API base URL
     */
    private static String getBaseUrl() {
        QuickBooks_Config__mdt config = QuickBooks_Config__mdt.getInstance('Default');
        return config.Is_Sandbox__c ?
               'https://sandbox-quickbooks.api.intuit.com' :
               'https://quickbooks.api.intuit.com';
    }

    /**
     * Log error to Integration Log
     */
    private static void logError(String context, String recordId, String errorMessage) {
        Integration_Log__c log = new Integration_Log__c(
            Integration_Type__c = 'QuickBooks Invocable Action',
            Context__c = context + ' - Record: ' + recordId,
            Error_Message__c = errorMessage,
            Timestamp__c = DateTime.now()
        );
        insert log;
    }

    /**
     * Custom exception class
     */
    public class QuickBooksException extends Exception {}

    /**
     * Invocable request wrapper
     */
    public class InvocableRequest {
        @InvocableVariable(label='Account ID' description='Salesforce Account ID' required=false)
        public String accountId;

        @InvocableVariable(label='Opportunity ID' description='Salesforce Opportunity ID' required=false)
        public String opportunityId;

        @InvocableVariable(label='Estimate ID' description='Salesforce Estimate ID' required=false)
        public String estimateId;
    }

    /**
     * Invocable result wrapper
     */
    public class InvocableResult {
        @InvocableVariable(label='Success' description='Whether the operation succeeded')
        public Boolean success;

        @InvocableVariable(label='Message' description='Success or error message')
        public String message;

        @InvocableVariable(label='QuickBooks ID' description='QuickBooks entity ID')
        public String quickBooksId;

        public InvocableResult() {
            this.success = false;
            this.message = '';
            this.quickBooksId = '';
        }
    }
}
