// Script to verify QuickBooks IDs
String companyId = '9341452808602382'; // Your Prod Company ID

// 1. Check Customer 586
try {
    String endpoint = 'https://quickbooks.api.intuit.com/v3/company/' + companyId + '/customer/586';
    HttpRequest req = new HttpRequest();
    req.setEndpoint(endpoint);
    req.setMethod('GET');
    req.setHeader('Accept', 'application/json');
    req.setHeader('Authorization', 'Bearer ' + QuickBooksAuthProvider.getValidAccessToken(companyId));
    
    Http http = new Http();
    HttpResponse res = http.send(req);
    System.debug('Customer 586 Check: ' + res.getStatusCode() + ' ' + res.getStatus());
    if (res.getStatusCode() != 200) System.debug('Body: ' + res.getBody());
} catch (Exception e) {
    System.debug('Error checking customer: ' + e.getMessage());
}

// 2. Check Item 1 (Our fallback)
try {
    String endpoint = 'https://quickbooks.api.intuit.com/v3/company/' + companyId + '/item/1';
    HttpRequest req = new HttpRequest();
    req.setEndpoint(endpoint);
    req.setMethod('GET');
    req.setHeader('Accept', 'application/json');
    req.setHeader('Authorization', 'Bearer ' + QuickBooksAuthProvider.getValidAccessToken(companyId));
    
    Http http = new Http();
    HttpResponse res = http.send(req);
    System.debug('Item 1 Check: ' + res.getStatusCode() + ' ' + res.getStatus());
    if (res.getStatusCode() != 200) System.debug('Body: ' + res.getBody());
} catch (Exception e) {
    System.debug('Error checking item 1: ' + e.getMessage());
}

// 3. Check Item 200006002 (The one we mapped)
try {
    String endpoint = 'https://quickbooks.api.intuit.com/v3/company/' + companyId + '/item/200006002';
    HttpRequest req = new HttpRequest();
    req.setEndpoint(endpoint);
    req.setMethod('GET');
    req.setHeader('Accept', 'application/json');
    req.setHeader('Authorization', 'Bearer ' + QuickBooksAuthProvider.getValidAccessToken(companyId));
    
    Http http = new Http();
    HttpResponse res = http.send(req);
    System.debug('Item 200006002 Check: ' + res.getStatusCode() + ' ' + res.getStatus());
    if (res.getStatusCode() != 200) System.debug('Body: ' + res.getBody());
} catch (Exception e) {
    System.debug('Error checking item 200006002: ' + e.getMessage());
}

