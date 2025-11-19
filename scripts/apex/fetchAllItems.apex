// Query QuickBooks for all relevant items to build the mapping list
String companyId = '9341452808602382';

try {
    String accessToken = QuickBooksAuthProvider.getValidAccessToken(companyId);
    
    // Broad query to fetch many items
    String query = 'select Id, Name from Item startposition 1 maxresults 100'; 
    // URL Encode
    query = EncodingUtil.urlEncode(query, 'UTF-8');
    
    HttpRequest req = new HttpRequest();
    req.setEndpoint('https://quickbooks.api.intuit.com/v3/company/' + companyId + '/query?query=' + query);
    req.setMethod('GET');
    req.setHeader('Accept', 'application/json');
    req.setHeader('Authorization', 'Bearer ' + accessToken);
    
    Http http = new Http();
    HttpResponse res = http.send(req);
    
    System.debug('Response Body: ' + res.getBody());
    
} catch (Exception e) {
    System.debug('Error: ' + e.getMessage());
}

