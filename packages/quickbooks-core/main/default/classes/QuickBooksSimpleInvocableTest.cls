@isTest
private class QuickBooksSimpleInvocableTest {

    @isTest
    static void testCreateCustomer() {
        // Create test account
        Account testAccount = new Account(
            Name = 'Test Account',
            BillingStreet = '123 Main St',
            BillingCity = 'San Francisco',
            BillingState = 'CA',
            BillingPostalCode = '94105',
            BillingCountry = 'USA',
            Phone = '555-1234'
        );
        insert testAccount;

        // Create request
        QuickBooksSimpleInvocable.SimpleCustomerRequest request = new QuickBooksSimpleInvocable.SimpleCustomerRequest();
        request.accountId = testAccount.Id;

        // Call invocable method
        Test.startTest();
        List<QuickBooksSimpleInvocable.SimpleResponse> responses =
            QuickBooksSimpleInvocable.createCustomer(new List<QuickBooksSimpleInvocable.SimpleCustomerRequest>{request});
        Test.stopTest();

        // Verify response
        System.assertEquals(1, responses.size());
        System.assertEquals(true, responses[0].success);
        System.assertNotEquals(null, responses[0].externalId);
        System.assert(responses[0].message.contains('Customer created'));

        // Verify integration log was created
        List<Integration_Log__c> logs = [SELECT Id FROM Integration_Log__c WHERE Record_Id__c = :testAccount.Id];
        System.assertEquals(1, logs.size());
    }

    @isTest
    static void testCreateCustomerError() {
        // Create request with invalid ID
        QuickBooksSimpleInvocable.SimpleCustomerRequest request = new QuickBooksSimpleInvocable.SimpleCustomerRequest();
        request.accountId = '001000000000000AAA'; // Invalid ID

        // Call invocable method
        Test.startTest();
        List<QuickBooksSimpleInvocable.SimpleResponse> responses =
            QuickBooksSimpleInvocable.createCustomer(new List<QuickBooksSimpleInvocable.SimpleCustomerRequest>{request});
        Test.stopTest();

        // Verify error response
        System.assertEquals(1, responses.size());
        System.assertEquals(false, responses[0].success);
        System.assert(responses[0].message.contains('Error'));
    }
}