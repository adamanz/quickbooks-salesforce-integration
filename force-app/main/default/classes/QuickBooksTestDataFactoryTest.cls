/**
 * Test class for QuickBooksTestDataFactory
 * Tests test data creation utilities
 */
@isTest
private class QuickBooksTestDataFactoryTest {

    @isTest
    static void testCreateTestAccount() {
        Test.startTest();
        Account acc = QuickBooksTestDataFactory.createTestAccount('Test Account');
        Test.stopTest();

        System.assertNotEquals(null, acc.Id, 'Account should be inserted');
        System.assert(acc.Name.contains('Test Account'), 'Account name should contain provided name');
        System.assertEquals('Test City', acc.BillingCity);
    }

    @isTest
    static void testCreateTestAccountWithQBId() {
        Test.startTest();
        Account acc = QuickBooksTestDataFactory.createTestAccountWithQBId('QB Test Account', 'QB-12345');
        Test.stopTest();

        System.assertNotEquals(null, acc.Id, 'Account should be inserted');
        System.assertEquals('QB-12345', acc.QuickBooks_Customer_Id__c);
        System.assertEquals('Synced', acc.QuickBooks_Sync_Status__c);
    }

    @isTest
    static void testCreateTestProduct() {
        Test.startTest();
        Product2 prod = QuickBooksTestDataFactory.createTestProduct('Test Product');
        Test.stopTest();

        System.assertNotEquals(null, prod.Id, 'Product should be inserted');
        System.assert(prod.Name.contains('Test Product'), 'Product name should contain provided name');
        System.assertEquals(true, prod.IsActive);
    }

    @isTest
    static void testCreateTestProductWithQBId() {
        Test.startTest();
        Product2 prod = QuickBooksTestDataFactory.createTestProductWithQBId('QB Product', 'QB-ITEM-001');
        Test.stopTest();

        System.assertNotEquals(null, prod.Id, 'Product should be inserted');
        System.assertEquals('QB-ITEM-001', prod.QuickBooks_Item_Id__c);
    }

    @isTest
    static void testCreateTestPricebookEntry() {
        Product2 prod = QuickBooksTestDataFactory.createTestProduct('Test Product');

        Test.startTest();
        PricebookEntry pbe = QuickBooksTestDataFactory.createTestPricebookEntry(prod.Id, 150.00);
        Test.stopTest();

        System.assertNotEquals(null, pbe.Id, 'PricebookEntry should be inserted');
        System.assertEquals(150.00, pbe.UnitPrice);
        System.assertEquals(true, pbe.IsActive);
    }

    @isTest
    static void testCreateTestOpportunity() {
        Account acc = QuickBooksTestDataFactory.createTestAccount('Test Account');

        Test.startTest();
        Opportunity opp = QuickBooksTestDataFactory.createTestOpportunity('Test Opp', acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, opp.Id, 'Opportunity should be inserted');
        System.assert(opp.Name.contains('Test Opp'), 'Opportunity name should contain provided name');
        System.assertEquals('Closed Won', opp.StageName);
        System.assertEquals(acc.Id, opp.AccountId);
    }

    @isTest
    static void testCreateTestOpportunityWithQBId() {
        Account acc = QuickBooksTestDataFactory.createTestAccount('Test Account');

        Test.startTest();
        Opportunity opp = QuickBooksTestDataFactory.createTestOpportunityWithQBId('Test Opp', acc.Id, 'INV-123');
        Test.stopTest();

        System.assertNotEquals(null, opp.Id, 'Opportunity should be inserted');
        System.assertEquals('INV-123', opp.QuickBooks_Invoice_Id__c);
        System.assertEquals('1001', opp.QuickBooks_Invoice_Number__c);
    }

    @isTest
    static void testCreateTestOpportunityLineItem() {
        Account acc = QuickBooksTestDataFactory.createTestAccount('Test Account');
        Opportunity opp = QuickBooksTestDataFactory.createTestOpportunity('Test Opp', acc.Id);
        Product2 prod = QuickBooksTestDataFactory.createTestProduct('Test Product');
        PricebookEntry pbe = QuickBooksTestDataFactory.createTestPricebookEntry(prod.Id, 100.00);

        Test.startTest();
        OpportunityLineItem oli = QuickBooksTestDataFactory.createTestOpportunityLineItem(
            opp.Id, pbe.Id, 2, 50.00
        );
        Test.stopTest();

        System.assertNotEquals(null, oli.Id, 'OpportunityLineItem should be inserted');
        System.assertEquals(2, oli.Quantity);
        System.assertEquals(50.00, oli.UnitPrice);
    }

    @isTest
    static void testCreateTestOpportunityLineItems() {
        Account acc = QuickBooksTestDataFactory.createTestAccount('Test Account');
        Opportunity opp = QuickBooksTestDataFactory.createTestOpportunity('Test Opp', acc.Id);

        Test.startTest();
        List<OpportunityLineItem> items = QuickBooksTestDataFactory.createTestOpportunityLineItems(opp.Id, 3);
        Test.stopTest();

        System.assertEquals(3, items.size(), 'Should create 3 line items');
        System.assertNotEquals(null, items[0].Id, 'Line items should be inserted');
    }

    @isTest
    static void testCreateTestAuth() {
        Test.startTest();
        QuickBooks_Auth__c auth = QuickBooksTestDataFactory.createTestAuth(
            'COMPANY-123', 'access_token', 'refresh_token', true
        );
        Test.stopTest();

        System.assertNotEquals(null, auth.Id, 'Auth should be inserted');
        System.assertEquals('COMPANY-123', auth.Company_Id__c);
        System.assertEquals('access_token', auth.Access_Token__c);
        System.assertEquals(true, auth.Is_Active__c);
    }

    @isTest
    static void testCreateCompleteTestScenario() {
        Test.startTest();
        Map<String, Object> scenario = QuickBooksTestDataFactory.createCompleteTestScenario('Complete Test');
        Test.stopTest();

        System.assertNotEquals(null, scenario, 'Scenario should be created');
        System.assert(scenario.containsKey('account'), 'Should contain account');
        System.assert(scenario.containsKey('product'), 'Should contain product');
        System.assert(scenario.containsKey('opportunity'), 'Should contain opportunity');
        System.assert(scenario.containsKey('auth'), 'Should contain auth');
        System.assert(scenario.containsKey('companyId'), 'Should contain companyId');

        Account acc = (Account) scenario.get('account');
        Opportunity opp = (Opportunity) scenario.get('opportunity');
        QuickBooks_Auth__c auth = (QuickBooks_Auth__c) scenario.get('auth');

        System.assertNotEquals(null, acc.Id, 'Account should be inserted');
        System.assertNotEquals(null, opp.Id, 'Opportunity should be inserted');
        System.assertNotEquals(null, auth.Id, 'Auth should be inserted');
    }

    @isTest
    static void testCreateScenarioWithQBCustomer() {
        Test.startTest();
        Map<String, Object> scenario = QuickBooksTestDataFactory.createScenarioWithQBCustomer(
            'QB Customer Test', 'QB-CUST-789'
        );
        Test.stopTest();

        System.assertNotEquals(null, scenario, 'Scenario should be created');
        Account acc = (Account) scenario.get('account');
        System.assertEquals('QB-CUST-789', acc.QuickBooks_Customer_Id__c);
        System.assertEquals('Synced', acc.QuickBooks_Sync_Status__c);
    }

    @isTest
    static void testBuildCustomerRequest() {
        Account acc = QuickBooksTestDataFactory.createTestAccount('Test Account');

        Test.startTest();
        QuickBooksCustomerRequest req = QuickBooksTestDataFactory.buildCustomerRequest(acc.Id, 'COMP-123');
        Test.stopTest();

        System.assertNotEquals(null, req, 'Request should be created');
        System.assertEquals(acc.Id, req.accountId);
        System.assertEquals('COMP-123', req.companyId);
    }

    @isTest
    static void testBuildInvoiceRequest() {
        Account acc = QuickBooksTestDataFactory.createTestAccount('Test Account');
        Opportunity opp = QuickBooksTestDataFactory.createTestOpportunity('Test Opp', acc.Id);

        Test.startTest();
        QuickBooksInvoiceRequest req = QuickBooksTestDataFactory.buildInvoiceRequest(opp.Id, 'COMP-456');
        Test.stopTest();

        System.assertNotEquals(null, req, 'Request should be created');
        System.assertEquals(opp.Id, req.opportunityId);
        System.assertEquals('COMP-456', req.companyId);
    }

    @isTest
    static void testCreateIntegrationLog() {
        Account acc = QuickBooksTestDataFactory.createTestAccount('Test Account');

        Test.startTest();
        Integration_Log__c log = QuickBooksTestDataFactory.createIntegrationLog(
            'QuickBooks', 'Test Context', 'Test Error', acc.Id
        );
        Test.stopTest();

        System.assertNotEquals(null, log.Id, 'Log should be inserted');
        System.assertEquals('QuickBooks', log.Integration_Type__c);
        System.assertEquals('Test Context', log.Context__c);
        System.assertEquals('Test Error', log.Error_Message__c);
    }
}
