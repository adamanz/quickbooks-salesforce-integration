/**
 * Test class for QuickBooksAPIService
 */
@isTest
private class QuickBooksAPIServiceTest {

    @TestSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Company',
            BillingStreet = '123 Test St',
            BillingCity = 'Test City',
            BillingState = 'CA',
            BillingPostalCode = '12345',
            BillingCountry = 'USA',
            Phone = '555-1234',
            Website = 'www.testcompany.com'
        );
        insert testAccount;

        // Create test Product
        Product2 testProduct = new Product2(
            Name = 'Test Product',
            ProductCode = 'TEST001',
            Description = 'Test Product Description',
            IsActive = true,
            Type__c = 'Service'
        );
        insert testProduct;

        // Create standard pricebook
        Id pricebookId = Test.getStandardPricebookId();

        // Create pricebook entry
        PricebookEntry testPBE = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = testProduct.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert testPBE;

        // Create test Opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 1000.00
        );
        insert testOpp;

        // Create OpportunityLineItem
        OpportunityLineItem testOLI = new OpportunityLineItem(
            OpportunityId = testOpp.Id,
            Product2Id = testProduct.Id,
            PricebookEntryId = testPBE.Id,
            Quantity = 10,
            UnitPrice = 100.00
        );
        insert testOLI;

        // Create QuickBooks Auth record
        QuickBooks_Auth__c auth = new QuickBooks_Auth__c(
            Company_Id__c = 'TEST_COMPANY_123',
            Access_Token__c = 'test_access_token_123456',
            Refresh_Token__c = 'test_refresh_token_123456',
            Token_Type__c = 'bearer',
            Token_Expiry__c = DateTime.now().addHours(1),
            Is_Active__c = true
        );
        insert auth;
    }

    /**
     * Test creating a QuickBooks customer
     */
    @isTest
    static void testCreateCustomer() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Company' LIMIT 1];

        // Setup HTTP mock
        Test.setMock(HttpCalloutMock.class, new QuickBooksHttpMock('customer_create_success'));

        // Prepare request
        QuickBooksAPIService.CustomerRequest request = new QuickBooksAPIService.CustomerRequest();
        request.accountId = testAccount.Id;
        request.companyId = 'TEST_COMPANY_123';

        Test.startTest();
        List<QuickBooksAPIService.CustomerResponse> responses =
            QuickBooksAPIService.createCustomer(new List<QuickBooksAPIService.CustomerRequest>{request});
        Test.stopTest();

        // Verify response
        System.assertEquals(1, responses.size());
        System.assertEquals(true, responses[0].success);
        System.assertEquals('QB_CUST_001', responses[0].quickBooksCustomerId);

        // Verify Account was updated
        Account updatedAccount = [SELECT QuickBooks_Customer_Id__c, QuickBooks_Sync_Status__c
                                 FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals('QB_CUST_001', updatedAccount.QuickBooks_Customer_Id__c);
        System.assertEquals('Synced', updatedAccount.QuickBooks_Sync_Status__c);
    }

    /**
     * Test creating a QuickBooks invoice
     */
    @isTest
    static void testCreateInvoice() {
        Opportunity testOpp = [SELECT Id, AccountId FROM Opportunity
                              WHERE Name = 'Test Opportunity' LIMIT 1];

        // Update Account with QuickBooks Customer ID
        Account acc = new Account(Id = testOpp.AccountId);
        acc.QuickBooks_Customer_Id__c = 'QB_CUST_001';
        update acc;

        // Setup HTTP mock
        Test.setMock(HttpCalloutMock.class, new QuickBooksHttpMock('invoice_create_success'));

        // Prepare request
        QuickBooksAPIService.InvoiceRequest request = new QuickBooksAPIService.InvoiceRequest();
        request.opportunityId = testOpp.Id;
        request.companyId = 'TEST_COMPANY_123';

        Test.startTest();
        List<QuickBooksAPIService.InvoiceResponse> responses =
            QuickBooksAPIService.createInvoice(new List<QuickBooksAPIService.InvoiceRequest>{request});
        Test.stopTest();

        // Verify response
        System.assertEquals(1, responses.size());
        System.assertEquals(true, responses[0].success);
        System.assertEquals('QB_INV_001', responses[0].quickBooksInvoiceId);
        System.assertEquals('INV-1001', responses[0].quickBooksInvoiceNumber);

        // Verify Opportunity was updated
        Opportunity updatedOpp = [SELECT QuickBooks_Invoice_Id__c, QuickBooks_Invoice_Number__c,
                                        QuickBooks_Sync_Status__c
                                 FROM Opportunity WHERE Id = :testOpp.Id];
        System.assertEquals('QB_INV_001', updatedOpp.QuickBooks_Invoice_Id__c);
        System.assertEquals('INV-1001', updatedOpp.QuickBooks_Invoice_Number__c);
        System.assertEquals('Synced', updatedOpp.QuickBooks_Sync_Status__c);
    }

    /**
     * Test syncing payments from QuickBooks
     */
    @isTest
    static void testSyncPayments() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Company' LIMIT 1];

        // Setup HTTP mock
        Test.setMock(HttpCalloutMock.class, new QuickBooksHttpMock('payment_sync_success'));

        // Prepare request
        QuickBooksAPIService.PaymentSyncRequest request = new QuickBooksAPIService.PaymentSyncRequest();
        request.accountId = testAccount.Id;
        request.quickBooksCustomerId = 'QB_CUST_001';
        request.companyId = 'TEST_COMPANY_123';

        Test.startTest();
        List<QuickBooksAPIService.PaymentSyncResponse> responses =
            QuickBooksAPIService.syncPayments(new List<QuickBooksAPIService.PaymentSyncRequest>{request});
        Test.stopTest();

        // Verify response
        System.assertEquals(1, responses.size());
        System.assertEquals(true, responses[0].success);
        System.assertEquals(3, responses[0].paymentsProcessed);
    }

    /**
     * Test creating a QuickBooks item
     */
    @isTest
    static void testCreateItem() {
        Product2 testProduct = [SELECT Id FROM Product2 WHERE Name = 'Test Product' LIMIT 1];

        // Setup HTTP mock
        Test.setMock(HttpCalloutMock.class, new QuickBooksHttpMock('item_create_success'));

        // Prepare request
        QuickBooksAPIService.ItemRequest request = new QuickBooksAPIService.ItemRequest();
        request.productId = testProduct.Id;
        request.companyId = 'TEST_COMPANY_123';

        Test.startTest();
        List<QuickBooksAPIService.ItemResponse> responses =
            QuickBooksAPIService.createItem(new List<QuickBooksAPIService.ItemRequest>{request});
        Test.stopTest();

        // Verify response
        System.assertEquals(1, responses.size());
        System.assertEquals(true, responses[0].success);
        System.assertEquals('QB_ITEM_001', responses[0].quickBooksItemId);

        // Verify Product was updated
        Product2 updatedProduct = [SELECT QuickBooks_Item_Id__c, QuickBooks_Sync_Status__c
                                  FROM Product2 WHERE Id = :testProduct.Id];
        System.assertEquals('QB_ITEM_001', updatedProduct.QuickBooks_Item_Id__c);
        System.assertEquals('Synced', updatedProduct.QuickBooks_Sync_Status__c);
    }

    /**
     * Test error handling
     */
    @isTest
    static void testErrorHandling() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Company' LIMIT 1];

        // Setup HTTP mock for error
        Test.setMock(HttpCalloutMock.class, new QuickBooksHttpMock('error'));

        // Prepare request
        QuickBooksAPIService.CustomerRequest request = new QuickBooksAPIService.CustomerRequest();
        request.accountId = testAccount.Id;
        request.companyId = 'TEST_COMPANY_123';

        Test.startTest();
        List<QuickBooksAPIService.CustomerResponse> responses =
            QuickBooksAPIService.createCustomer(new List<QuickBooksAPIService.CustomerRequest>{request});
        Test.stopTest();

        // Verify error response
        System.assertEquals(1, responses.size());
        System.assertEquals(false, responses[0].success);
        System.assert(responses[0].message.contains('Error'));

        // Verify error was logged
        List<Integration_Log__c> logs = [SELECT Error_Message__c FROM Integration_Log__c
                                        WHERE Record_Id__c = :testAccount.Id];
        System.assertEquals(1, logs.size());
    }

    /**
     * HTTP Mock class for QuickBooks API
     */
    public class QuickBooksHttpMock implements HttpCalloutMock {
        private String responseType;

        public QuickBooksHttpMock(String responseType) {
            this.responseType = responseType;
        }

        public HTTPResponse respond(HTTPRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');

            switch on responseType {
                when 'customer_create_success' {
                    response.setStatusCode(200);
                    response.setBody('{"Customer": {"Id": "QB_CUST_001", "DisplayName": "Test Company"}}');
                }
                when 'invoice_create_success' {
                    response.setStatusCode(200);
                    response.setBody('{"Invoice": {"Id": "QB_INV_001", "DocNumber": "INV-1001"}}');
                }
                when 'payment_sync_success' {
                    response.setStatusCode(200);
                    response.setBody('{"QueryResponse": {"Payment": [{"Id": "1"}, {"Id": "2"}, {"Id": "3"}]}}');
                }
                when 'item_create_success' {
                    response.setStatusCode(200);
                    response.setBody('{"Item": {"Id": "QB_ITEM_001", "Name": "Test Product"}}');
                }
                when 'error' {
                    response.setStatusCode(400);
                    response.setBody('{"Fault": {"Error": [{"Message": "Invalid request", "Detail": "Missing required field"}]}}');
                }
            }

            return response;
        }
    }
}