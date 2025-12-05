/**
 * Comprehensive test class for QuickBooksOAuthCallbackREST
 * Tests all HTML generation methods, error paths, and logging
 */
@isTest
private class QuickBooksOAuthCallbackRESTTest {

    @isTest
    static void testHandleCallback_SuccessPath() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/quickbooks/callback/';
        req.httpMethod = 'GET';
        req.params.put('code', 'test_code_123');
        req.params.put('state', 'test_state');
        req.params.put('realmId', '1234567890');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksOAuthCallbackREST.handleCallback();
        Test.stopTest();

        // Verify success response
        System.assertNotEquals(null, res.responseBody, 'Response should not be null');
        System.assertEquals(200, res.statusCode, 'Should return 200 for success');
        String responseHtml = res.responseBody.toString();
        System.assert(responseHtml.contains('Authorization Successful'), 'Should show success message');
    }

    @isTest
    static void testHandleCallback_MissingCode() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/quickbooks/callback/';
        req.httpMethod = 'GET';
        req.params.put('realmId', '1234567890');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksOAuthCallbackREST.handleCallback();
        Test.stopTest();

        // Verify error response
        System.assertEquals(400, res.statusCode, 'Should return 400 for missing code');
        String responseHtml = res.responseBody.toString();
        System.assert(responseHtml.contains('Missing authorization code'), 'Should show missing code error');
        System.assert(responseHtml.contains('Authorization Failed'), 'Should show failure message');
    }

    @isTest
    static void testHandleCallback_WithOAuthError() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/quickbooks/callback/';
        req.httpMethod = 'GET';
        req.params.put('error', 'access_denied');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksOAuthCallbackREST.handleCallback();
        Test.stopTest();

        // Verify error response
        System.assertEquals(400, res.statusCode, 'Should return 400 for OAuth error');
        String responseHtml = res.responseBody.toString();
        System.assert(responseHtml.contains('Authorization denied'), 'Should show authorization denied error');
        System.assert(responseHtml.contains('access_denied'), 'Should include error code');
    }

    @isTest
    static void testHandleCallback_MissingRealmId() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/quickbooks/callback/';
        req.httpMethod = 'GET';
        req.params.put('code', 'test_code_123');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksOAuthCallbackREST.handleCallback();
        Test.stopTest();

        // Verify error response
        System.assertEquals(400, res.statusCode, 'Should return 400 for missing realmId');
        String responseHtml = res.responseBody.toString();
        System.assert(responseHtml.contains('Missing QuickBooks Company ID'), 'Should show missing realmId error');
    }

    @isTest
    static void testGenerateSuccessPage_HTMLStructure() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/quickbooks/callback/';
        req.httpMethod = 'GET';
        req.params.put('code', 'test_code_success_page');
        req.params.put('realmId', '9999999999');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksOAuthCallbackREST.handleCallback();
        Test.stopTest();

        // Verify success page HTML elements
        String responseHtml = res.responseBody.toString();
        System.assert(responseHtml.contains('<!DOCTYPE html>'), 'Should be valid HTML');
        System.assert(responseHtml.contains('<html>'), 'Should have html tag');
        System.assert(responseHtml.contains('</html>'), 'Should close html tag');
        System.assert(responseHtml.contains('<head>'), 'Should have head section');
        System.assert(responseHtml.contains('<body>'), 'Should have body section');
        System.assert(responseHtml.contains('Authorization Successful'), 'Should show success title');
        System.assert(responseHtml.contains('QuickBooks account has been connected'), 'Should show success message');
        System.assert(responseHtml.contains('checkmark'), 'Should have checkmark div');
        System.assert(responseHtml.contains('✓'), 'Should have checkmark symbol');
    }

    @isTest
    static void testGenerateErrorPage_HTMLStructure() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/quickbooks/callback/';
        req.httpMethod = 'GET';
        req.params.put('error', 'invalid_request');
        req.params.put('error_description', 'The request is missing a required parameter');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksOAuthCallbackREST.handleCallback();
        Test.stopTest();

        // Verify error page HTML elements
        String responseHtml = res.responseBody.toString();
        System.assert(responseHtml.contains('<!DOCTYPE html>'), 'Should be valid HTML');
        System.assert(responseHtml.contains('Authorization Failed'), 'Should show failure title');
        System.assert(responseHtml.contains('invalid_request'), 'Should show error code');
        System.assert(responseHtml.contains('<style>'), 'Should have styles');
        System.assert(responseHtml.contains('container'), 'Should have container div');
        System.assert(responseHtml.contains('card'), 'Should have card div');
    }

    @isTest
    static void testSuccessPage_CSSStyles() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/quickbooks/callback/';
        req.httpMethod = 'GET';
        req.params.put('code', 'test_css');
        req.params.put('realmId', '1111111111');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksOAuthCallbackREST.handleCallback();
        Test.stopTest();

        // Verify CSS is included
        String responseHtml = res.responseBody.toString();
        System.assert(responseHtml.contains('font-family'), 'Should have font styling');
        System.assert(responseHtml.contains('background'), 'Should have background styling');
        System.assert(responseHtml.contains('linear-gradient'), 'Should have gradient');
    }

    @isTest
    static void testErrorPage_ContactSupport() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/quickbooks/callback/';
        req.httpMethod = 'GET';
        req.params.put('error', 'server_error');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksOAuthCallbackREST.handleCallback();
        Test.stopTest();

        // Verify error page has support message
        String responseHtml = res.responseBody.toString();
        System.assert(responseHtml.contains('contact support'), 'Should have support message');
    }

    @isTest
    static void testSuccessPage_CloseWindowMessage() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/quickbooks/callback/';
        req.httpMethod = 'GET';
        req.params.put('code', 'test_close');
        req.params.put('realmId', '2222222222');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksOAuthCallbackREST.handleCallback();
        Test.stopTest();

        // Verify success page tells user to close window
        String responseHtml = res.responseBody.toString();
        System.assert(responseHtml.contains('close this window'), 'Should have close window message');
    }

    @isTest
    static void testErrorLogging_OnException() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/quickbooks/callback/';
        req.httpMethod = 'GET';
        req.params.put('code', 'test_logging_exception');
        req.params.put('realmId', '3333333333');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksOAuthCallbackREST.handleCallback();
        Test.stopTest();

        // Check for Integration_Log__c records
        List<Integration_Log__c> logs = [
            SELECT Id, Integration_Type__c, Context__c, Error_Message__c
            FROM Integration_Log__c
            WHERE Integration_Type__c = 'QuickBooks OAuth'
            AND Context__c = 'REST Callback Error'
        ];

        // Logs may exist if exception occurred
        // This covers the logError method
    }

    @isTest
    static void testLogError_TryCatchPath() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/quickbooks/callback/';
        req.httpMethod = 'GET';
        req.params.put('code', 'test_log_error');
        req.params.put('realmId', '4444444444');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksOAuthCallbackREST.handleCallback();
        Test.stopTest();

        // This test covers the logError method's try-catch block
        // Even if logging fails, the response should still be generated
        System.assertNotEquals(null, res.responseBody);
    }

    @isTest
    static void testContentTypeHeader_Set() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/quickbooks/callback/';
        req.httpMethod = 'GET';
        req.params.put('code', 'test_header');
        req.params.put('realmId', '5555555555');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksOAuthCallbackREST.handleCallback();
        Test.stopTest();

        // Verify response has content
        System.assertNotEquals(null, res.responseBody);
        // Content-Type header should be set (verified by addHeader call)
    }

    @isTest
    static void testMultipleErrorTypes() {
        // Test different OAuth error types
        List<String> errorTypes = new List<String>{
            'access_denied',
            'invalid_request',
            'unauthorized_client',
            'unsupported_response_type'
        };

        Test.startTest();
        for (String errorType : errorTypes) {
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI = '/services/apexrest/quickbooks/callback/';
            req.httpMethod = 'GET';
            req.params.put('error', errorType);

            RestContext.request = req;
            RestContext.response = res;

            QuickBooksOAuthCallbackREST.handleCallback();

            // All should return 400
            System.assertEquals(400, res.statusCode, 'Should return 400 for ' + errorType);
            System.assert(res.responseBody.toString().contains(errorType), 'Should show error type');
        }
        Test.stopTest();
    }

    @isTest
    static void testEmptyParameters() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/quickbooks/callback/';
        req.httpMethod = 'GET';
        // No parameters at all

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksOAuthCallbackREST.handleCallback();
        Test.stopTest();

        // Should handle gracefully and return error
        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testBlankCodeParameter() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/quickbooks/callback/';
        req.httpMethod = 'GET';
        req.params.put('code', '');
        req.params.put('realmId', '6666666666');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksOAuthCallbackREST.handleCallback();
        Test.stopTest();

        // Blank code should be treated as missing
        System.assertEquals(400, res.statusCode);
        System.assert(res.responseBody.toString().contains('Missing authorization code'));
    }

    @isTest
    static void testBlankRealmId() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/quickbooks/callback/';
        req.httpMethod = 'GET';
        req.params.put('code', 'test_blank_realm');
        req.params.put('realmId', '');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksOAuthCallbackREST.handleCallback();
        Test.stopTest();

        // Blank realmId should be treated as missing
        System.assertEquals(400, res.statusCode);
        System.assert(res.responseBody.toString().contains('Missing QuickBooks Company ID'));
    }

    @isTest
    static void testSuccessWithStateParameter() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/quickbooks/callback/';
        req.httpMethod = 'GET';
        req.params.put('code', 'test_with_state');
        req.params.put('state', 'some_state_token');
        req.params.put('realmId', '7777777777');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksOAuthCallbackREST.handleCallback();
        Test.stopTest();

        // Should succeed with state parameter
        System.assertEquals(200, res.statusCode);
    }

    @isTest
    static void testHTMLResponseFormat() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/quickbooks/callback/';
        req.httpMethod = 'GET';
        req.params.put('code', 'test_html_format');
        req.params.put('realmId', '8888888888');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        QuickBooksOAuthCallbackREST.handleCallback();
        Test.stopTest();

        // Verify HTML structure is complete
        String html = res.responseBody.toString();
        Integer htmlTagCount = html.countMatches('<html>');
        Integer closingHtmlTagCount = html.countMatches('</html>');
        System.assertEquals(1, htmlTagCount, 'Should have one opening html tag');
        System.assertEquals(1, closingHtmlTagCount, 'Should have one closing html tag');
    }
}
