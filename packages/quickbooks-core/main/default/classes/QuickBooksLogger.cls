/**
 * QuickBooks Logger Utility
 * Centralized logging for QuickBooks integration with intuit_tid capture
 */
public class QuickBooksLogger {

    /**
     * Log error with intuit_tid from response headers
     */
    public static void logError(String context, String message, String recordId, HttpResponse response) {
        String intuitTid = null;

        // Capture intuit_tid from response headers if available
        if (response != null) {
            intuitTid = response.getHeader('intuit_tid');
        }

        logError(context, message, recordId, intuitTid);
    }

    /**
     * Log error with manual intuit_tid
     */
    public static void logError(String context, String message, String recordId, String intuitTid) {
        try {
            Integration_Log__c log = new Integration_Log__c(
                Integration_Type__c = 'QuickBooks',
                Context__c = context,
                Error_Message__c = message,
                Record_Id__c = recordId,
                Intuit_TID__c = intuitTid,
                Timestamp__c = DateTime.now()
            );
            insert log;
        } catch (Exception e) {
            // Fallback: Log to system debug if insert fails
            System.debug('Failed to create integration log: ' + e.getMessage());
            System.debug('Original error - Context: ' + context + ', Message: ' + message);
        }
    }

    /**
     * Log success with intuit_tid for audit trail
     */
    public static void logSuccess(String context, String message, String recordId, HttpResponse response) {
        String intuitTid = null;

        if (response != null) {
            intuitTid = response.getHeader('intuit_tid');
        }

        try {
            Integration_Log__c log = new Integration_Log__c(
                Integration_Type__c = 'QuickBooks',
                Context__c = context + ' - Success',
                Error_Message__c = message,
                Record_Id__c = recordId,
                Intuit_TID__c = intuitTid,
                Timestamp__c = DateTime.now()
            );
            insert log;
        } catch (Exception e) {
            System.debug('Failed to create success log: ' + e.getMessage());
        }
    }

    /**
     * Log API call details for troubleshooting
     */
    public static void logAPICall(String endpoint, String method, Integer statusCode,
                                  String requestBody, String responseBody, HttpResponse response) {
        String intuitTid = null;

        if (response != null) {
            intuitTid = response.getHeader('intuit_tid');
        }

        String logMessage = String.format(
            'API Call Details:\nEndpoint: {0}\nMethod: {1}\nStatus: {2}\nRequest: {3}\nResponse: {4}',
            new List<String>{
                endpoint,
                method,
                String.valueOf(statusCode),
                truncate(requestBody, 1000),
                truncate(responseBody, 1000)
            }
        );

        try {
            Integration_Log__c log = new Integration_Log__c(
                Integration_Type__c = 'QuickBooks API Call',
                Context__c = method + ' ' + endpoint,
                Error_Message__c = logMessage,
                Intuit_TID__c = intuitTid,
                Timestamp__c = DateTime.now()
            );
            insert log;
        } catch (Exception e) {
            System.debug('Failed to log API call: ' + e.getMessage());
        }
    }

    /**
     * Truncate string to max length
     */
    private static String truncate(String str, Integer maxLength) {
        if (String.isBlank(str)) {
            return '';
        }
        return str.length() > maxLength ? str.substring(0, maxLength) + '...' : str;
    }

    /**
     * Helper class to store response with intuit_tid
     */
    public class APIResponse {
        public HttpResponse response { get; set; }
        public String intuitTid { get; set; }
        public Boolean success { get; set; }
        public String errorMessage { get; set; }

        public APIResponse(HttpResponse res) {
            this.response = res;
            this.intuitTid = res != null ? res.getHeader('intuit_tid') : null;
            this.success = res != null && res.getStatusCode() >= 200 && res.getStatusCode() < 300;
        }
    }
}