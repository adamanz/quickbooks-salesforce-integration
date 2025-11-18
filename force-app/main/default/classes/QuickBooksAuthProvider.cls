/**
 * QuickBooks OAuth 2.0 Authentication Provider
 * Handles authentication flow and token management for QuickBooks Online API
 */
public with sharing class QuickBooksAuthProvider {

    // Custom metadata type to store configuration
    private static QuickBooks_Config__mdt config {
        get {
            if (config == null) {
                config = QuickBooks_Config__mdt.getInstance('Default');
            }
            return config;
        }
        set;
    }

    /**
     * Initiates OAuth 2.0 authorization flow
     * @return PageReference to QuickBooks authorization URL
     */
    public static PageReference initiateAuthFlow() {
        String authUrl = 'https://appcenter.intuit.com/connect/oauth2';
        String scope = 'com.intuit.quickbooks.accounting';
        String responseType = 'code';

        Map<String, String> params = new Map<String, String>{
            'client_id' => config.Client_Id__c,
            'scope' => scope,
            'redirect_uri' => config.Redirect_URI__c,
            'response_type' => responseType,
            'state' => generateStateToken()
        };

        String queryString = buildQueryString(params);
        return new PageReference(authUrl + '?' + queryString);
    }

    /**
     * Handles OAuth callback and exchanges authorization code for tokens
     * @param code The authorization code from QuickBooks
     * @param realmId The QuickBooks company ID
     * @return Boolean indicating success
     */
    public static Boolean handleCallback(String code, String realmId) {
        try {
            // Exchange authorization code for access token
            Map<String, Object> tokenResponse = exchangeCodeForToken(code);

            // Store tokens securely
            storeTokens(tokenResponse, realmId);

            return true;
        } catch (Exception e) {
            System.debug('Error handling callback: ' + e.getMessage());
            logError('OAuth Callback', e.getMessage());
            return false;
        }
    }

    /**
     * Exchange authorization code for access and refresh tokens
     */
    private static Map<String, Object> exchangeCodeForToken(String code) {
        String tokenEndpoint = 'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(tokenEndpoint);
        req.setMethod('POST');

        // Basic authentication header
        String authHeader = EncodingUtil.base64Encode(
            Blob.valueOf(config.Client_Id__c + ':' + config.Client_Secret__c)
        );
        req.setHeader('Authorization', 'Basic ' + authHeader);
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setHeader('Accept', 'application/json');

        // Request body
        String body = 'grant_type=authorization_code' +
                     '&code=' + EncodingUtil.urlEncode(code, 'UTF-8') +
                     '&redirect_uri=' + EncodingUtil.urlEncode(config.Redirect_URI__c, 'UTF-8');
        req.setBody(body);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        } else {
            throw new QuickBooksException('Token exchange failed: ' + res.getBody());
        }
    }

    /**
     * Store tokens in custom object for secure storage
     */
    private static void storeTokens(Map<String, Object> tokenData, String realmId) {
        QuickBooks_Auth__c auth = new QuickBooks_Auth__c();

        // Check if record exists
        List<QuickBooks_Auth__c> existing = [
            SELECT Id FROM QuickBooks_Auth__c
            WHERE Company_Id__c = :realmId
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            auth = existing[0];
        }

        auth.Access_Token__c = (String) tokenData.get('access_token');
        auth.Refresh_Token__c = (String) tokenData.get('refresh_token');
        auth.Company_Id__c = realmId;
        auth.Token_Type__c = (String) tokenData.get('token_type');
        auth.Expires_In__c = (Integer) tokenData.get('expires_in');
        auth.Token_Expiry__c = DateTime.now().addSeconds((Integer) tokenData.get('expires_in'));
        auth.Is_Active__c = true;

        upsert auth;
    }

    /**
     * Get valid access token, refreshing if necessary
     * @param companyId QuickBooks company ID
     * @return Valid access token
     */
    public static String getValidAccessToken(String companyId) {
        List<QuickBooks_Auth__c> authList = [
            SELECT Id, Access_Token__c, Refresh_Token__c, Token_Expiry__c
            FROM QuickBooks_Auth__c
            WHERE Company_Id__c = :companyId
            AND Is_Active__c = true
            LIMIT 1
        ];

        if (authList.isEmpty()) {
            throw new QuickBooksException('No authentication found for company: ' + companyId);
        }

        QuickBooks_Auth__c auth = authList[0];

        // Check if token is expired or about to expire (5 minutes buffer)
        if (auth.Token_Expiry__c <= DateTime.now().addMinutes(5)) {
            refreshAccessToken(auth);
        }

        return auth.Access_Token__c;
    }

    /**
     * Get the active QuickBooks company ID
     * @return Active company ID
     */
    public static String getCompanyId() {
        List<QuickBooks_Auth__c> authList = [
            SELECT Company_Id__c
            FROM QuickBooks_Auth__c
            WHERE Is_Active__c = true
            LIMIT 1
        ];

        if (authList.isEmpty()) {
            throw new QuickBooksException('No active QuickBooks authentication found');
        }

        return authList[0].Company_Id__c;
    }

    /**
     * Get valid access token using the default active company
     * @return Valid access token for the active company
     */
    public static String getValidAccessToken() {
        String companyId = getCompanyId();
        return getValidAccessToken(companyId);
    }

    /**
     * Refresh access token using refresh token
     */
    private static void refreshAccessToken(QuickBooks_Auth__c auth) {
        String tokenEndpoint = 'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(tokenEndpoint);
        req.setMethod('POST');

        // Basic authentication
        String authHeader = EncodingUtil.base64Encode(
            Blob.valueOf(config.Client_Id__c + ':' + config.Client_Secret__c)
        );
        req.setHeader('Authorization', 'Basic ' + authHeader);
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setHeader('Accept', 'application/json');

        String body = 'grant_type=refresh_token' +
                     '&refresh_token=' + EncodingUtil.urlEncode(auth.Refresh_Token__c, 'UTF-8');
        req.setBody(body);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> tokenData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            auth.Access_Token__c = (String) tokenData.get('access_token');
            auth.Refresh_Token__c = (String) tokenData.get('refresh_token');
            auth.Token_Expiry__c = DateTime.now().addSeconds((Integer) tokenData.get('expires_in'));

            update auth;
        } else {
            throw new QuickBooksException('Token refresh failed: ' + res.getBody());
        }
    }

    /**
     * Generate state token for CSRF protection
     */
    private static String generateStateToken() {
        return EncodingUtil.convertToHex(Crypto.generateAESKey(128));
    }

    /**
     * Build query string from parameters
     */
    private static String buildQueryString(Map<String, String> params) {
        List<String> paramList = new List<String>();
        for (String key : params.keySet()) {
            paramList.add(key + '=' + EncodingUtil.urlEncode(params.get(key), 'UTF-8'));
        }
        return String.join(paramList, '&');
    }

    /**
     * Log error to custom object
     */
    private static void logError(String context, String message) {
        Integration_Log__c log = new Integration_Log__c(
            Integration_Type__c = 'QuickBooks',
            Context__c = context,
            Error_Message__c = message,
            Timestamp__c = DateTime.now()
        );
        insert log;
    }

    /**
     * Custom exception class
     */
    public class QuickBooksException extends Exception {}
}