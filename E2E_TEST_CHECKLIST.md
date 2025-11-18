# End-to-End Test Checklist

Use this to track your progress through the E2E test.

---

## Pre-Flight Check ✅

Before starting, verify:

- [ ] You can access Salesforce: https://oxycell.lightning.force.com/
- [ ] You have QB sandbox login credentials
- [ ] Developer Console works (avatar → Developer Console)
- [ ] Files exist in your project:
  - [ ] `e2e-test-scripts.apex`
  - [ ] `E2E_TEST_GUIDE.md`
  - [ ] `QUICK_REFERENCE.md`

---

## Phase 1: OAuth Flow (Manual - Browser)

**Time:** 2-3 minutes

- [ ] **Step 1.1:** Open this link in browser:
  ```
  https://oxycell.lightning.force.com/apex/QuickBooksAuthStart
  ```
  - [ ] Confirm you're logged into Salesforce
  - [ ] Confirm page loads without errors

- [ ] **Step 1.2:** QB Login
  - [ ] Redirected to QuickBooks login page
  - [ ] Entered QB sandbox username
  - [ ] Entered QB sandbox password
  - [ ] Clicked "Sign In"

- [ ] **Step 1.3:** Authorization
  - [ ] Saw authorization consent screen
  - [ ] Reviewed permissions (Accounting scope)
  - [ ] Clicked "Authorize" button

- [ ] **Step 1.4:** Success
  - [ ] Redirected back to Salesforce
  - [ ] Saw success message OR no error
  - [ ] Note the QB Company ID from the callback URL or response

---

## Phase 2: Verify Auth Tokens

**Time:** 1 minute
**Location:** Developer Console → Execute Anonymous

- [ ] **Step 2.1:** Copy code
  - [ ] Opened `e2e-test-scripts.apex`
  - [ ] Copied "PHASE 2: VERIFY AUTH TOKENS" section

- [ ] **Step 2.2:** Run code
  - [ ] Opened Developer Console: https://oxycell.lightning.force.com/
  - [ ] Click: Debug → Execute Anonymous
  - [ ] Pasted the code
  - [ ] Clicked "Execute"

- [ ] **Step 2.3:** Check output
  - [ ] Debug tab shows output
  - [ ] Looking for: `✓ Auth token found`
  - [ ] Looking for: `✓ PHASE 2 PASSED`

**Expected Output:**
```
✓ Auth token found
  Company ID: 1234567890
  Token exists: true
  Token length: [some number]
  Active: true
✓ PHASE 2 PASSED: Tokens stored successfully
```

**If failed:**
- [ ] Check error message
- [ ] If "No auth tokens found" → Go back and redo Phase 1
- [ ] See E2E_TEST_GUIDE.md for troubleshooting

---

## Phase 3: Test Token Retrieval

**Time:** 1 minute
**Location:** Developer Console → Execute Anonymous

- [ ] **Step 3.1:** Copy code
  - [ ] Opened `e2e-test-scripts.apex`
  - [ ] Copied "PHASE 3: TEST TOKEN RETRIEVAL" section

- [ ] **Step 3.2:** Run code
  - [ ] Opened Developer Console
  - [ ] Click: Debug → Execute Anonymous
  - [ ] Pasted the code
  - [ ] Clicked "Execute"

- [ ] **Step 3.3:** Check output
  - [ ] Debug tab shows output
  - [ ] Looking for: `✓ Token retrieved successfully`
  - [ ] Looking for: `✓ PHASE 3 PASSED`

**Expected Output:**
```
Using Company ID: 1234567890
✓ Token retrieved successfully
  Token prefix: eyJkb2MiOiJRQk9...
  Token length: [some number]
✓ PHASE 3 PASSED: Token retrieval works
```

**If failed:**
- [ ] Check error message
- [ ] If "Variable does not exist" → Check class deployment
- [ ] See E2E_TEST_GUIDE.md for troubleshooting

---

## Phase 4: Test QB API Reachability

**Time:** 1 minute
**Location:** Developer Console → Execute Anonymous

- [ ] **Step 4.1:** Copy code
  - [ ] Opened `e2e-test-scripts.apex`
  - [ ] Copied "PHASE 4: TEST QB API CALL" section

- [ ] **Step 4.2:** Run code
  - [ ] Opened Developer Console
  - [ ] Click: Debug → Execute Anonymous
  - [ ] Pasted the code
  - [ ] Clicked "Execute"

- [ ] **Step 4.3:** Check output
  - [ ] Debug tab shows output
  - [ ] Looking for: `Response Status: 200 OK`
  - [ ] Looking for: `✓ QB API is accessible`
  - [ ] Looking for: `✓ PHASE 4 PASSED`

**Expected Output:**
```
Calling: GET /v4/customers
Authorization: Bearer eyJkb2MiOiJRQk9...
Response Status: 200 OK
✓ QB API is accessible
✓ Auth token is valid
✓ PHASE 4 PASSED: QB API reachable with valid auth
```

**If failed:**
- [ ] If "401 Unauthorized":
  - [ ] Token may be expired
  - [ ] Try Phase 1 again
- [ ] If "403 Forbidden":
  - [ ] Check QB app permissions
  - [ ] Verify "Accounting" scope selected
- [ ] See E2E_TEST_GUIDE.md for troubleshooting

---

## Phase 5: Create Estimate

**Time:** 1 minute
**Location:** Developer Console → Execute Anonymous

- [ ] **Step 5.1:** Copy code
  - [ ] Opened `e2e-test-scripts.apex`
  - [ ] Copied "PHASE 5: CREATE ESTIMATE" section

- [ ] **Step 5.2:** Run code
  - [ ] Opened Developer Console
  - [ ] Click: Debug → Execute Anonymous
  - [ ] Pasted the code
  - [ ] Clicked "Execute"

- [ ] **Step 5.3:** Check output
  - [ ] Debug tab shows output
  - [ ] Looking for: `Success: true`
  - [ ] Looking for: `QB Estimate ID: [some number]`
  - [ ] Looking for: `✓ PHASE 5 PASSED`
  - [ ] Looking for: `✓✓✓ E2E TEST COMPLETE ✓✓✓`

**Expected Output:**
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
✓✓✓ E2E TEST COMPLETE ✓✓✓
```

**If failed:**
- [ ] Check error message in response
- [ ] If customer error:
  - [ ] QB doesn't have customer for this opportunity
  - [ ] Create customer in QB first
- [ ] See E2E_TEST_GUIDE.md for troubleshooting

---

## Post-Test: Verify in QB

**Time:** 5 minutes

- [ ] **Step 1:** Log into QB
  - [ ] Opened QB Sandbox: https://sandbox.qbo.intuit.com
  - [ ] Logged in with QB credentials

- [ ] **Step 2:** Find the estimate
  - [ ] Click: Sales → Estimates
  - [ ] Find estimate with #: (from Phase 5 output)
  - [ ] Or search for "Adam Smith"

- [ ] **Step 3:** Verify details
  - [ ] [ ] Estimate number matches: ________
  - [ ] [ ] Date: 11/07/2025
  - [ ] [ ] Expiration: 12/07/2025
  - [ ] [ ] Has line items from Opportunity
  - [ ] [ ] Discount: $15,092.00
  - [ ] [ ] Customer/account is correct

- [ ] **Step 4:** Celebrate! 🎉
  - [ ] All details correct
  - [ ] E2E test is successful
  - [ ] Screenshot for documentation (optional)

---

## Summary

- [ ] Phase 1 (OAuth): ✓ COMPLETE
- [ ] Phase 2 (Verify): ✓ PHASE 2 PASSED
- [ ] Phase 3 (Token): ✓ PHASE 3 PASSED
- [ ] Phase 4 (API): ✓ PHASE 4 PASSED
- [ ] Phase 5 (Estimate): ✓ PHASE 5 PASSED
- [ ] QB Verification: ✓ Estimate found and verified

---

## Final Status

**E2E Test Result:** ✅ **SUCCESSFUL**

Date Completed: _______________

Estimate ID in QB: _______________

Notes:
```
[Add any notes about the test here]


```

---

## Troubleshooting Used (if any)

- [ ] Re-ran OAuth (Phase 1)
- [ ] Checked Remote Site Settings
- [ ] Created customer in QB
- [ ] Reviewed debug logs
- [ ] Other: _____________________

---

## Next Steps

After successful E2E test:

- [ ] Test with Production QB credentials (if ready)
- [ ] Deploy to Production Salesforce org (if ready)
- [ ] Set up automated testing/CI (optional)
- [ ] Create end-user documentation (optional)
- [ ] Train team on using the estimate feature (optional)

---

## Sign Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Developer | | | |
| QA/Tester | | | |
| Manager | | | |

---

**Questions?** See E2E_TEST_GUIDE.md or QUICK_REFERENCE.md
