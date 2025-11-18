# END-TO-END TESTING: START HERE ⚡

**Status:** Ready to test authentication & QB API

---

## Quick Summary

You have 2 things to do:

### 1️⃣ MANUAL: Complete OAuth Flow (5 minutes)
```
Visit: https://oxycell.lightning.force.com/apex/QuickBooksAuthStart
1. Log in to QuickBooks
2. Click "Authorize"
3. Done - system saves tokens automatically
```

### 2️⃣ AUTOMATED: Run Test Scripts (5 minutes)
Copy & paste Apex code from `e2e-test-scripts.apex` into:
- Setup → Developer Console → Execute Anonymous
- Or: Setup → Developer Console → Query Editor → Execute

---

## Current Status

**Checked ✓:**
- QB Config in Salesforce: ✓ Found
- Opportunity data: ✓ Accessible
- Apex classes: ✓ Deployed

**Not Done Yet:**
- QB Authorization: ❌ No tokens yet (need Phase 1)
- API Test: ❌ Waiting for Phase 1

---

## The 5-Phase End-to-End Test

### Phase 1: OAuth Flow (YOU DO THIS - Browser)
**Time:** 2-3 minutes
**Action:** Click link, log into QB, click authorize
**Result:** Tokens saved to Salesforce automatically
**Next:** Go to Phase 2

---

### Phase 2: Verify Tokens (AUTOMATED - Copy/Paste Apex)
**Time:** 1 minute
**Code Location:** First section of `e2e-test-scripts.apex`
**Expected Result:**
```
✓ Auth token found
✓ PHASE 2 PASSED
```
**Next:** Go to Phase 3

---

### Phase 3: Test Token Retrieval (AUTOMATED - Copy/Paste Apex)
**Time:** 1 minute
**Code Location:** Second section of `e2e-test-scripts.apex`
**Expected Result:**
```
✓ Token retrieved successfully
✓ PHASE 3 PASSED
```
**Next:** Go to Phase 4

---

### Phase 4: Test QB API Reachability (AUTOMATED - Copy/Paste Apex)
**Time:** 1 minute
**Code Location:** Third section of `e2e-test-scripts.apex`
**Expected Result:**
```
Response Status: 200 OK
✓ QB API is accessible
✓ PHASE 4 PASSED
```
**Next:** Go to Phase 5

---

### Phase 5: Create Estimate (AUTOMATED - Copy/Paste Apex)
**Time:** 1 minute
**Code Location:** Fourth section of `e2e-test-scripts.apex`
**Expected Result:**
```
Success: true
QB Estimate ID: 31
QB Estimate #: 0000031
✓ PHASE 5 PASSED
✓✓✓ E2E TEST COMPLETE ✓✓✓
```

---

## HOW TO RUN PHASES 2-5

### Method 1: Developer Console (Easiest)
1. Login to Salesforce
2. Click your avatar → Developer Console
3. Click "Debug" → "Execute Anonymous"
4. Paste code from `e2e-test-scripts.apex`
5. Click "Execute"
6. Check "Debug" tab for output

### Method 2: VS Code (If you use Salesforce Extensions)
1. Open the code in VS Code
2. Right-click → SFDX: Execute Anonymous Apex
3. Check output

---

## File Locations & Docs

| File | Purpose |
|------|---------|
| `E2E_TESTING_START_HERE.md` | This quick start guide |
| `E2E_TEST_GUIDE.md` | Detailed phase-by-phase instructions |
| `e2e-test-scripts.apex` | Copy/paste Apex code for phases 2-5 |
| `QUICKBOOKS_AUTH_SETUP.md` | How authentication works |
| `DEPLOYMENT_TEST_SUMMARY.md` | Deployment status report |

---

## Troubleshooting Quick Ref

| Error | Fix |
|-------|-----|
| "No auth tokens found" | Complete Phase 1 - visit OAuth URL |
| "401 Unauthorized" | Phase 1 failed - re-run OAuth flow |
| "QB API not accessible" | Check remote site settings in Salesforce |
| "Company ID invalid" | Use QB Company ID from auth record, not example ID |

---

## What Gets Tested

✅ **Authentication**
- OAuth 2.0 flow with QB
- Token storage in Salesforce
- Token retrieval and use

✅ **API Integration**
- HTTP callouts to QB sandbox
- Bearer token authentication
- Estimate creation endpoint
- Error handling

✅ **Salesforce Integration**
- Opportunity data access
- Custom metadata config
- Invocable Apex methods
- Error logging

✅ **End Result**
- **QB Estimate created** with:
  - Estimate Date: 11/07/2025
  - Expiration: 12/07/2025
  - Discount: $15,092
  - For: Adam Smith opportunity
  - Line items: From opportunity products

---

## What Happens in Each Phase

### Phase 1: OAuth
```
Browser → QB Login → QB Authorization → Code Exchange → Token Storage
```

### Phase 2: Verify
```
SOQL Query → Check QuickBooks_Auth__c record exists
```

### Phase 3: Retrieve
```
Call QuickBooksAuthProvider.getValidAccessToken() → Return token
```

### Phase 4: API Test
```
HTTP GET request → /v4/customers → QB API → 200 OK response
```

### Phase 5: Create Estimate
```
Build estimate data → HTTP POST → /v3/company/{id}/estimate → Estimate created
```

---

## Success Criteria

You've successfully completed the E2E test when you see:

```
✓ PHASE 2 PASSED: Tokens stored successfully
✓ PHASE 3 PASSED: Token retrieval works
✓ PHASE 4 PASSED: QB API reachable with valid auth
✓ PHASE 5 PASSED: Estimate created in QB!
✓✓✓ E2E TEST COMPLETE ✓✓✓
```

---

## Next: After E2E Test

Once all phases pass:

1. ✅ Log into QB Online
2. ✅ Verify new estimate exists
3. ✅ Check estimate details match test data
4. ✅ Share success with team
5. ✅ Move to production OAuth credentials

---

## Need Help?

1. **Check debug logs:** Setup → Logs → Debug Logs
2. **Check Integration Logs:** Look for Integration_Log__c records
3. **Read full guide:** See `E2E_TEST_GUIDE.md` for detailed troubleshooting

---

## Ready? Let's Go! 🚀

**Next Step:** Click this link and log in to QB:
```
https://oxycell.lightning.force.com/apex/QuickBooksAuthStart
```

Then come back here and run Phase 2 code.
