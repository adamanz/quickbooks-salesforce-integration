@isTest
private class QuickBooksInvocableActionsTest {

    @TestSetup
    static void setup() {
        // Create test Account
        Account acc = new Account(
            Name = 'Test Account',
            BillingStreet = '123 Test St',
            BillingCity = 'Test City',
            BillingState = 'CA',
            BillingPostalCode = '90210',
            BillingCountry = 'USA',
            Phone = '555-555-5555',
            Description = 'Test Description'
        );
        insert acc;

        // Create auth record
        QuickBooks_Auth__c auth = new QuickBooks_Auth__c(
            Company_Id__c = '123456789',
            Access_Token__c = 'test_token',
            Refresh_Token__c = 'test_refresh',
            Token_Expiry__c = DateTime.now().addHours(1),
            Is_Active__c = true
        );
        insert auth;
    }

    @isTest
    static void testCreateCustomerNew() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        QuickBooksInvocableActions.InvocableRequest req = new QuickBooksInvocableActions.InvocableRequest();
        req.accountId = acc.Id;

        // Mock for create customer
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('CREATE'));

        Test.startTest();
        List<QuickBooksInvocableActions.InvocableResult> results = 
            QuickBooksInvocableActions.createCustomer(new List<QuickBooksInvocableActions.InvocableRequest>{req});
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].success);
        System.assertEquals('QB-123', results[0].quickBooksId);

        // Verify Account updated
        Account updatedAcc = [SELECT QuickBooks_Customer_Id__c, QuickBooks_Sync_Status__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('QB-123', updatedAcc.QuickBooks_Customer_Id__c);
        System.assertEquals('Synced', updatedAcc.QuickBooks_Sync_Status__c);
    }

    @isTest
    static void testCreateCustomerUpdate() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        acc.QuickBooks_Customer_Id__c = 'QB-EXISTING';
        update acc;
        
        QuickBooksInvocableActions.InvocableRequest req = new QuickBooksInvocableActions.InvocableRequest();
        req.accountId = acc.Id;

        // Mock for update (GET then POST)
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('UPDATE'));

        Test.startTest();
        List<QuickBooksInvocableActions.InvocableResult> results = 
            QuickBooksInvocableActions.createCustomer(new List<QuickBooksInvocableActions.InvocableRequest>{req});
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].success);
        System.assertEquals('QB-EXISTING', results[0].quickBooksId);
    }

    @isTest
    static void testCreateCustomerError() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        QuickBooksInvocableActions.InvocableRequest req = new QuickBooksInvocableActions.InvocableRequest();
        req.accountId = acc.Id;

        // Mock for error
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('ERROR'));

        Test.startTest();
        List<QuickBooksInvocableActions.InvocableResult> results = 
            QuickBooksInvocableActions.createCustomer(new List<QuickBooksInvocableActions.InvocableRequest>{req});
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('Error'));
    }

    @isTest
    static void testMissingAccountId() {
        QuickBooksInvocableActions.InvocableRequest req = new QuickBooksInvocableActions.InvocableRequest();
        // No Account ID

        Test.startTest();
        List<QuickBooksInvocableActions.InvocableResult> results = 
            QuickBooksInvocableActions.createCustomer(new List<QuickBooksInvocableActions.InvocableRequest>{req});
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('Account ID is required'));
    }

    public class MockHttpResponseGenerator implements HttpCalloutMock {
        private String type;

        public MockHttpResponseGenerator(String type) {
            this.type = type;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (type == 'CREATE') {
                res.setStatusCode(200);
                res.setBody('{"Customer": {"Id": "QB-123"}}');
            } else if (type == 'UPDATE') {
                if (req.getMethod() == 'GET') {
                    res.setStatusCode(200);
                    res.setBody('{"Customer": {"Id": "QB-EXISTING", "SyncToken": "0"}}');
                } else {
                    res.setStatusCode(200);
                    res.setBody('{"Customer": {"Id": "QB-EXISTING", "SyncToken": "1"}}');
                }
            } else if (type == 'ERROR') {
                res.setStatusCode(400);
                res.setBody('{"Fault": {"Error": [{"Message": "Bad Request"}]}}');
            }
            return res;
        }
    }
}
