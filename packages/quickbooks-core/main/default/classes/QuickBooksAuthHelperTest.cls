@isTest
private class QuickBooksAuthHelperTest {

    @isTest
    static void testProcessCallbackCoverage() {
        // Setup mock
        Test.setMock(HttpCalloutMock.class, new MockTokenResponse());

        // Execute
        Test.startTest();
        Boolean success = QuickBooksAuthHelper.processCallback('test_code', '1234567890');
        Test.stopTest();

        // Verify - this test mainly provides code coverage
        System.assert(success, 'Callback should succeed with mock');
    }

    @isTest
    static void testProcessCallbackAsync() {
        // Setup mock
        Test.setMock(HttpCalloutMock.class, new MockTokenResponse());

        // Execute
        Test.startTest();
        QuickBooksAuthHelper.processCallbackAsync('test_code', '1234567890');
        Test.stopTest();

        // Verify - async method doesn't return value, but we can check logs if we wanted
        // For now, we just ensure it runs without exception
    }

    // Simple mock class for testing
    private class MockTokenResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"access_token":"test_token","refresh_token":"test_refresh","token_type":"bearer","expires_in":3600}');
            res.setStatusCode(200);
            return res;
        }
    }
}
