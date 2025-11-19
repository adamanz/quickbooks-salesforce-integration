// Debug Script: Create Estimate via direct HTTP (simulating CURL)
// Usage: sf apex run -f scripts/apex/debugEstimateCurl.apex -o my-org

String companyId = '9341452808602382';
String customerId = '586';
String itemId = '200006002'; // Mapped ID for O2PU6520
Decimal amount = 78900.00;
Decimal discount = 12092.00;

System.debug('--- Starting Debug CURL ---');

try {
    // 1. Get Token
    String accessToken = QuickBooksAuthProvider.getValidAccessToken(companyId);
    if (String.isBlank(accessToken)) {
        System.debug('ERROR: No access token found.');
        return;
    }

    // 2. Construct JSON Payload (Manual construction to match your request exactly)
    Map<String, Object> payload = new Map<String, Object>();
    
    // Customer
    Map<String, Object> custRef = new Map<String, Object>();
    custRef.put('value', customerId);
    payload.put('CustomerRef', custRef);

    // Dates
    payload.put('TxnDate', String.valueOf(Date.today()));
    payload.put('ExpirationDate', String.valueOf(Date.today()));

    // Lines
    List<Object> lines = new List<Object>();
    
    // Line 1: The Product
    Map<String, Object> line1 = new Map<String, Object>();
    line1.put('DetailType', 'SalesItemLineDetail');
    line1.put('Amount', amount);
    line1.put('Description', 'Oxycell OxyPro Ultra 6500 2.0 ATA Chamber with All-In-One Machine...');
    
    Map<String, Object> salesDetail = new Map<String, Object>();
    salesDetail.put('Qty', 1);
    salesDetail.put('UnitPrice', amount);
    
    Map<String, Object> itemRef = new Map<String, Object>();
    itemRef.put('value', itemId); // TESTING THIS SPECIFIC ID
    salesDetail.put('ItemRef', itemRef);
    
    line1.put('SalesItemLineDetail', salesDetail);
    lines.add(line1);

    // Line 2: Discount
    Map<String, Object> discountLine = new Map<String, Object>();
    discountLine.put('DetailType', 'DiscountLineDetail');
    discountLine.put('Amount', discount);
    
    Map<String, Object> discountDetail = new Map<String, Object>();
    discountDetail.put('PercentBased', false);
    discountLine.put('DiscountLineDetail', discountDetail);
    lines.add(discountLine);

    payload.put('Line', lines);
    
    // Memos
    Map<String, Object> memo = new Map<String, Object>();
    memo.put('value', 'Test Memo');
    payload.put('CustomerMemo', memo);
    payload.put('PrivateNote', 'Test Private Note');

    String jsonBody = JSON.serialize(payload);
    System.debug('Payload: ' + jsonBody);

    // 3. Send Request
    HttpRequest req = new HttpRequest();
    req.setEndpoint('https://quickbooks.api.intuit.com/v3/company/' + companyId + '/estimate');
    req.setMethod('POST');
    req.setHeader('Accept', 'application/json');
    req.setHeader('Content-Type', 'application/json');
    req.setHeader('Authorization', 'Bearer ' + accessToken);
    req.setBody(jsonBody);
    req.setTimeout(60000);

    Http http = new Http();
    HttpResponse res = http.send(req);

    // 4. Output
    System.debug('Response Code: ' + res.getStatusCode());
    System.debug('Response Body: ' + res.getBody());

} catch (Exception e) {
    System.debug('Exception: ' + e.getMessage());
    System.debug(e.getStackTraceString());
}

