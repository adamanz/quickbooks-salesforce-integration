# End-to-End Test Guide: Authentication & QB API

**Goal:** Complete the full authentication flow and test QB Estimate API

**Current Status:**
- ✅ Salesforce OAuth config deployed
- ✅ QB credentials stored in Custom Metadata
- ❌ **AUTH TOKENS NOT YET OBTAINED** - Need manual OAuth flow

---

## Phase 1: Complete OAuth 2.0 Flow (MANUAL)

### Current Status
```
Auth Records: 0
Config: ✓ Found with Client ID: ABVXMjcDNzYm3f9...
Sandbox: ✓ Enabled (testing in QB Sandbox)
```

### Step 1: Initiate Authentication

**Option A: Via Visualforce Page (Recommended)**

Open this URL in your browser (logged in as a@simple.company.oxycell):
```
https://oxycell.lightning.force.com/apex/QuickBooksAuthStart
```

**What happens:**
1. Page loads QuickBooksOAuthController
2. Controller calls `QuickBooksAuthProvider.initiateAuthFlow()`
3. Browser redirects to QuickBooks login
4. You see: "Sign in to your QuickBooks Online account"

### Step 2: Authorize in QuickBooks

1. **Log into QB with your sandbox account credentials**
   - Username: [Your QB sandbox username]
   - Password: [Your QB sandbox password]

2. **Grant Permission to Salesforce**
   - You'll see: "Salesforce is requesting access to your QuickBooks data"
   - Click "Authorize"

3. **Authorization Code Exchange**
   - QB redirects back to Salesforce
   - URL becomes: `https://oxycell.lightning.force.com/apex/QuickBooksAuthCallback?code=XXXXXXX&realmId=YYYYYY`
   - Controller captures `code` and `realmId`
   - Controller calls `QuickBooksAuthProvider.handleCallback(code, realmId)`

### Step 3: Token Exchange (Automatic)

The `handleCallback()` method performs these steps automatically:

```
1. POST to: https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer
2. Send: Authorization header (Basic auth with Client ID + Secret)
3. Send: code, redirect_uri in body
4. Receive: access_token, refresh_token, expires_in
5. Store: Save tokens in QuickBooks_Auth__c object
```

**What gets stored:**
```
QuickBooks_Auth__c record
├── Company_Id__c: "1234567890" (Your QB Company ID)
├── Access_Token__c: "eyJkb2MiOiJRQk9... " (Bearer token for API calls)
├── Refresh_Token__c: "L0744324...  " (Used to get new access tokens)
├── Token_Type__c: "Bearer"
├── Expires_In__c: 3600 (seconds)
├── Token_Expiry__c: 2025-11-17 14:14:00 (Now + 1 hour)
└── Is_Active__c: true
```

### ✅ Phase 1 Complete When:
- You see success screen in browser
- Browser shows: ✓ QB Estimate created successfully!
- OR error message with details

---

## Phase 2: Verify Auth Tokens Saved (AUTOMATED TEST)

Once you complete Phase 1, run this Apex code to verify tokens were stored:

```apex
System.debug('=== VERIFYING AUTH TOKENS ===');

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
```

**Expected Output:**
```
✓ Auth token found
  Company ID: 1234567890
  Token exists: true
  Token length: 487
  Token expires: 2025-11-17 14:14:00
  Active: true
✓ PHASE 2 PASSED: Tokens stored successfully
```

---

## Phase 3: Test Token Retrieval (AUTOMATED TEST)

This tests the `QuickBooksAuthProvider.getValidAccessToken()` method:

```apex
System.debug('=== TESTING TOKEN RETRIEVAL ===');

try {
    // Get the company ID from stored auth record
    List<QuickBooks_Auth__c> authRecords = [
        SELECT Company_Id__c FROM QuickBooks_Auth__c LIMIT 1
    ];

    if (authRecords.isEmpty()) {
        System.debug('❌ FAILED: No auth tokens - run OAuth flow first');
        return;
    }

    String companyId = authRecords[0].Company_Id__c;
    System.debug('Using Company ID: ' + companyId);

    // Call the token retrieval method
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
```

**Expected Output:**
```
Using Company ID: 1234567890
✓ Token retrieved successfully
  Token prefix: eyJkb2MiOiJRQk9...
  Token length: 487
✓ PHASE 3 PASSED: Token retrieval works
```

---

## Phase 4: Test QB API Call (AUTOMATED TEST)

This makes an actual HTTP request to QuickBooks:

```apex
System.debug('=== TESTING QB API CALL ===');

try {
    // Get auth token
    List<QuickBooks_Auth__c> authRecords = [
        SELECT Company_Id__c FROM QuickBooks_Auth__c LIMIT 1
    ];

    if (authRecords.isEmpty()) {
        System.debug('❌ FAILED: No auth tokens');
        return;
    }

    String companyId = authRecords[0].Company_Id__c;
    String accessToken = QuickBooksAuthProvider.getValidAccessToken(companyId);

    // Build test API call
    Http http = new Http();
    HttpRequest req = new HttpRequest();

    // Query endpoint - simpler than create
    String baseUrl = 'https://sandbox-quickbooks.api.intuit.com';
    req.setEndpoint(baseUrl + '/v4/customers');
    req.setMethod('GET');
    req.setHeader('Authorization', 'Bearer ' + accessToken);
    req.setHeader('Accept', 'application/json');
    req.setTimeout(30000);

    System.debug('Calling: GET /v4/customers');
    System.debug('Authorization: Bearer ' + accessToken.substring(0, 20) + '...');

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
        System.debug('Response: ' + res.getBody().substring(0, 200));
    }
} catch (Exception e) {
    System.debug('❌ FAILED: ' + e.getMessage());
}
```

**Expected Output (Success):**
```
Calling: GET /v4/customers
Authorization: Bearer eyJkb2MiOiJRQk9...
Response Status: 200 OK
✓ QB API is accessible
✓ Auth token is valid
✓ PHASE 4 PASSED: QB API reachable with valid auth
```

**Possible Failure Scenarios:**

| Status | Meaning | Fix |
|--------|---------|-----|
| 401 | Unauthorized | Re-run OAuth flow |
| 403 | Forbidden | Check QB app permissions |
| 404 | Not Found | Check API endpoint URL |
| 429 | Rate Limited | Wait and retry |

---

## Phase 5: Create Estimate via Invocable (AUTOMATED TEST)

Once Phase 4 passes, run the full estimate creation test:

```apex
System.debug('=== PHASE 5: CREATE ESTIMATE ===');

try {
    // Get company ID from auth
    List<QuickBooks_Auth__c> authRecords = [
        SELECT Company_Id__c FROM QuickBooks_Auth__c LIMIT 1
    ];

    if (authRecords.isEmpty()) {
        System.debug('❌ Auth tokens required - complete OAuth flow first');
        return;
    }

    String companyId = authRecords[0].Company_Id__c;
    System.debug('Using Company ID: ' + companyId);

    // Build estimate request
    QuickBooksEstimateInvocable.EstimateRequest request =
        new QuickBooksEstimateInvocable.EstimateRequest();

    request.opportunityId = '006V500000Jw7KnIAJ';
    request.companyId = companyId;
    request.estimateDate = Date.valueOf('2025-11-07');
    request.expirationDate = Date.valueOf('2025-12-07');
    request.discountAmount = 15092.00;
    request.applyTaxAfterDiscount = true;
    request.customerMemo = 'Thank you for your business!';

    System.debug('Estimate Request:');
    System.debug('  Opportunity: 006V500000Jw7KnIAJ (Adam Smith)');
    System.debug('  Company ID: ' + companyId);
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
    } else {
        System.debug('❌ PHASE 5 FAILED: ' + resp.message);
    }

} catch (Exception e) {
    System.debug('❌ EXCEPTION: ' + e.getMessage());
    System.debug('Stack: ' + e.getStackTraceString());
}
```

**Expected Success Output:**
```
Using Company ID: 1234567890
Estimate Request:
  Opportunity: 006V500000Jw7KnIAJ (Adam Smith)
  Dates: 2025-11-07 to 2025-12-07
  Discount: $15,092.00
Response:
  Success: true
  Message: Estimate created successfully
  QB Estimate ID: 31
  QB Estimate #: 0000031
✓ PHASE 5 PASSED: Estimate created in QB!
```

---

## Complete E2E Test Checklist

Run through these phases in order:

- [ ] **Phase 1:** Complete OAuth at https://oxycell.lightning.force.com/apex/QuickBooksAuthStart
  - Logged in to QB
  - Clicked "Authorize"
  - Saw callback URL with code

- [ ] **Phase 2:** Verify tokens with provided Apex (check for ✓ PHASE 2 PASSED)

- [ ] **Phase 3:** Test token retrieval with provided Apex (check for ✓ PHASE 3 PASSED)

- [ ] **Phase 4:** Test QB API reachability with provided Apex (check for ✓ PHASE 4 PASSED)

- [ ] **Phase 5:** Create estimate with provided Apex (check for ✓ PHASE 5 PASSED)

- [ ] **Verify in QB:** Log into QB and check:
  - New estimate exists
  - For: Opportunity customer (check if linked)
  - With estimate #: From response
  - Dates: 11/07/2025 - 12/07/2025
  - Line items: From Opportunity or custom
  - Discount: $15,092.00

---

## Troubleshooting

### "No auth tokens found" in Phase 2
**Cause:** OAuth flow didn't complete successfully
**Fix:**
1. Check browser console for errors
2. Verify redirect URI in QB app settings matches Salesforce
3. Re-run OAuth flow at https://oxycell.lightning.force.com/apex/QuickBooksAuthStart

### "401 Unauthorized" in Phase 4
**Cause:** Access token invalid or expired
**Fix:**
1. Check Token_Expiry__c timestamp
2. If expired, QuickBooksAuthProvider should auto-refresh (check code)
3. If still failing, re-run OAuth flow

### "403 Forbidden" in Phase 4
**Cause:** App doesn't have required permissions
**Fix:**
1. Check QB app permissions in developer.intuit.com
2. Ensure "com.intuit.quickbooks.accounting" scope is selected
3. Re-authorize if permissions changed

### "400 Bad Request" on estimate creation
**Cause:** Invalid request data
**Possible issues:**
- Customer doesn't exist in QB for this company
- Product items don't exist
- Amount format incorrect
**Fix:** Verify line items and customer in QB

### "404 Not Found"
**Cause:** Invalid API endpoint or company ID
**Fix:**
1. Verify company ID is correct (from QB Account & Settings)
2. Verify API endpoint URL is correct
3. Check if using sandbox vs production URL

---

## Log Locations

### Apex Debug Logs
```
Setup → Logs → Debug Logs
Filter by user: a@simple.company.oxycell
```

### Integration Logs
```
QuickBooks Integration custom object
See: Integration_Log__c records
```

### QB API Response Details
Check the `message` field in EstimateResponse for:
- API error codes
- Detailed failure reasons
- Invalid field references
