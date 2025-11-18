public with sharing class QuickBooksOAuthController {
    public Boolean isProcessing { get; private set; }
    public Boolean isSuccess { get; private set; }
    public Boolean isError { get; private set; }
    public String errorMessage { get; private set; }

    private static final String TOKEN_ENDPOINT = 'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer';

    public QuickBooksOAuthController() {
        isProcessing = true;
        isSuccess = false;
        isError = false;

        // Process OAuth callback
        processOAuthCallback();
    }

    private void processOAuthCallback() {
        try {
            // Get parameters from URL
            String code = ApexPages.currentPage().getParameters().get('code');
            String state = ApexPages.currentPage().getParameters().get('state');
            String realmId = ApexPages.currentPage().getParameters().get('realmId'); // Company ID
            String error = ApexPages.currentPage().getParameters().get('error');

            // Check for errors from QuickBooks
            if (String.isNotBlank(error)) {
                throw new OAuthException('Authorization denied: ' + error);
            }

            // Validate required parameters
            if (String.isBlank(code)) {
                throw new OAuthException('Missing authorization code');
            }

            if (String.isBlank(realmId)) {
                throw new OAuthException('Missing QuickBooks Company ID');
            }

            // Exchange authorization code for tokens
            exchangeCodeForTokens(code, realmId);

            isProcessing = false;
            isSuccess = true;

        } catch (Exception e) {
            isProcessing = false;
            isError = true;
            errorMessage = e.getMessage();

            // Log the error
            logError('OAuth Callback Error', e.getMessage());
        }
    }

    private void exchangeCodeForTokens(String code, String realmId) {
        // Get QuickBooks configuration
        QuickBooks_Config__mdt config = getQuickBooksConfig();

        if (config == null) {
            throw new OAuthException('QuickBooks configuration not found. Please configure QuickBooks settings.');
        }

        // Prepare token exchange request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(TOKEN_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        // Basic authentication with client ID and secret
        String credentials = config.Client_Id__c + ':' + config.Client_Secret__c;
        Blob credentialsBlob = Blob.valueOf(credentials);
        String encodedCredentials = EncodingUtil.base64Encode(credentialsBlob);
        req.setHeader('Authorization', 'Basic ' + encodedCredentials);

        // Build request body
        String redirectUri = config.Redirect_URI__c;
        if (String.isBlank(redirectUri)) {
            // Build redirect URI dynamically
            redirectUri = URL.getOrgDomainUrl().toExternalForm() + '/apex/qboOAuthRedirect';
        }

        String body = 'grant_type=authorization_code' +
                     '&code=' + EncodingUtil.urlEncode(code, 'UTF-8') +
                     '&redirect_uri=' + EncodingUtil.urlEncode(redirectUri, 'UTF-8');

        req.setBody(body);

        // Send request
        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new OAuthException('Token exchange failed: ' + res.getBody());
        }

        // Parse response
        Map<String, Object> tokenResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        // Save tokens
        saveTokens(tokenResponse, realmId);
    }

    private void saveTokens(Map<String, Object> tokenResponse, String realmId) {
        // Check if we already have an auth record for this company
        List<QuickBooks_Auth__c> existingAuths = [
            SELECT Id FROM QuickBooks_Auth__c
            WHERE Company_Id__c = :realmId
            LIMIT 1
        ];

        QuickBooks_Auth__c auth;
        if (!existingAuths.isEmpty()) {
            auth = existingAuths[0];
        } else {
            auth = new QuickBooks_Auth__c();
            auth.Company_Id__c = realmId;
        }

        // Update token fields
        auth.Access_Token__c = (String) tokenResponse.get('access_token');
        auth.Refresh_Token__c = (String) tokenResponse.get('refresh_token');
        auth.Token_Type__c = (String) tokenResponse.get('token_type');

        // Calculate token expiry
        Integer expiresIn = (Integer) tokenResponse.get('expires_in');
        if (expiresIn != null) {
            auth.Expires_In__c = expiresIn;
            auth.Token_Expiry__c = DateTime.now().addSeconds(expiresIn);
        }

        auth.Is_Active__c = true;

        // Save the record
        upsert auth;

        // Log success
        logSuccess('OAuth tokens saved successfully for Company ID: ' + realmId);
    }

    private QuickBooks_Config__mdt getQuickBooksConfig() {
        List<QuickBooks_Config__mdt> configs = [
            SELECT Client_Id__c, Client_Secret__c, Redirect_URI__c, Is_Sandbox__c
            FROM QuickBooks_Config__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];

        return configs.isEmpty() ? null : configs[0];
    }

    private void logError(String context, String errorMessage) {
        Integration_Log__c log = new Integration_Log__c();
        log.Integration_Type__c = 'QuickBooks OAuth';
        log.Context__c = context;
        log.Error_Message__c = errorMessage;
        log.Timestamp__c = DateTime.now();

        insert log;
    }

    private void logSuccess(String message) {
        Integration_Log__c log = new Integration_Log__c();
        log.Integration_Type__c = 'QuickBooks OAuth';
        log.Context__c = 'OAuth Success';
        log.Error_Message__c = message;
        log.Timestamp__c = DateTime.now();

        insert log;
    }

    public class OAuthException extends Exception {}
}