/**
 * Test class for QuickBooksWebhookSimple with full coverage
 */
@isTest
private class QuickBooksWebhookSimpleTest {

    @isTest
    static void testHandleWebhook_Success() {
        // Prepare test webhook payload
        String testPayload = '{"eventNotifications":[{"realmId":"123","dataChangeEvent":{"entities":[{"name":"Payment","id":"1234","operation":"Create"}]}}]}';

        // Setup REST context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/quickbooks/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(testPayload);
        req.addHeader('Content-Type', 'application/json');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksWebhookSimple.handleWebhook();
        Test.stopTest();

        // Verify response
        System.assertEquals(200, res.statusCode, 'Should return 200 status');
        System.assertEquals('Webhook received successfully', res.responseBody.toString());

        // Verify Integration_Log__c was created
        List<Integration_Log__c> logs = [
            SELECT Id, Integration_Type__c, Context__c
            FROM Integration_Log__c
            WHERE Integration_Type__c = 'QuickBooks Webhook'
        ];
        System.assertEquals(1, logs.size(), 'Should create one log entry');
        System.assertEquals('Webhook Received', logs[0].Context__c);
    }

    @isTest
    static void testHandleWebhook_EmptyBody() {
        // Setup REST context with empty body
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/quickbooks/webhook';
        req.httpMethod = 'POST';
        req.requestBody = null;

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksWebhookSimple.handleWebhook();
        Test.stopTest();

        // Should still succeed
        System.assertEquals(200, res.statusCode, 'Should return 200 even with empty body');

        // Verify log was created
        List<Integration_Log__c> logs = [
            SELECT Id FROM Integration_Log__c
            WHERE Integration_Type__c = 'QuickBooks Webhook'
        ];
        System.assertEquals(1, logs.size(), 'Should create log for empty body');
    }

    @isTest
    static void testHandleWebhook_Exception() {
        // We need to force an exception - we'll mock a DML exception
        // by making the Error_Message__c field too long
        String hugePayload = '';
        for (Integer i = 0; i < 33000; i++) {
            hugePayload += 'x';
        }

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/quickbooks/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(hugePayload);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksWebhookSimple.handleWebhook();
        Test.stopTest();

        // Should handle the exception gracefully
        System.assertEquals(200, res.statusCode, 'Should handle large payloads gracefully');
    }

    @isTest
    static void testVerifyEndpoint_WithChallenge() {
        // Test the verification endpoint with challenge
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/quickbooks/webhook';
        req.httpMethod = 'GET';
        req.params.put('challenge', 'test-challenge-123');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksWebhookSimple.verifyEndpoint();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        System.assertEquals('test-challenge-123', res.responseBody.toString());
    }

    @isTest
    static void testVerifyEndpoint_WithoutChallenge() {
        // Test the verification endpoint without challenge
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/quickbooks/webhook';
        req.httpMethod = 'GET';

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksWebhookSimple.verifyEndpoint();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        System.assertEquals('Missing challenge parameter', res.responseBody.toString());
    }

    @isTest
    static void testVerifyEndpoint_EmptyChallenge() {
        // Test with empty challenge parameter
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/quickbooks/webhook';
        req.httpMethod = 'GET';
        req.params.put('challenge', '');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksWebhookSimple.verifyEndpoint();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }
}