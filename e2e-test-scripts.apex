// ============================================================
// E2E TEST SCRIPTS - Run these after each phase
// ============================================================

// ============================================================
// PHASE 2: Verify Auth Tokens Saved
// ============================================================
// Run after completing OAuth flow
// Expected: ✓ Auth token found, ✓ PHASE 2 PASSED

System.debug('=== PHASE 2: VERIFY AUTH TOKENS ===');

List<QuickBooks_Auth__c> authRecords = [
    SELECT Id, Company_Id__c, Access_Token__c, Token_Expiry__c, Is_Active__c
    FROM QuickBooks_Auth__c
    LIMIT 1
];

if (authRecords.isEmpty()) {
    System.debug('❌ FAILED: No auth tokens found');
    System.debug('ACTION: Re-run OAuth flow at https://oxycell.lightning.force.com/apex/QuickBooksAuthStart');
} else {
    QuickBooks_Auth__c auth = authRecords[0];
    System.debug('✓ Auth token found');
    System.debug('  Company ID: ' + auth.Company_Id__c);
    System.debug('  Token exists: ' + (auth.Access_Token__c != null));
    System.debug('  Token length: ' + (auth.Access_Token__c != null ? auth.Access_Token__c.length() : 0));
    System.debug('  Token expires: ' + auth.Token_Expiry__c);
    System.debug('  Active: ' + auth.Is_Active__c);
    System.debug('✓ PHASE 2 PASSED: Tokens stored successfully');
}

// ============================================================
// PHASE 3: Test Token Retrieval
// ============================================================
// Run after Phase 2 passes
// Expected: ✓ Token retrieved successfully, ✓ PHASE 3 PASSED

System.debug('=== PHASE 3: TEST TOKEN RETRIEVAL ===');

try {
    List<QuickBooks_Auth__c> authRecords2 = [
        SELECT Company_Id__c FROM QuickBooks_Auth__c LIMIT 1
    ];

    if (authRecords2.isEmpty()) {
        System.debug('❌ FAILED: No auth tokens - run OAuth flow first');
        return;
    }

    String companyId = authRecords2[0].Company_Id__c;
    System.debug('Using Company ID: ' + companyId);

    String accessToken = QuickBooksAuthProvider.getValidAccessToken(companyId);

    if (accessToken == null) {
        System.debug('❌ FAILED: getValidAccessToken() returned null');
    } else {
        System.debug('✓ Token retrieved successfully');
        System.debug('  Token prefix: ' + accessToken.substring(0, 20) + '...');
        System.debug('  Token length: ' + accessToken.length());
        System.debug('✓ PHASE 3 PASSED: Token retrieval works');
    }
} catch (Exception e) {
    System.debug('❌ FAILED: ' + e.getMessage());
    System.debug('Stack: ' + e.getStackTraceString());
}

// ============================================================
// PHASE 4: Test QB API Call
// ============================================================
// Run after Phase 3 passes
// Expected: 200 OK, ✓ PHASE 4 PASSED

System.debug('=== PHASE 4: TEST QB API CALL ===');

try {
    List<QuickBooks_Auth__c> authRecords3 = [
        SELECT Company_Id__c FROM QuickBooks_Auth__c LIMIT 1
    ];

    if (authRecords3.isEmpty()) {
        System.debug('❌ FAILED: No auth tokens');
        return;
    }

    String companyId3 = authRecords3[0].Company_Id__c;
    String accessToken3 = QuickBooksAuthProvider.getValidAccessToken(companyId3);

    Http http = new Http();
    HttpRequest req = new HttpRequest();

    String baseUrl = 'https://sandbox-quickbooks.api.intuit.com';
    req.setEndpoint(baseUrl + '/v4/customers');
    req.setMethod('GET');
    req.setHeader('Authorization', 'Bearer ' + accessToken3);
    req.setHeader('Accept', 'application/json');
    req.setTimeout(30000);

    System.debug('Calling: GET /v4/customers');
    System.debug('Authorization: Bearer ' + accessToken3.substring(0, 20) + '...');

    HttpResponse res = http.send(req);

    System.debug('Response Status: ' + res.getStatusCode() + ' ' + res.getStatus());

    if (res.getStatusCode() == 200) {
        System.debug('✓ QB API is accessible');
        System.debug('✓ Auth token is valid');
        System.debug('✓ PHASE 4 PASSED: QB API reachable with valid auth');
    } else if (res.getStatusCode() == 401) {
        System.debug('❌ FAILED: 401 Unauthorized');
        System.debug('  Issue: Token may be expired or invalid');
        System.debug('  Action: Re-run OAuth flow');
    } else {
        System.debug('⚠ Unexpected Status: ' + res.getStatusCode());
        System.debug('Response: ' + res.getBody().substring(0, Math.min(200, res.getBody().length())));
    }
} catch (Exception e) {
    System.debug('❌ FAILED: ' + e.getMessage());
}

// ============================================================
// PHASE 5: Create Estimate via Invocable
// ============================================================
// Run after Phase 4 passes
// Expected: Success: true, QB Estimate ID returned, ✓ PHASE 5 PASSED

System.debug('=== PHASE 5: CREATE ESTIMATE ===');

try {
    List<QuickBooks_Auth__c> authRecords4 = [
        SELECT Company_Id__c FROM QuickBooks_Auth__c LIMIT 1
    ];

    if (authRecords4.isEmpty()) {
        System.debug('❌ Auth tokens required - complete OAuth flow first');
        return;
    }

    String companyId4 = authRecords4[0].Company_Id__c;
    System.debug('Using Company ID: ' + companyId4);

    // Build estimate request
    QuickBooksEstimateInvocable.EstimateRequest request =
        new QuickBooksEstimateInvocable.EstimateRequest();

    request.opportunityId = '006V500000Jw7KnIAJ';
    request.companyId = companyId4;
    request.estimateDate = Date.valueOf('2025-11-07');
    request.expirationDate = Date.valueOf('2025-12-07');
    request.discountAmount = 15092.00;
    request.applyTaxAfterDiscount = true;
    request.customerMemo = 'Thank you for your business!';

    System.debug('Estimate Request:');
    System.debug('  Opportunity: 006V500000Jw7KnIAJ (Adam Smith)');
    System.debug('  Company ID: ' + companyId4);
    System.debug('  Dates: 2025-11-07 to 2025-12-07');
    System.debug('  Discount: $15,092.00');

    // Execute the invocable
    List<QuickBooksEstimateInvocable.EstimateResponse> responses =
        QuickBooksEstimateInvocable.createEstimate(
            new List<QuickBooksEstimateInvocable.EstimateRequest>{request}
        );

    // Check response
    if (responses.isEmpty()) {
        System.debug('❌ FAILED: No response returned');
        return;
    }

    QuickBooksEstimateInvocable.EstimateResponse resp = responses[0];

    System.debug('Response:');
    System.debug('  Success: ' + resp.success);
    System.debug('  Message: ' + resp.message);
    System.debug('  QB Estimate ID: ' + resp.quickBooksEstimateId);
    System.debug('  QB Estimate #: ' + resp.quickBooksEstimateNumber);

    if (resp.success) {
        System.debug('✓ PHASE 5 PASSED: Estimate created in QB!');
        System.debug('  QB ID: ' + resp.quickBooksEstimateId);
        System.debug('  QB Doc#: ' + resp.quickBooksEstimateNumber);
        System.debug('✓✓✓ E2E TEST COMPLETE ✓✓✓');
    } else {
        System.debug('❌ PHASE 5 FAILED: ' + resp.message);
    }

} catch (Exception e) {
    System.debug('❌ EXCEPTION: ' + e.getMessage());
    System.debug('Stack: ' + e.getStackTraceString());
}
