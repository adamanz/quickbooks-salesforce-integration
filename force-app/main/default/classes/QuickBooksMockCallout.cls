/**
 * Mock HTTP Callout Handler for QuickBooks API Testing
 * Implements HttpCalloutMock to provide mock responses for test methods
 */
@isTest
global class QuickBooksMockCallout implements HttpCalloutMock {

    private Integer statusCode;
    private String responseBody;
    private String endpoint;

    /**
     * Constructor with custom response
     */
    global QuickBooksMockCallout(Integer statusCode, String responseBody) {
        this.statusCode = statusCode;
        this.responseBody = responseBody;
    }

    /**
     * Default constructor for success responses
     */
    global QuickBooksMockCallout() {
        this.statusCode = 200;
    }

    /**
     * Implement HttpCalloutMock interface
     */
    global HTTPResponse respond(HTTPRequest request) {
        this.endpoint = request.getEndpoint();

        HttpResponse response = new HttpResponse();
        response.setStatusCode(statusCode);
        response.setHeader('Content-Type', 'application/json');

        // If a specific response body was provided (e.g. for error testing), use it
        if (responseBody != null) {
            response.setBody(responseBody);
            return response;
        }

        // Determine response based on endpoint
        if (endpoint.contains('/estimate')) {
            response.setBody(getEstimateResponse());
        } else if (endpoint.contains('/customer')) {
            response.setBody(getCustomerResponse());
        } else if (endpoint.contains('/invoice')) {
            response.setBody(getInvoiceResponse());
        } else if (endpoint.contains('/tokens/bearer')) {
            response.setBody(getTokenResponse());
        } else {
            response.setBody(getDefaultResponse());
        }

        return response;
    }

    /**
     * Mock response for estimate creation
     */
    private String getEstimateResponse() {
        return '{"Estimate": {' +
               '"Id": "EST-' + Math.round(Math.random() * 10000) + '",' +
               '"DocNumber": "1001",' +
               '"TxnDate": "' + Date.today().format() + '",' +
               '"CustomerRef": {"value": "123"},' +
               '"TotalAmt": 1000.00,' +
               '"Line": [' +
               '  {"Amount": 500.00, "Description": "Test Item 1"},' +
               '  {"Amount": 500.00, "Description": "Test Item 2"}' +
               ']}}';
    }

    /**
     * Mock response for customer creation
     */
    private String getCustomerResponse() {
        return '{"Customer": {' +
               '"Id": "CUST-' + Math.round(Math.random() * 10000) + '",' +
               '"DisplayName": "Test Customer",' +
               '"Active": true}}';
    }

    /**
     * Mock response for invoice creation
     */
    private String getInvoiceResponse() {
        return '{"Invoice": {' +
               '"Id": "INV-' + Math.round(Math.random() * 10000) + '",' +
               '"DocNumber": "2001",' +
               '"TxnDate": "' + Date.today().format() + '",' +
               '"CustomerRef": {"value": "123"},' +
               '"TotalAmt": 2000.00}}';
    }

    /**
     * Mock response for token refresh
     */
    private String getTokenResponse() {
        return '{' +
               '"access_token": "eyJhbGciOiJkaXIiLCJlbmMiOiJBMTI4Q0JDLUhTMjU2In0...' + Math.round(Math.random() * 10000) + '",' +
               '"refresh_token": "AB11234567890...' + Math.round(Math.random() * 10000) + '",' +
               '"expires_in": 3600,' +
               '"token_type": "bearer"' +
               '}';
    }

    /**
     * Default response
     */
    private String getDefaultResponse() {
        return '{"success": true, "message": "Mock response"}';
    }
}