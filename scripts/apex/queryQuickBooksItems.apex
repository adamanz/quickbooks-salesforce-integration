// Query QuickBooks for valid Items to find the correct ID
// Usage: sf apex run -f scripts/apex/queryQuickBooksItems.apex -o my-org

String companyId = '9341452808602382';

try {
    String accessToken = QuickBooksAuthProvider.getValidAccessToken(companyId);
    
    // Query for the specific product name OR just list the first 5 items
    // Trying to find "OxyPro" related items first
    String query = 'select Id, Name, FullyQualifiedName from Item where Name like \'%OxyPro%\' maxresults 10';
    // URL Encode the query
    query = EncodingUtil.urlEncode(query, 'UTF-8');
    
    HttpRequest req = new HttpRequest();
    req.setEndpoint('https://quickbooks.api.intuit.com/v3/company/' + companyId + '/query?query=' + query);
    req.setMethod('GET');
    req.setHeader('Accept', 'application/json');
    req.setHeader('Authorization', 'Bearer ' + accessToken);
    
    Http http = new Http();
    HttpResponse res = http.send(req);
    
    System.debug('Response Code: ' + res.getStatusCode());
    System.debug('Response Body: ' + res.getBody());
    
} catch (Exception e) {
    System.debug('Error: ' + e.getMessage());
}

