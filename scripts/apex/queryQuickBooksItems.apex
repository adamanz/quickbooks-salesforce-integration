// Query QuickBooks for Items
// Usage: sf apex run -f scripts/apex/queryQuickBooksItems.apex -o my-org
//
// This script demonstrates how to query QuickBooks Items via the API.
// Customize the queries below to search for your products.

// Get your QuickBooks Company ID from QuickBooks_Auth__c or QuickBooks_Config__mdt
String companyId = 'YOUR_COMPANY_ID';

try {
    String accessToken = QuickBooksAuthProvider.getValidAccessToken(companyId);

    // Example queries - customize these for your products
    List<String> queries = new List<String>{
        'select Id, Name, FullyQualifiedName, Sku, Type from Item maxresults 25',
        'select Id, Name, FullyQualifiedName, Sku from Item where Type = \'Service\' maxresults 10',
        'select Id, Name, FullyQualifiedName, Sku from Item where Type = \'Inventory\' maxresults 10'
        // Add more queries as needed:
        // 'select Id, Name, Sku from Item where Name like \'%YourProduct%\' maxresults 10'
    };

    System.debug('--- Starting QuickBooks Item Search ---');

    for (String q : queries) {
        String encodedQuery = EncodingUtil.urlEncode(q, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://quickbooks.api.intuit.com/v3/company/' + companyId + '/query?query=' + encodedQuery);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + accessToken);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            System.debug('Query: ' + q);
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Map<String, Object> queryResponse = (Map<String, Object>) result.get('QueryResponse');
            if (queryResponse.containsKey('Item')) {
                List<Object> items = (List<Object>) queryResponse.get('Item');
                for (Object itemObj : items) {
                    Map<String, Object> item = (Map<String, Object>) itemObj;
                    System.debug('  Name: ' + item.get('Name'));
                    System.debug('  ID: ' + item.get('Id'));
                    System.debug('  SKU: ' + item.get('Sku'));
                    System.debug('  Type: ' + item.get('Type'));
                    System.debug('  ---');
                }
            } else {
                System.debug('  No items found.');
            }
        } else {
            System.debug('Error for query ' + q + ': ' + res.getStatusCode() + ' ' + res.getBody());
        }
    }

} catch (Exception e) {
    System.debug('Error: ' + e.getMessage());
}
