/**
 * Controller for QuickBooksAuthStart page
 * Initiates OAuth 2.0 flow with QuickBooks
 * Note: Uses without sharing to allow Site Guest User access for OAuth initiation
 */
public without sharing class QuickBooksAuthStartController {
    public Boolean isProcessing { get; private set; }
    public Boolean isError { get; private set; }
    public String errorMessage { get; private set; }

    public QuickBooksAuthStartController() {
        isProcessing = true;
        isError = false;
        errorMessage = '';
    }

    /**
     * Redirects user to QuickBooks OAuth authorization endpoint
     */
    public PageReference redirectToQuickBooks() {
        try {
            PageReference redirectPage = QuickBooksAuthProvider.initiateAuthFlow();

            if (redirectPage != null) {
                // Redirect immediately
                redirectPage.setRedirect(true);
                return redirectPage;
            } else {
                throw new QuickBooksException('Failed to generate OAuth authorization URL');
            }
        } catch (Exception e) {
            isProcessing = false;
            isError = true;
            errorMessage = 'Failed to start authentication: ' + e.getMessage();

            // Log the error
            logError('OAuth Start Error', e.getMessage());

            return null;
        }
    }

    private void logError(String context, String errorMsg) {
        try {
            Integration_Log__c log = new Integration_Log__c();
            log.Integration_Type__c = 'QuickBooks OAuth';
            log.Context__c = context;
            log.Error_Message__c = errorMsg;
            log.Timestamp__c = DateTime.now();
            insert log;
        } catch (Exception e) {
            System.debug('Failed to log error: ' + e.getMessage());
        }
    }

    public class QuickBooksException extends Exception {}
}
