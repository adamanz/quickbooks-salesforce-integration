/**
 * Test class for QuickBooksAuthProvider
 * Tests OAuth 2.0 authentication flow and token management
 */
@isTest
private class QuickBooksAuthProviderTest {

    @TestSetup
    static void setupTestData() {
        // Create QuickBooks Auth record with expired token
        QuickBooks_Auth__c auth = new QuickBooks_Auth__c(
            Company_Id__c = 'TEST_COMPANY_123',
            Access_Token__c = 'test_access_token_old',
            Refresh_Token__c = 'test_refresh_token_123',
            Token_Type__c = 'bearer',
            Token_Expiry__c = DateTime.now().addMinutes(-10), // Expired 10 minutes ago
            Expires_In__c = 3600,
            Is_Active__c = true
        );
        insert auth;

        // Create Integration Log object (if needed for testing)
        // This assumes Integration_Log__c is available
    }

    /**
     * Test successful OAuth callback handling
     */
    @isTest
    static void testHandleCallback_Success() {
        // Setup HTTP mock for token exchange
        Test.setMock(HttpCalloutMock.class, new AuthProviderHttpMock('token_exchange_success'));

        Test.startTest();
        Boolean result = QuickBooksAuthProvider.handleCallback('test_auth_code_123', 'TEST_COMPANY_456');
        Test.stopTest();

        // Verify success
        System.assertEquals(true, result, 'Callback should be handled successfully');

        // Verify tokens were stored
        List<QuickBooks_Auth__c> authRecords = [
            SELECT Access_Token__c, Refresh_Token__c, Company_Id__c, Is_Active__c, Token_Expiry__c
            FROM QuickBooks_Auth__c
            WHERE Company_Id__c = 'TEST_COMPANY_456'
        ];
        System.assertEquals(1, authRecords.size(), 'Should create one auth record');
        System.assertEquals('new_access_token', authRecords[0].Access_Token__c);
        System.assertEquals('new_refresh_token', authRecords[0].Refresh_Token__c);
        System.assertEquals(true, authRecords[0].Is_Active__c);
        System.assertNotEquals(null, authRecords[0].Token_Expiry__c);
    }

    /**
     * Test OAuth callback with error
     */
    @isTest
    static void testHandleCallback_Error() {
        // Setup HTTP mock for error response
        Test.setMock(HttpCalloutMock.class, new AuthProviderHttpMock('token_exchange_error'));

        Test.startTest();
        Boolean result = QuickBooksAuthProvider.handleCallback('invalid_code', 'TEST_COMPANY_123');
        Test.stopTest();

        // Verify failure
        System.assertEquals(false, result, 'Callback should fail with invalid code');

        // Verify error was logged
        List<Integration_Log__c> logs = [
            SELECT Context__c, Error_Message__c
            FROM Integration_Log__c
            WHERE Integration_Type__c = 'QuickBooks' AND Context__c = 'OAuth Callback'
        ];
        System.assertEquals(1, logs.size(), 'Should log error');
    }

    /**
     * Test updating existing auth record
     */
    @isTest
    static void testHandleCallback_UpdateExisting() {
        // Setup HTTP mock
        Test.setMock(HttpCalloutMock.class, new AuthProviderHttpMock('token_exchange_success'));

        Test.startTest();
        Boolean result = QuickBooksAuthProvider.handleCallback('test_code', 'TEST_COMPANY_123');
        Test.stopTest();

        // Verify existing record was updated
        List<QuickBooks_Auth__c> authRecords = [
            SELECT Id, Access_Token__c, Refresh_Token__c
            FROM QuickBooks_Auth__c
            WHERE Company_Id__c = 'TEST_COMPANY_123'
        ];
        System.assertEquals(1, authRecords.size(), 'Should only have one record for company');
        System.assertEquals('new_access_token', authRecords[0].Access_Token__c);
    }

    /**
     * Test getting valid access token (no refresh needed)
     */
    @isTest
    static void testGetValidAccessToken_NoRefresh() {
        // Create auth with valid token
        QuickBooks_Auth__c auth = new QuickBooks_Auth__c(
            Company_Id__c = 'TEST_COMPANY_VALID',
            Access_Token__c = 'valid_access_token',
            Refresh_Token__c = 'refresh_token',
            Token_Expiry__c = DateTime.now().addHours(1), // Valid for 1 hour
            Is_Active__c = true
        );
        insert auth;

        Test.startTest();
        String accessToken = QuickBooksAuthProvider.getValidAccessToken('TEST_COMPANY_VALID');
        Test.stopTest();

        // Verify token returned without refresh
        System.assertEquals('valid_access_token', accessToken);
    }

    /**
     * Test getting valid access token (refresh needed)
     */
    @isTest
    static void testGetValidAccessToken_RefreshNeeded() {
        // Setup HTTP mock for token refresh
        Test.setMock(HttpCalloutMock.class, new AuthProviderHttpMock('token_refresh_success'));

        Test.startTest();
        String accessToken = QuickBooksAuthProvider.getValidAccessToken('TEST_COMPANY_123');
        Test.stopTest();

        // Verify new token was returned
        System.assertEquals('refreshed_access_token', accessToken);

        // Verify auth record was updated
        QuickBooks_Auth__c updatedAuth = [
            SELECT Access_Token__c, Refresh_Token__c, Token_Expiry__c
            FROM QuickBooks_Auth__c
            WHERE Company_Id__c = 'TEST_COMPANY_123'
        ];
        System.assertEquals('refreshed_access_token', updatedAuth.Access_Token__c);
        System.assertEquals('refreshed_refresh_token', updatedAuth.Refresh_Token__c);
        System.assert(updatedAuth.Token_Expiry__c > DateTime.now());
    }

    /**
     * Test getting access token when auth not found
     */
    @isTest
    static void testGetValidAccessToken_NotFound() {
        Test.startTest();
        try {
            QuickBooksAuthProvider.getValidAccessToken('NONEXISTENT_COMPANY');
            System.assert(false, 'Should throw exception');
        } catch (QuickBooksAuthProvider.QuickBooksException e) {
            System.assert(e.getMessage().contains('No authentication found'));
        }
        Test.stopTest();
    }

    /**
     * Test token refresh failure
     */
    @isTest
    static void testGetValidAccessToken_RefreshFails() {
        // Setup HTTP mock for refresh error
        Test.setMock(HttpCalloutMock.class, new AuthProviderHttpMock('token_refresh_error'));

        Test.startTest();
        try {
            QuickBooksAuthProvider.getValidAccessToken('TEST_COMPANY_123');
            System.assert(false, 'Should throw exception');
        } catch (QuickBooksAuthProvider.QuickBooksException e) {
            System.assert(e.getMessage().contains('Token refresh failed'));
        }
        Test.stopTest();
    }

    @isTest
    static void testGetCompanyId() {
        String companyId = QuickBooksAuthProvider.getCompanyId();
        System.assertEquals('TEST_COMPANY_123', companyId);
    }

    @isTest
    static void testGetValidAccessTokenNoArgs() {
        // Setup HTTP mock in case refresh is needed
        Test.setMock(HttpCalloutMock.class, new AuthProviderHttpMock('token_refresh_success'));

        // Create auth with valid token
        QuickBooks_Auth__c auth = new QuickBooks_Auth__c(
            Company_Id__c = 'TEST_COMPANY_VALID_2',
            Access_Token__c = 'valid_access_token_2',
            Refresh_Token__c = 'refresh_token_2',
            Token_Expiry__c = DateTime.now().addHours(1), // Valid for 1 hour
            Is_Active__c = true
        );
        insert auth;

        Test.startTest();
        String accessToken = QuickBooksAuthProvider.getValidAccessToken();
        Test.stopTest();

        System.assertNotEquals(null, accessToken);
    }

    /**
     * Test initiate auth flow
     */
    @isTest
    static void testInitiateAuthFlow() {
        Test.startTest();
        PageReference authPage = QuickBooksAuthProvider.initiateAuthFlow();
        Test.stopTest();

        // Verify PageReference is created
        System.assertNotEquals(null, authPage);
        String url = authPage.getUrl();

        // Verify URL contains required parameters
        System.assert(url.contains('appcenter.intuit.com'));
        System.assert(url.contains('client_id='));
        System.assert(url.contains('redirect_uri='));
        System.assert(url.contains('scope='));
        System.assert(url.contains('response_type=code'));
        System.assert(url.contains('state='));
    }

    /**
     * Test configuration validation
     */
    @isTest
    static void testValidateConfiguration() {
        Test.startTest();
        Map<String, Object> validationResult = QuickBooksAuthProvider.validateConfiguration();
        Test.stopTest();

        System.assertNotEquals(null, validationResult, 'Validation result should not be null');
        System.assert(validationResult.containsKey('isValid'), 'Result should contain isValid key');
        System.assert(validationResult.containsKey('errors'), 'Result should contain errors key');
        System.assert(validationResult.containsKey('warnings'), 'Result should contain warnings key');
    }

    /**
     * Test initiateAuthFlow with warnings
     */
    @isTest
    static void testInitiateAuthFlowWithWarnings() {
        Test.startTest();
        PageReference authPage = QuickBooksAuthProvider.initiateAuthFlow();
        Test.stopTest();

        System.assertNotEquals(null, authPage);
        String url = authPage.getUrl();
        System.assert(url.contains('client_id='));
        System.assert(url.contains('state='));
    }

    /**
     * Test getCompanyId when no auth exists
     */
    @isTest
    static void testGetCompanyIdNoAuth() {
        // Delete all auth records
        delete [SELECT Id FROM QuickBooks_Auth__c];

        Test.startTest();
        try {
            QuickBooksAuthProvider.getCompanyId();
            System.assert(false, 'Should throw exception');
        } catch (QuickBooksAuthProvider.QuickBooksException e) {
            System.assert(e.getMessage().contains('No active QuickBooks authentication'));
        }
        Test.stopTest();
    }

    /**
     * Test exception handling
     */
    @isTest
    static void testQuickBooksException() {
        try {
            throw new QuickBooksAuthProvider.QuickBooksException('Test exception message');
        } catch (QuickBooksAuthProvider.QuickBooksException e) {
            System.assertEquals('Test exception message', e.getMessage());
        }
    }

    /**
     * HTTP Mock class for QuickBooks OAuth
     */
    private class AuthProviderHttpMock implements HttpCalloutMock {
        private String responseType;

        public AuthProviderHttpMock(String responseType) {
            this.responseType = responseType;
        }

        public HTTPResponse respond(HTTPRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');

            switch on responseType {
                when 'token_exchange_success' {
                    response.setStatusCode(200);
                    response.setBody(JSON.serialize(new Map<String, Object>{
                        'access_token' => 'new_access_token',
                        'refresh_token' => 'new_refresh_token',
                        'token_type' => 'bearer',
                        'expires_in' => 3600
                    }));
                }
                when 'token_exchange_error' {
                    response.setStatusCode(400);
                    response.setBody('{"error": "invalid_grant", "error_description": "Invalid authorization code"}');
                }
                when 'token_refresh_success' {
                    response.setStatusCode(200);
                    response.setBody(JSON.serialize(new Map<String, Object>{
                        'access_token' => 'refreshed_access_token',
                        'refresh_token' => 'refreshed_refresh_token',
                        'token_type' => 'bearer',
                        'expires_in' => 3600
                    }));
                }
                when 'token_refresh_error' {
                    response.setStatusCode(400);
                    response.setBody('{"error": "invalid_grant"}');
                }
            }

            return response;
        }
    }
}
