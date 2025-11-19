@isTest
private class QuickBooksAPIServiceSimpleTest {

    @isTest
    static void testCreateCustomer() {
        // Create test account
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;

        // Create request with all fields
        QuickBooksCustomerRequest request = new QuickBooksCustomerRequest();
        request.accountId = testAccount.Id;
        request.fullName = 'John Doe';
        request.displayName = 'Test Account';
        request.firstName = 'John';
        request.lastName = 'Doe';
        request.companyName = 'Test Company';
        request.email = 'test@example.com';
        request.phone = '555-1234';

        // Call method
        Test.startTest();
        List<QuickBooksCustomerResponse> responses =
            QuickBooksAPIServiceSimple.createCustomer(new List<QuickBooksCustomerRequest>{request});
        Test.stopTest();

        // Verify response
        System.assertEquals(1, responses.size());
        System.assertEquals(true, responses[0].success);
        System.assertNotEquals(null, responses[0].quickBooksCustomerId);
    }

    @isTest
    static void testCreateEstimate() {
        // Create test opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert testOpp;

        // Create request with line items
        QuickBooksEstimateRequest request = new QuickBooksEstimateRequest();
        request.opportunityId = testOpp.Id;
        request.companyId = 'TEST123';
        request.customerRef = 'CUST-123';
        request.customerName = 'Test Customer';

        // Create line items JSON
        List<Map<String, Object>> lineItems = new List<Map<String, Object>>();
        Map<String, Object> item1 = new Map<String, Object>();
        item1.put('description', 'Test Item 1');
        item1.put('quantity', 2);
        item1.put('unitPrice', 100);
        item1.put('amount', 200);
        lineItems.add(item1);
        request.lineItemsJson = JSON.serialize(lineItems);

        // Call method
        Test.startTest();
        List<QuickBooksEstimateResponse> responses = QuickBooksAPIServiceSimple.createEstimate(
            new List<QuickBooksEstimateRequest>{request}
        );
        Test.stopTest();

        // Verify response
        System.assertEquals(1, responses.size());
        System.assertEquals(true, responses[0].success);
        System.assertNotEquals(null, responses[0].quickBooksEstimateId);
    }

    @isTest
    static void testEstimateSimpleInvocable() {
        // Create test opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert testOpp;

        // Create request
        QuickBooksEstimateRequest request = new QuickBooksEstimateRequest();
        request.opportunityId = testOpp.Id;
        request.companyId = 'TEST123';
        request.customerRef = 'CUST-456';
        request.estimateDate = Date.today();
        request.expirationDate = Date.today().addDays(30);

        // Call invocable method
        Test.startTest();
        List<QuickBooksEstimateResponse> responses =
            QuickBooksEstimateSimpleInvocable.createEstimate(
                new List<QuickBooksEstimateRequest>{request}
            );
        Test.stopTest();

        // Verify response
        System.assertEquals(1, responses.size());
        System.assertEquals(true, responses[0].success);
    }

    @isTest
    static void testCreateInvoice() {
        // Create test opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert testOpp;

        // Create request
        QuickBooksInvoiceRequest request = new QuickBooksInvoiceRequest();
        request.opportunityId = testOpp.Id;
        request.companyId = 'TEST123';

        // Call method
        Test.startTest();
        QuickBooksInvoiceResponse response = QuickBooksAPIServiceSimple.createInvoice(request);
        Test.stopTest();

        // Verify response
        System.assertEquals(true, response.success);
        System.assertNotEquals(null, response.quickBooksInvoiceId);
    }

    @isTest
    static void testCustomerInvocable() {
        // Create test account
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;

        // Create request with all fields
        QuickBooksCustomerRequest request = new QuickBooksCustomerRequest();
        request.accountId = testAccount.Id;
        request.fullName = 'Jane Smith';
        request.displayName = 'Test Account';
        request.firstName = 'Jane';
        request.lastName = 'Smith';
        request.companyName = 'Test Company';
        request.email = 'jane@example.com';
        request.phone = '555-5678';

        // Call invocable method
        Test.startTest();
        List<QuickBooksCustomerResponse> responses =
            QuickBooksCustomerInvocable.createCustomer(new List<QuickBooksCustomerRequest>{request});
        Test.stopTest();

        // Verify response
        System.assertEquals(1, responses.size());
        System.assertEquals(true, responses[0].success);
    }
}