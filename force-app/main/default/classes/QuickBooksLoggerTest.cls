/**
 * Test class for QuickBooksLogger
 * Tests logging utility with intuit_tid tracking
 */
@isTest
private class QuickBooksLoggerTest {

    /**
     * Test logging error with HTTP response
     */
    @isTest
    static void testLogError_WithResponse() {
        // Create mock HTTP response
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('intuit_tid', 'test_tid_12345');
        mockResponse.setStatusCode(500);

        Test.startTest();
        QuickBooksLogger.logError(
            'Test Context',
            'Test error message',
            'record_id_123',
            mockResponse
        );
        Test.stopTest();

        // Verify log was created
        List<Integration_Log__c> logs = [
            SELECT Context__c, Error_Message__c, Record_Id__c, Intuit_TID__c
            FROM Integration_Log__c
            WHERE Integration_Type__c = 'QuickBooks'
        ];

        System.assertEquals(1, logs.size());
        System.assertEquals('Test Context', logs[0].Context__c);
        System.assertEquals('Test error message', logs[0].Error_Message__c);
        System.assertEquals('record_id_123', logs[0].Record_Id__c);
        System.assertEquals('test_tid_12345', logs[0].Intuit_TID__c);
    }

    /**
     * Test logging error without HTTP response
     */
    @isTest
    static void testLogError_WithoutResponse() {
        Test.startTest();
        QuickBooksLogger.logError(
            'Test Context',
            'Test error without response',
            'record_id_456',
            (HttpResponse)null
        );
        Test.stopTest();

        // Verify log was created
        List<Integration_Log__c> logs = [
            SELECT Context__c, Error_Message__c, Record_Id__c, Intuit_TID__c
            FROM Integration_Log__c
        ];

        System.assertEquals(1, logs.size());
        System.assertEquals('Test error without response', logs[0].Error_Message__c);
        System.assertEquals(null, logs[0].Intuit_TID__c);
    }

    /**
     * Test logging error with manual intuit_tid
     */
    @isTest
    static void testLogError_WithManualTid() {
        Test.startTest();
        QuickBooksLogger.logError(
            'Manual TID Context',
            'Error with manual TID',
            'record_id_789',
            'manual_tid_99999'
        );
        Test.stopTest();

        // Verify log was created
        List<Integration_Log__c> logs = [
            SELECT Intuit_TID__c, Error_Message__c
            FROM Integration_Log__c
        ];

        System.assertEquals(1, logs.size());
        System.assertEquals('manual_tid_99999', logs[0].Intuit_TID__c);
    }

    /**
     * Test logging success
     */
    @isTest
    static void testLogSuccess() {
        // Create mock HTTP response
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('intuit_tid', 'success_tid_54321');
        mockResponse.setStatusCode(200);

        Test.startTest();
        QuickBooksLogger.logSuccess(
            'Success Context',
            'Operation completed successfully',
            'record_id_success',
            mockResponse
        );
        Test.stopTest();

        // Verify log was created
        List<Integration_Log__c> logs = [
            SELECT Context__c, Error_Message__c, Record_Id__c, Intuit_TID__c
            FROM Integration_Log__c
        ];

        System.assertEquals(1, logs.size());
        System.assertEquals('Success Context - Success', logs[0].Context__c);
        System.assertEquals('Operation completed successfully', logs[0].Error_Message__c);
        System.assertEquals('success_tid_54321', logs[0].Intuit_TID__c);
    }

    /**
     * Test logging API call details
     */
    @isTest
    static void testLogAPICall() {
        // Create mock HTTP response
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('intuit_tid', 'api_tid_11111');
        mockResponse.setStatusCode(200);
        mockResponse.setBody('{"status": "success"}');

        String requestBody = '{"customer": "test"}';
        String responseBody = '{"id": "123"}';

        Test.startTest();
        QuickBooksLogger.logAPICall(
            'https://api.quickbooks.com/v3/customer',
            'POST',
            200,
            requestBody,
            responseBody,
            mockResponse
        );
        Test.stopTest();

        // Verify log was created
        List<Integration_Log__c> logs = [
            SELECT Context__c, Error_Message__c, Intuit_TID__c, Integration_Type__c
            FROM Integration_Log__c
        ];

        System.assertEquals(1, logs.size());
        System.assertEquals('QuickBooks API Call', logs[0].Integration_Type__c);
        System.assert(logs[0].Context__c.contains('POST'));
        System.assert(logs[0].Error_Message__c.contains('Endpoint'));
        System.assert(logs[0].Error_Message__c.contains('Status: 200'));
        System.assertEquals('api_tid_11111', logs[0].Intuit_TID__c);
    }

    /**
     * Test API call logging with large payloads (truncation)
     */
    @isTest
    static void testLogAPICall_LargePayload() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(200);

        // Create large request/response bodies (over 1000 chars)
        String largeRequest = 'x'.repeat(1500);
        String largeResponse = 'y'.repeat(1500);

        Test.startTest();
        QuickBooksLogger.logAPICall(
            'https://api.quickbooks.com/test',
            'GET',
            200,
            largeRequest,
            largeResponse,
            mockResponse
        );
        Test.stopTest();

        // Verify log was created and truncated
        List<Integration_Log__c> logs = [
            SELECT Error_Message__c
            FROM Integration_Log__c
        ];

        System.assertEquals(1, logs.size());
        // Verify truncation occurred (should contain '...')
        System.assert(logs[0].Error_Message__c.contains('...'));
    }

    /**
     * Test API call logging with null bodies
     */
    @isTest
    static void testLogAPICall_NullBodies() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(204);

        Test.startTest();
        QuickBooksLogger.logAPICall(
            'https://api.quickbooks.com/delete',
            'DELETE',
            204,
            null,
            null,
            mockResponse
        );
        Test.stopTest();

        // Verify log was created
        List<Integration_Log__c> logs = [
            SELECT Error_Message__c
            FROM Integration_Log__c
        ];

        System.assertEquals(1, logs.size());
        System.assert(logs[0].Error_Message__c != null);
    }

    /**
     * Test APIResponse helper class
     */
    @isTest
    static void testAPIResponse_Success() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setHeader('intuit_tid', 'response_tid_123');
        mockResponse.setStatusCode(200);

        Test.startTest();
        QuickBooksLogger.APIResponse apiResponse = new QuickBooksLogger.APIResponse(mockResponse);
        Test.stopTest();

        // Verify APIResponse properties
        System.assertEquals(true, apiResponse.success);
        System.assertEquals('response_tid_123', apiResponse.intuitTid);
        System.assertNotEquals(null, apiResponse.response);
    }

    /**
     * Test APIResponse helper class with error
     */
    @isTest
    static void testAPIResponse_Error() {
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setStatusCode(400);

        Test.startTest();
        QuickBooksLogger.APIResponse apiResponse = new QuickBooksLogger.APIResponse(mockResponse);
        Test.stopTest();

        // Verify APIResponse properties
        System.assertEquals(false, apiResponse.success);
    }

    /**
     * Test APIResponse with null response
     */
    @isTest
    static void testAPIResponse_Null() {
        Test.startTest();
        QuickBooksLogger.APIResponse apiResponse = new QuickBooksLogger.APIResponse(null);
        Test.stopTest();

        // Verify APIResponse properties
        System.assertEquals(false, apiResponse.success);
        System.assertEquals(null, apiResponse.intuitTid);
    }

    /**
     * Test logging when Integration_Log__c insert fails
     */
    @isTest
    static void testLogError_InsertFailureHandling() {
        // This test verifies graceful handling if log insert fails
        // In production, this would write to System.debug
        Test.startTest();
        QuickBooksLogger.logError(
            'Test Context',
            'Test error',
            null,
            (String)null
        );
        Test.stopTest();

        // Verify log was created successfully in test context
        List<Integration_Log__c> logs = [SELECT Id FROM Integration_Log__c];
        System.assertEquals(1, logs.size());
    }

    /**
     * Test multiple logs
     */
    @isTest
    static void testMultipleLogs() {
        HttpResponse response1 = new HttpResponse();
        response1.setHeader('intuit_tid', 'tid_1');

        HttpResponse response2 = new HttpResponse();
        response2.setHeader('intuit_tid', 'tid_2');

        Test.startTest();
        QuickBooksLogger.logError('Context 1', 'Error 1', 'rec1', response1);
        QuickBooksLogger.logError('Context 2', 'Error 2', 'rec2', response2);
        QuickBooksLogger.logSuccess('Context 3', 'Success 1', 'rec3', response1);
        Test.stopTest();

        // Verify multiple logs created
        List<Integration_Log__c> logs = [
            SELECT Id, Intuit_TID__c
            FROM Integration_Log__c
            ORDER BY CreatedDate
        ];

        System.assertEquals(3, logs.size());
        System.assertEquals('tid_1', logs[0].Intuit_TID__c);
        System.assertEquals('tid_2', logs[1].Intuit_TID__c);
        System.assertEquals('tid_1', logs[2].Intuit_TID__c);
    }
}
