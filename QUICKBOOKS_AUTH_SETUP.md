# QuickBooks Authentication Setup Guide

This guide walks you through setting up OAuth 2.0 authentication with QuickBooks Online in your Salesforce org.

## Overview

The QuickBooks integration uses OAuth 2.0 to securely authenticate with QuickBooks Online API. The authentication flow:

1. **User initiates auth** → Salesforce redirects to QuickBooks login
2. **User authenticates with QB** → QB generates authorization code
3. **Code exchange** → Salesforce exchanges code for access/refresh tokens
4. **Token storage** → Tokens saved securely in `QuickBooks_Auth__c` object
5. **API calls** → Salesforce uses access token for QB API requests
6. **Token refresh** → When token expires, refresh token automatically gets new access token

## Prerequisites

Before starting, you need:
- QuickBooks Online account (production or sandbox)
- Intuit Developer Account at https://developer.intuit.com
- Salesforce org with `QuickBooks_Config__mdt` and `QuickBooks_Auth__c` objects deployed
- Your Salesforce org URL (e.g., `https://oxycell.lightning.force.com`)

## Step 1: Create QuickBooks App in Intuit Developer Portal

### 1.1 Go to Intuit Developer Portal
- Visit https://developer.intuit.com/app/developer/myapps
- Sign in with your Intuit Developer account (create one if needed)

### 1.2 Create New App
- Click "Create an app"
- Select "QuickBooks Online" (not QuickBooks Desktop)
- Select "Web" as your app type
- Provide an app name (e.g., "Salesforce QB Integration")
- Click "Create app"

### 1.3 Get Your Credentials
Once the app is created, you'll see:
- **Client ID** - Copy this
- **Client Secret** - Copy this (keep this secret!)
- **Redirect URI** - We'll configure this next

### 1.4 Configure Redirect URI
QuickBooks will redirect here after user authenticates:

**For sandbox environment:**
```
https://YOUR_ORG_DOMAIN.sandbox.my.salesforce.com/apex/QuickBooksAuthCallback
```

**For production environment:**
```
https://YOUR_ORG_DOMAIN.my.salesforce.com/apex/QuickBooksAuthCallback
```

Example:
```
https://oxycell.my.salesforce.com/apex/QuickBooksAuthCallback
```

In your Intuit app settings:
1. Click "Keys & credentials"
2. Add your Redirect URI in the "Redirect URIs" section
3. Save changes

## Step 2: Create Custom Metadata Config in Salesforce

Now you'll create the configuration record that stores your QB credentials.

### 2.1 Navigate to Custom Metadata
In Salesforce:
1. Setup → Custom Code → Custom Metadata Types
2. Find "QuickBooks Config"
3. Click "Manage Records"
4. Click "New"

### 2.2 Fill in the Configuration

| Field | Value |
|-------|-------|
| **Label** | Default |
| **Client_Id__c** | [Paste your Client ID from Intuit] |
| **Client_Secret__c** | [Paste your Client Secret from Intuit] |
| **Redirect_URI__c** | `https://oxycell.my.salesforce.com/apex/QuickBooksAuthCallback` |
| **Is_Sandbox__c** | ☑️ Check if using QB Sandbox, uncheck for production |
| **Webhook_Verifier_Token__c** | [Leave empty for now, only needed for webhooks] |

### 2.3 Save the Configuration
- Click "Save"
- Note the DeveloperName must be "Default" (case-sensitive)

## Step 3: Create Authentication Page in Salesforce

You need a Visualforce page to initiate the auth flow. If not already created, deploy:

**File: `force-app/main/default/pages/QuickBooksAuthCallback.page`**

```xml
<apex:page controller="QuickBooksOAuthController" standardStylesheets="false">
    <apex:form>
        <apex:pageMessages />
    </apex:form>
</apex:page>
```

**File: `force-app/main/default/pages/QuickBooksAuthStart.page`**

```xml
<apex:page controller="QuickBooksOAuthController" action="{!startAuth}">
    <h1>Initiating QuickBooks Authentication...</h1>
</apex:page>
```

## Step 4: Deploy Apex Classes

The authentication classes are already in your codebase:

- **QuickBooksAuthProvider.cls** - Handles OAuth flow, token exchange, and refresh
- **QuickBooksOAuthController.cls** - Page controller for auth flow

Deploy these files to ensure they're in sync with your config.

## Step 5: Initiate Authentication Flow

There are two ways to authenticate:

### Method A: Using Apex Code
```apex
// In a batch, scheduled action, or anonymous script
PageReference authPage = QuickBooksAuthProvider.initiateAuthFlow();
if (authPage != null) {
    System.debug('Auth URL: ' + authPage.getUrl());
    // User would navigate to this URL
}
```

### Method B: Using Visualforce Page
1. In Salesforce, navigate to your site URL with the auth page:
   ```
   https://oxycell.lightning.force.com/apex/QuickBooksAuthStart
   ```
2. This will redirect to QuickBooks login
3. User logs in with their QB account
4. QuickBooks redirects back to your callback page with authorization code
5. The callback handler automatically exchanges code for tokens

## Step 6: Verify Token Storage

After authentication completes:

1. Setup → Custom Objects and Fields → QuickBooks Auth
2. Click the QuickBooks Auth tab or list view
3. You should see a new record with:
   - **Account_Id__c** - Your QB company ID (RealmId)
   - **Access_Token__c** - Active bearer token
   - **Refresh_Token__c** - Token for refreshing access
   - **Token_Expiry__c** - Timestamp when access token expires

**Important:** Do NOT expose these tokens in UI or logs. They're sensitive credentials.

## Step 7: Test Token Retrieval

Run this in Anonymous Apex to verify your setup:

```apex
// Test getting valid access token
String token = QuickBooksAuthProvider.getValidAccessToken('YOUR_COMPANY_ID');
System.debug('Token obtained: ' + (token != null ? 'SUCCESS' : 'FAILED'));
System.debug('Token length: ' + (token != null ? token.length() : 0));
```

Where `YOUR_COMPANY_ID` is your QuickBooks Realm ID (usually 12 digits).

## Step 8: Troubleshooting

### Error: "Invalid redirect URI"
- ✓ Verify Redirect URI exactly matches in Intuit app settings
- ✓ Check for trailing slashes or case differences
- ✓ Ensure it includes the Apex page name

### Error: "Invalid client credentials"
- ✓ Verify Client ID and Secret match exactly in Custom Metadata
- ✓ No extra spaces before/after values
- ✓ Check if credentials need URL encoding

### Error: "Token refresh failed"
- ✓ Verify QuickBooks_Auth__c record exists with valid refresh token
- ✓ Check if refresh token has expired (QB tokens are short-lived)
- ✓ Re-run authentication flow to generate new tokens

### Error: "Invalid company ID"
- ✓ Verify Company ID (RealmId) is stored in QuickBooks_Auth__c
- ✓ Ensure you're using the correct QB Sandbox/Production environment

## Step 9: Security Best Practices

1. **Never hardcode credentials** - Always use Custom Metadata Type
2. **Use HTTPS only** - All QB API calls must be over HTTPS
3. **Encrypt sensitive fields** - Mark token fields as encrypted in SFDC
4. **Rotate secrets regularly** - Regenerate Client Secret periodically
5. **Audit token usage** - Log all API calls in Integration_Log__c
6. **Limit scope** - Only request necessary QB permissions in OAuth scope
7. **Handle token expiry** - Token refresh happens automatically; verify in logs

## Step 10: Enable API Integration Class

Add your QB API service class (QuickBooksAPIService.cls) to authorized classes:

1. Setup → Custom Code → Remote Site Settings
2. Click "New Remote Site"
3. **Remote Site Name:** QuickBooks API
4. **Remote Site URL:** `https://quickbooks.api.intuit.com` (production) or `https://sandbox-quickbooks.api.intuit.com` (sandbox)
5. **Disable Protocol Security:** Unchecked
6. **Save**

Repeat for OAuth endpoint:
- **Remote Site Name:** Intuit OAuth
- **Remote Site URL:** `https://oauth.platform.intuit.com`

## Next Steps

Once authentication is complete:

1. Test API calls using QuickBooksAPIService methods
2. Create invocable actions in Flow (e.g., "Create QB Estimate")
3. Set up webhook handlers for QB notifications
4. Configure scheduled sync jobs for data consistency

## Reference Documentation

- Intuit OAuth 2.0: https://developer.intuit.com/app/developer/qbo/docs/develop/authentication-and-authorization/oauth-2.0
- QB API Endpoints: https://developer.intuit.com/app/developer/qbo/docs/api/accounting-api-reference
- Salesforce Remote Site Settings: https://help.salesforce.com/s/articleView?id=sf.integrate_remote_site_settings.htm
