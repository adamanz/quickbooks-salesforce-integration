# Quick Reference Card

## URLs
| Purpose | URL |
|---------|-----|
| **Start OAuth** | `https://oxycell.lightning.force.com/apex/QuickBooksAuthStart` |
| **Developer Console** | `https://oxycell.lightning.force.com/` (Click avatar → Dev Console) |
| **QB Sandbox** | `https://sandbox.qbo.intuit.com` |
| **Intuit Developer** | `https://developer.intuit.com/app/developer/myapps` |

---

## Apex Code to Run

### Check Auth Tokens Exist
```apex
List<QuickBooks_Auth__c> auth = [SELECT Id FROM QuickBooks_Auth__c LIMIT 1];
System.debug('Tokens exist: ' + !auth.isEmpty());
```

### Get Company ID
```apex
List<QuickBooks_Auth__c> auth = [SELECT Company_Id__c FROM QuickBooks_Auth__c LIMIT 1];
System.debug('Company ID: ' + auth[0].Company_Id__c);
```

### Test Token Retrieval
```apex
String token = QuickBooksAuthProvider.getValidAccessToken('1234567890');
System.debug('Token: ' + (token != null ? 'SUCCESS' : 'FAILED'));
```

### Check Config
```apex
QuickBooks_Config__mdt config = QuickBooks_Config__mdt.getInstance('Default');
System.debug('Client ID: ' + config.Client_Id__c);
System.debug('Sandbox: ' + config.Is_Sandbox__c);
```

---

## Objects & Fields

### QuickBooks_Auth__c (Custom Object)
| Field | Type | Purpose |
|-------|------|---------|
| Company_Id__c | Text | QB Company ID (RealmId) |
| Access_Token__c | Long Text | Bearer token for API calls |
| Refresh_Token__c | Long Text | Token to get new access token |
| Token_Type__c | Text | Type = "Bearer" |
| Expires_In__c | Number | Seconds until expiry (usually 3600) |
| Token_Expiry__c | DateTime | When token expires |
| Is_Active__c | Checkbox | Whether this auth is active |

### QuickBooks_Config__mdt (Custom Metadata)
| Field | Type | Purpose |
|-------|------|---------|
| Client_Id__c | Text | OAuth Client ID from Intuit |
| Client_Secret__c | Text | OAuth Client Secret from Intuit |
| Redirect_URI__c | URL | Callback URL after QB auth |
| Is_Sandbox__c | Checkbox | true=sandbox, false=production |
| Webhook_Verifier_Token__c | Text | For webhook verification |

---

## API Endpoints

### QB REST API v3 (Estimates)
```
POST https://sandbox-quickbooks.api.intuit.com/v3/company/{realmId}/estimate
Headers:
  Authorization: Bearer {access_token}
  Content-Type: application/json
  Accept: application/json

Body: {
  "Estimate": {
    "CustomerRef": {"value": "{customerId}"},
    "itemLines": [...],
    "TxnDate": "2025-11-07",
    "ExpirationDate": "2025-12-07",
    "discount": {"amount": {"value": 15092.00}},
    ...
  }
}

Response: {
  "Estimate": {
    "Id": "31",
    "DocNumber": "0000031",
    ...
  }
}
```

### QB OAuth Token Endpoint
```
POST https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer
Headers:
  Authorization: Basic {base64(clientId:clientSecret)}
  Content-Type: application/x-www-form-urlencoded

Body:
  grant_type=authorization_code
  &code={authCode}
  &redirect_uri={redirectUri}

Response: {
  "access_token": "...",
  "refresh_token": "...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

---

## Classes & Methods

### QuickBooksAuthProvider
| Method | Purpose |
|--------|---------|
| `initiateAuthFlow()` | Start OAuth flow, return redirect to QB |
| `handleCallback(code, realmId)` | Process OAuth callback, exchange code for tokens |
| `exchangeCodeForToken(code)` | Make token exchange request to QB |
| `getValidAccessToken(companyId)` | Get token, refresh if needed |
| `storeTokens(data, realmId)` | Save tokens to QuickBooks_Auth__c |

### QuickBooksEstimateInvocable
| Class | Purpose |
|-------|---------|
| `createEstimate(requests)` | @InvocableMethod to create QB estimates |
| `buildEstimateData(opp, request, customerId)` | Build estimate JSON for QB API |
| `buildEstimateLineItem(lineItem, seq)` | Build single line item |
| `makeAPICall(method, endpoint, body, companyId)` | Make HTTP request to QB API |

#### Inner Classes
```
EstimateRequest {
  opportunityId: Id,
  companyId: String,
  lineItems: List<EstimateLineItem>,
  discountAmount: Decimal,
  estimateDate: Date,
  expirationDate: Date,
  customerMemo: String,
  ...
}

EstimateLineItem {
  description: String,
  quantity: Decimal,
  unitPrice: Decimal,
  amount: Decimal,
  quickBooksItemId: String
}

EstimateResponse {
  success: Boolean,
  message: String,
  quickBooksEstimateId: String,
  quickBooksEstimateNumber: String
}
```

---

## Common Issues & Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| No auth tokens | OAuth not completed | Run `https://oxycell.lightning.force.com/apex/QuickBooksAuthStart` |
| 401 Unauthorized | Invalid token | Check token expiry, re-run OAuth if expired |
| 403 Forbidden | Missing permissions | Check QB app has "Accounting" scope |
| Customer not found | QB has no matching customer | Create customer in QB first |
| Invalid Company ID | Using wrong ID | Get from QB Account Settings → Billing |
| Rate limited (429) | Too many requests | Wait and retry |

---

## Debug Log Locations

```
Setup → Logs → Debug Logs          # For Apex execution logs
Setup → Custom Objects → Integration_Log__c  # For API errors
```

---

## Key Concepts

**OAuth 2.0 Flow:**
1. User clicks auth link
2. Redirects to QB login
3. User authorizes app
4. QB returns authorization code
5. Salesforce exchanges code for tokens
6. Tokens stored in custom object
7. Tokens used for all future API calls

**Token Management:**
- Access token: Short-lived (1 hour), used for API calls
- Refresh token: Long-lived, used to get new access tokens
- Automatic refresh: QuickBooksAuthProvider handles refresh automatically

**Estimate Creation Flow:**
1. Get auth token from custom object
2. Build estimate data from Opportunity
3. Make HTTP POST to QB API
4. Parse response
5. Return estimate ID to Flow/caller
6. Log any errors to Integration_Log__c

---

## Files in Project

```
force-app/main/default/
├── classes/
│   ├── QuickBooksAuthProvider.cls          # OAuth handling
│   ├── QuickBooksEstimateInvocable.cls     # Estimate creation
│   └── [other QB classes]
├── objects/
│   ├── QuickBooks_Auth__c/                 # Token storage
│   └── QuickBooks_Config__mdt/             # Configuration
├── remotesite/
│   ├── QuickBooksAPI                       # QB API domain
│   └── IntuitOAuth                         # OAuth domain
└── flows/
    └── Create_QB_Estimate_From_Opportunity.flow  # Flow (optional)

Root Documentation/
├── E2E_TESTING_START_HERE.md               # Start here!
├── E2E_TEST_GUIDE.md                       # Detailed phases
├── e2e-test-scripts.apex                   # Runnable code
├── QUICKBOOKS_AUTH_SETUP.md                # Auth setup details
├── QUICK_REFERENCE.md                      # This file
└── DEPLOYMENT_TEST_SUMMARY.md              # Deployment report
```

---

## One-Minute Summary

1. **OAuth:** Visit URL → Log in to QB → Click authorize → Tokens saved
2. **Verify:** Run Apex code → Check tokens exist
3. **Test Token:** Get token from storage → Use for API calls
4. **Test API:** Make HTTP GET to QB → Should return 200 OK
5. **Create:** Call invocable → Pass Opportunity → Get estimate ID back

---

## Status Codes Explained

| Code | Meaning | Action |
|------|---------|--------|
| 200 | OK - Success | Continue to next phase |
| 201 | Created | Same as 200 for our purposes |
| 400 | Bad Request | Check request format/data |
| 401 | Unauthorized | Re-run OAuth, check token |
| 403 | Forbidden | Check app permissions |
| 404 | Not Found | Check endpoint URL, company ID |
| 429 | Rate Limited | Wait, then retry |
| 500 | Server Error | QB service issue, retry later |

---

## Time Estimates

| Phase | Time | Manual? |
|-------|------|---------|
| Phase 1: OAuth | 2-3 min | ✅ Yes (browser) |
| Phase 2: Verify | 1 min | ❌ No (copy/paste) |
| Phase 3: Token | 1 min | ❌ No (copy/paste) |
| Phase 4: API Test | 1 min | ❌ No (copy/paste) |
| Phase 5: Estimate | 1 min | ❌ No (copy/paste) |
| **Total** | **6-8 min** | - |

---

## Success Indicators

✅ **You're done when you see:**
```
✓ PHASE 2 PASSED: Tokens stored successfully
✓ PHASE 3 PASSED: Token retrieval works
✓ PHASE 4 PASSED: QB API reachable with valid auth
✓ PHASE 5 PASSED: Estimate created in QB!
✓✓✓ E2E TEST COMPLETE ✓✓✓
```

Then verify in QB:
- Log in to QB
- Find new estimate
- Confirm dates, amount, line items match
- Share success! 🎉
