/**
 * Simplified QuickBooks Webhook Handler for initial deployment
 * This version just logs webhook receipts to prove the endpoint works
 */
@RestResource(urlMapping='/quickbooks/webhook/simple/*')
global with sharing class QuickBooksWebhookSimple {

    @HttpPost
    global static void handleWebhook() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            // Log the webhook receipt
            String requestBody = req.requestBody != null ? req.requestBody.toString() : 'Empty body';
            System.debug('QuickBooks Webhook Received: ' + requestBody);

            // Log to Integration_Log__c
            Integration_Log__c log = new Integration_Log__c(
                Integration_Type__c = 'QuickBooks Webhook',
                Context__c = 'Webhook Received',
                Error_Message__c = 'Webhook body: ' + requestBody.left(32000),
                Timestamp__c = DateTime.now()
            );
            insert log;

            // Return success
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('Webhook received successfully');

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error: ' + e.getMessage());
        }
    }

    @HttpGet
    global static void verifyEndpoint() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String challenge = req.params.get('challenge');
        if (String.isNotBlank(challenge)) {
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(challenge);
        } else {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('Missing challenge parameter');
        }
    }
}