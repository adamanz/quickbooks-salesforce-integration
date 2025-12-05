/**
 * Helper class to handle OAuth operations in system context
 * This allows REST endpoints to perform DML without requiring user session
 */
global without sharing class QuickBooksAuthHelper {

    /**
     * Process OAuth callback in system context using future method
     * @param code Authorization code from QuickBooks
     * @param realmId QuickBooks company ID
     * @return Boolean indicating success
     */
    @future(callout=true)
    global static void processCallbackAsync(String code, String realmId) {
        try {
            QuickBooksAuthProvider.handleCallback(code, realmId);
        } catch (Exception e) {
            System.debug('Error in async callback: ' + e.getMessage());
            logError('Async OAuth Callback', e.getMessage());
        }
    }

    /**
     * Synchronous version for testing
     * @param code Authorization code from QuickBooks
     * @param realmId QuickBooks company ID
     * @return Boolean indicating success
     */
    global static Boolean processCallback(String code, String realmId) {
        return QuickBooksAuthProvider.handleCallback(code, realmId);
    }

    /**
     * Log errors to Integration_Log__c for visibility
     */
    private static void logError(String context, String message) {
        try {
            Integration_Log__c log = new Integration_Log__c(
                Integration_Type__c = 'QuickBooks OAuth',
                Context__c = context,
                Error_Message__c = message,
                Timestamp__c = DateTime.now()
            );
            insert log;
        } catch (Exception e) {
            System.debug('Failed to log async OAuth error: ' + e.getMessage());
        }
    }
}
