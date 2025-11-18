/**
 * Test class for QuickBooksOAuthController
 * Tests Visualforce page OAuth callback controller
 */
@isTest
private class QuickBooksOAuthControllerTest {

    /**
     * Test successful OAuth callback
     */
    @isTest
    static void testProcessOAuthCallback_Success() {
        // Setup HTTP mock
        Test.setMock(HttpCalloutMock.class, new OAuthControllerHttpMock('success'));

        // Setup page parameters
        PageReference pageRef = Page.qboOAuthRedirect; // Assumes VF page exists
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('code', 'test_auth_code_123');
        ApexPages.currentPage().getParameters().put('realmId', 'TEST_REALM_123');

        Test.startTest();
        QuickBooksOAuthController controller = new QuickBooksOAuthController();
        Test.stopTest();

        // Verify controller state
        System.assertEquals(false, controller.isProcessing);
        System.assertEquals(true, controller.isSuccess);
        System.assertEquals(false, controller.isError);
        System.assertEquals(null, controller.errorMessage);

        // Verify tokens were saved
        List<QuickBooks_Auth__c> authRecords = [
            SELECT Access_Token__c, Refresh_Token__c, Company_Id__c
            FROM QuickBooks_Auth__c
            WHERE Company_Id__c = 'TEST_REALM_123'
        ];
        System.assertEquals(1, authRecords.size());
        System.assertEquals('new_access_token', authRecords[0].Access_Token__c);
        System.assertEquals('new_refresh_token', authRecords[0].Refresh_Token__c);

        // Verify success was logged
        List<Integration_Log__c> logs = [
            SELECT Error_Message__c
            FROM Integration_Log__c
            WHERE Integration_Type__c = 'QuickBooks OAuth'
            AND Context__c = 'OAuth Success'
        ];
        System.assertEquals(1, logs.size());
        System.assert(logs[0].Error_Message__c.contains('successfully'));
    }

    /**
     * Test OAuth callback with missing code
     */
    @isTest
    static void testProcessOAuthCallback_MissingCode() {
        // Setup page parameters without code
        PageReference pageRef = Page.qboOAuthRedirect;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('realmId', 'TEST_REALM_123');

        Test.startTest();
        QuickBooksOAuthController controller = new QuickBooksOAuthController();
        Test.stopTest();

        // Verify error state
        System.assertEquals(false, controller.isProcessing);
        System.assertEquals(false, controller.isSuccess);
        System.assertEquals(true, controller.isError);
        System.assert(controller.errorMessage.contains('Missing authorization code'));
    }

    /**
     * Test OAuth callback with missing realmId
     */
    @isTest
    static void testProcessOAuthCallback_MissingRealmId() {
        // Setup page parameters without realmId
        PageReference pageRef = Page.qboOAuthRedirect;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('code', 'test_auth_code_123');

        Test.startTest();
        QuickBooksOAuthController controller = new QuickBooksOAuthController();
        Test.stopTest();

        // Verify error state
        System.assertEquals(false, controller.isProcessing);
        System.assertEquals(false, controller.isSuccess);
        System.assertEquals(true, controller.isError);
        System.assert(controller.errorMessage.contains('Missing QuickBooks Company ID'));
    }

    /**
     * Test OAuth callback with error parameter
     */
    @isTest
    static void testProcessOAuthCallback_AuthorizationDenied() {
        // Setup page parameters with error
        PageReference pageRef = Page.qboOAuthRedirect;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('error', 'access_denied');

        Test.startTest();
        QuickBooksOAuthController controller = new QuickBooksOAuthController();
        Test.stopTest();

        // Verify error state
        System.assertEquals(false, controller.isProcessing);
        System.assertEquals(false, controller.isSuccess);
        System.assertEquals(true, controller.isError);
        System.assert(controller.errorMessage.contains('Authorization denied'));

        // Verify error was logged
        List<Integration_Log__c> logs = [
            SELECT Error_Message__c
            FROM Integration_Log__c
            WHERE Integration_Type__c = 'QuickBooks OAuth'
            AND Context__c = 'OAuth Callback Error'
        ];
        System.assertEquals(1, logs.size());
    }

    /**
     * Test token exchange failure
     */
    @isTest
    static void testProcessOAuthCallback_TokenExchangeError() {
        // Setup HTTP mock for error
        Test.setMock(HttpCalloutMock.class, new OAuthControllerHttpMock('error'));

        // Setup page parameters
        PageReference pageRef = Page.qboOAuthRedirect;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('code', 'test_auth_code_123');
        ApexPages.currentPage().getParameters().put('realmId', 'TEST_REALM_123');

        Test.startTest();
        QuickBooksOAuthController controller = new QuickBooksOAuthController();
        Test.stopTest();

        // Verify error state
        System.assertEquals(false, controller.isProcessing);
        System.assertEquals(false, controller.isSuccess);
        System.assertEquals(true, controller.isError);
        System.assert(controller.errorMessage.contains('Token exchange failed'));
    }

    /**
     * Test updating existing auth record
     */
    @isTest
    static void testProcessOAuthCallback_UpdateExisting() {
        // Create existing auth record
        QuickBooks_Auth__c existingAuth = new QuickBooks_Auth__c(
            Company_Id__c = 'TEST_REALM_123',
            Access_Token__c = 'old_token',
            Refresh_Token__c = 'old_refresh',
            Token_Type__c = 'bearer',
            Is_Active__c = false
        );
        insert existingAuth;

        // Setup HTTP mock
        Test.setMock(HttpCalloutMock.class, new OAuthControllerHttpMock('success'));

        // Setup page parameters
        PageReference pageRef = Page.qboOAuthRedirect;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('code', 'test_auth_code_123');
        ApexPages.currentPage().getParameters().put('realmId', 'TEST_REALM_123');

        Test.startTest();
        QuickBooksOAuthController controller = new QuickBooksOAuthController();
        Test.stopTest();

        // Verify only one record exists (updated, not created)
        List<QuickBooks_Auth__c> authRecords = [
            SELECT Id, Access_Token__c, Is_Active__c
            FROM QuickBooks_Auth__c
            WHERE Company_Id__c = 'TEST_REALM_123'
        ];
        System.assertEquals(1, authRecords.size());
        System.assertEquals(existingAuth.Id, authRecords[0].Id);
        System.assertEquals('new_access_token', authRecords[0].Access_Token__c);
        System.assertEquals(true, authRecords[0].Is_Active__c);
    }

    /**
     * Test with all URL parameters
     */
    @isTest
    static void testProcessOAuthCallback_AllParameters() {
        // Setup HTTP mock
        Test.setMock(HttpCalloutMock.class, new OAuthControllerHttpMock('success'));

        // Setup page parameters with state
        PageReference pageRef = Page.qboOAuthRedirect;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('code', 'test_auth_code_123');
        ApexPages.currentPage().getParameters().put('realmId', 'TEST_REALM_123');
        ApexPages.currentPage().getParameters().put('state', 'test_state_token');

        Test.startTest();
        QuickBooksOAuthController controller = new QuickBooksOAuthController();
        Test.stopTest();

        // Verify success
        System.assertEquals(true, controller.isSuccess);
    }

    /**
     * HTTP Mock class for OAuth Controller
     */
    private class OAuthControllerHttpMock implements HttpCalloutMock {
        private String responseType;

        public OAuthControllerHttpMock(String responseType) {
            this.responseType = responseType;
        }

        public HTTPResponse respond(HTTPRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');

            if (responseType == 'success') {
                response.setStatusCode(200);
                response.setBody(JSON.serialize(new Map<String, Object>{
                    'access_token' => 'new_access_token',
                    'refresh_token' => 'new_refresh_token',
                    'token_type' => 'bearer',
                    'expires_in' => 3600
                }));
            } else if (responseType == 'error') {
                response.setStatusCode(400);
                response.setBody('{"error": "invalid_grant", "error_description": "Invalid authorization code"}');
            }

            return response;
        }
    }
}
