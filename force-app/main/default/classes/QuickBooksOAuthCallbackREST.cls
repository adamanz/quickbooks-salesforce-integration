/**
 * REST endpoint for QuickBooks OAuth callback
 * @RestResource allows unauthenticated access for OAuth flow
 */
@RestResource(urlMapping='/quickbooks/callback/*')
global without sharing class QuickBooksOAuthCallbackREST {

    @HttpGet
    global static void handleCallback() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        // Get OAuth parameters from URL
        String code = req.params.get('code');
        String state = req.params.get('state');
        String realmId = req.params.get('realmId');
        String error = req.params.get('error');

        String htmlResponse = '';

        try {
            // Check for errors from QuickBooks
            if (String.isNotBlank(error)) {
                htmlResponse = generateErrorPage('Authorization denied: ' + error);
                res.responseBody = Blob.valueOf(htmlResponse);
                res.statusCode = 400;
                return;
            }

            // Validate required parameters
            if (String.isBlank(code)) {
                htmlResponse = generateErrorPage('Missing authorization code');
                res.responseBody = Blob.valueOf(htmlResponse);
                res.statusCode = 400;
                return;
            }

            if (String.isBlank(realmId)) {
                htmlResponse = generateErrorPage('Missing QuickBooks Company ID');
                res.responseBody = Blob.valueOf(htmlResponse);
                res.statusCode = 400;
                return;
            }

            // Exchange authorization code for tokens (using async future for system context)
            QuickBooksAuthHelper.processCallbackAsync(code, realmId);

            // Return success page immediately - token exchange happens in background
            htmlResponse = generateSuccessPage();
            res.statusCode = 200;

        } catch (Exception e) {
            htmlResponse = generateErrorPage('Error: ' + e.getMessage());
            res.statusCode = 500;
            logError('REST Callback Error', e.getMessage());
        }

        res.addHeader('Content-Type', 'text/html; charset=UTF-8');
        res.responseBody = Blob.valueOf(htmlResponse);
    }

    private static String generateSuccessPage() {
        return '<!DOCTYPE html>' +
            '<html>' +
            '<head>' +
            '    <title>QuickBooks Authorization</title>' +
            '    <style>' +
            '        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 0; padding: 0; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }' +
            '        .container { display: flex; justify-content: center; align-items: center; min-height: 100vh; }' +
            '        .card { background: white; padding: 40px; border-radius: 8px; box-shadow: 0 10px 40px rgba(0,0,0,0.2); text-align: center; max-width: 400px; }' +
            '        .checkmark { font-size: 48px; color: #3c3; }' +
            '        h1 { color: #333; margin-top: 0; font-size: 24px; }' +
            '        .success { background: #efe; color: #3c3; padding: 15px; border-radius: 4px; margin: 20px 0; }' +
            '        .info-box { background: #f0f0f0; padding: 15px; border-radius: 4px; margin: 20px 0; font-size: 13px; color: #666; }' +
            '    </style>' +
            '</head>' +
            '<body>' +
            '    <div class="container">' +
            '        <div class="card">' +
            '            <div class="checkmark">✓</div>' +
            '            <h1>Authorization Successful!</h1>' +
            '            <div class="success">' +
            '                <strong>Your QuickBooks account has been connected to Salesforce.</strong>' +
            '            </div>' +
            '            <div class="info-box">' +
            '                <p>Tokens have been saved and you can now create estimates and sync data with QuickBooks.</p>' +
            '                <p>You can close this window.</p>' +
            '            </div>' +
            '        </div>' +
            '    </div>' +
            '</body>' +
            '</html>';
    }

    private static String generateErrorPage(String errorMessage) {
        return '<!DOCTYPE html>' +
            '<html>' +
            '<head>' +
            '    <title>QuickBooks Authorization</title>' +
            '    <style>' +
            '        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 0; padding: 0; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }' +
            '        .container { display: flex; justify-content: center; align-items: center; min-height: 100vh; }' +
            '        .card { background: white; padding: 40px; border-radius: 8px; box-shadow: 0 10px 40px rgba(0,0,0,0.2); text-align: center; max-width: 400px; }' +
            '        h1 { color: #333; margin-top: 0; font-size: 24px; }' +
            '        .error { background: #fee; color: #c33; padding: 15px; border-radius: 4px; margin: 20px 0; }' +
            '        .info-box { background: #f0f0f0; padding: 15px; border-radius: 4px; margin: 20px 0; font-size: 13px; color: #666; }' +
            '    </style>' +
            '</head>' +
            '<body>' +
            '    <div class="container">' +
            '        <div class="card">' +
            '            <h1>Authorization Failed</h1>' +
            '            <div class="error">' +
            '                <strong>Error:</strong><br/>' +
            '                ' + errorMessage + '' +
            '            </div>' +
            '            <div class="info-box">' +
            '                <p>Please contact support if the problem persists.</p>' +
            '            </div>' +
            '        </div>' +
            '    </div>' +
            '</body>' +
            '</html>';
    }

    private static void logError(String context, String errorMessage) {
        try {
            Integration_Log__c log = new Integration_Log__c();
            log.Integration_Type__c = 'QuickBooks OAuth';
            log.Context__c = context;
            log.Error_Message__c = errorMessage;
            log.Timestamp__c = DateTime.now();
            insert log;
        } catch (Exception e) {
            System.debug('Failed to log error: ' + e.getMessage());
        }
    }
}
