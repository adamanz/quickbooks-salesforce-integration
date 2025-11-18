# QuickBooks-Salesforce Integration Setup Guide for Oxycell

## Your QuickBooks Credentials

You have received the following credentials from QuickBooks:
- **Client ID**: `ABUE22i50hgL5RvR49RvqhWEPqnLSUBsLHyLzgXiHEF9jA0pmI`
- **Client Secret**: `yDFTOE93WVLxqMm7QqWjcXBiAV8YP2pfanqXxtmH`

**IMPORTANT**: Keep these credentials secure and never commit them to version control.

## Step 1: Deploy to Salesforce

### Deploy using Salesforce CLI
```bash
# Login to your Salesforce org
sfdx auth:web:login -a oxycell-org

# Deploy the integration package
sfdx force:source:deploy -p force-app -u oxycell-org

# Assign permissions
sfdx force:user:permset:assign -n QuickBooksIntegrationUser -u oxycell-org
```

## Step 2: Configure Remote Sites

In Salesforce Setup → Security → Remote Site Settings, add:

1. **QuickBooks OAuth**
   - Remote Site Name: `QuickBooks_OAuth`
   - Remote Site URL: `https://oauth.platform.intuit.com`
   - Active: ✓

2. **QuickBooks API Sandbox** (for testing)
   - Remote Site Name: `QuickBooks_API_Sandbox`
   - Remote Site URL: `https://sandbox-quickbooks.api.intuit.com`
   - Active: ✓

3. **QuickBooks API Production** (for live data)
   - Remote Site Name: `QuickBooks_API_Production`
   - Remote Site URL: `https://quickbooks.api.intuit.com`
   - Active: ✓

## Step 3: Configure Custom Metadata

1. Go to Setup → Custom Metadata Types → QuickBooks Config
2. Click "Manage Records" → "New"
3. Enter the following configuration:

   **For Development/Testing (Sandbox):**
   - Label: `Default`
   - DeveloperName: `Default`
   - Client Id: `ABUE22i50hgL5RvR49RvqhWEPqnLSUBsLHyLzgXiHEF9jA0pmI`
   - Client Secret: `yDFTOE93WVLxqMm7QqWjcXBiAV8YP2pfanqXxtmH`
   - Redirect URI: `https://[your-domain].my.salesforce.com/apex/QuickBooksCallback`
   - Is Sandbox: ✓ (checked for sandbox, unchecked for production)
   - Webhook Verifier Token: (will be generated in QuickBooks later)

   Replace `[your-domain]` with your actual Salesforce domain.

## Step 4: QuickBooks App Configuration

1. Go to https://developer.intuit.com
2. Sign in and go to "My Apps"
3. Create a new app or select existing app
4. Configure the following:

### OAuth 2.0 Settings
In the "Keys & credentials" section:
- Add these Redirect URIs:
  ```
  https://[your-domain].my.salesforce.com/apex/QuickBooksCallback
  https://[your-domain].lightning.force.com/apex/QuickBooksCallback
  ```

### Webhook Configuration (for real-time sync)

1. Go to the "Webhooks" section
2. Enter Webhook URL:
   ```
   https://[your-domain].my.salesforce.com/services/apexrest/quickbooks/webhook
   ```
3. Select events to subscribe to:
   - **Customer**: Create, Update, Delete
   - **Invoice**: Create, Update, Delete, Void
   - **Payment**: Create, Update, Delete
   - **Item**: Create, Update, Delete
   - **SalesReceipt**: Create, Update
   - **Estimate**: Create, Update

4. Copy the "Verifier Token" and update it in Salesforce Custom Metadata

## Step 5: Create OAuth Callback Page

Create a simple Visualforce page to handle OAuth callback:

1. Go to Setup → Visualforce Pages → New
2. Name: `QuickBooksCallback`
3. Code:
```apex
<apex:page controller="QuickBooksCallbackController" action="{!handleCallback}">
    <apex:pageMessages />
    <div style="text-align: center; padding: 50px;">
        <h1>QuickBooks Authorization</h1>
        <apex:outputPanel rendered="{!isSuccess}">
            <p style="color: green;">✓ Successfully connected to QuickBooks!</p>
            <p>You can now close this window.</p>
        </apex:outputPanel>
        <apex:outputPanel rendered="{!NOT(isSuccess)}">
            <p style="color: red;">✗ Authorization failed. Please try again.</p>
        </apex:outputPanel>
    </div>
</apex:page>
```

## Step 6: Create Callback Controller

```apex
public with sharing class QuickBooksCallbackController {
    public Boolean isSuccess { get; set; }

    public PageReference handleCallback() {
        isSuccess = false;

        String code = ApexPages.currentPage().getParameters().get('code');
        String realmId = ApexPages.currentPage().getParameters().get('realmId');

        if (String.isNotBlank(code) && String.isNotBlank(realmId)) {
            isSuccess = QuickBooksAuthProvider.handleCallback(code, realmId);
        }

        return null;
    }
}
```

## Step 7: Activate Flows

1. Go to Setup → Flows
2. Activate these flows:
   - **QuickBooks - Create Customer From Account**
   - **QuickBooks - Create Invoice From Opportunity**

## Step 8: Initial Authorization

1. Execute this in Anonymous Apex to start OAuth flow:
```apex
PageReference authPage = QuickBooksAuthProvider.initiateAuthFlow();
System.debug('Go to this URL: ' + authPage.getUrl());
```

2. Navigate to the URL in your browser
3. Log in to QuickBooks and authorize the app
4. You'll be redirected back to Salesforce

## Step 9: Test the Integration

### Test Customer Creation
```apex
// Create a test Account
Account testAccount = new Account(
    Name = 'Test Company from Salesforce',
    BillingStreet = '123 Test Street',
    BillingCity = 'San Francisco',
    BillingState = 'CA',
    BillingPostalCode = '94105',
    Phone = '415-555-0100'
);
insert testAccount;

// The Flow will automatically create a QuickBooks customer
// Check the Account after a few seconds:
Account result = [SELECT QuickBooks_Customer_Id__c, QuickBooks_Sync_Status__c
                  FROM Account WHERE Id = :testAccount.Id];
System.debug('QB Customer ID: ' + result.QuickBooks_Customer_Id__c);
System.debug('Sync Status: ' + result.QuickBooks_Sync_Status__c);
```

### Test Invoice Creation
```apex
// Create and close an Opportunity
Opportunity opp = new Opportunity(
    Name = 'Test Sale',
    AccountId = testAccount.Id,
    StageName = 'Closed Won',
    CloseDate = Date.today(),
    Amount = 1000.00
);
insert opp;

// Check for invoice creation
Opportunity result = [SELECT QuickBooks_Invoice_Id__c, QuickBooks_Invoice_Number__c
                      FROM Opportunity WHERE Id = :opp.Id];
System.debug('QB Invoice ID: ' + result.QuickBooks_Invoice_Id__c);
System.debug('QB Invoice Number: ' + result.QuickBooks_Invoice_Number__c);
```

## Step 10: Monitor Integration

### Check Integration Logs
```soql
SELECT Id, Context__c, Error_Message__c, Timestamp__c
FROM Integration_Log__c
ORDER BY Timestamp__c DESC
LIMIT 10
```

### View Sync Status
Create reports on:
- Accounts with `QuickBooks_Sync_Status__c != 'Synced'`
- Opportunities with `QuickBooks_Sync_Status__c = 'Error'`

## Webhook Testing

To test webhooks:
1. In QuickBooks Developer Dashboard, use "Send Test Notification"
2. Check Salesforce Debug Logs for webhook processing
3. Verify data updates in Salesforce records

## Troubleshooting

### Common Issues and Solutions

1. **"Invalid client" error**
   - Verify Client ID and Secret are correct in Custom Metadata
   - Ensure you're using the right environment (sandbox vs production)

2. **"Redirect URI mismatch"**
   - Check that redirect URIs in QuickBooks exactly match Salesforce URLs
   - Include both .my.salesforce.com and .lightning.force.com versions

3. **Webhook signature verification fails**
   - Copy the Verifier Token from QuickBooks Webhooks section
   - Update it in Salesforce Custom Metadata

4. **No QuickBooks customer/invoice created**
   - Check if Flows are activated
   - Review debug logs for errors
   - Verify Remote Site Settings are active

## Security Best Practices

1. **Never hardcode credentials** - Always use Custom Metadata or Custom Settings
2. **Use Named Credentials** when possible for enhanced security
3. **Implement IP restrictions** in QuickBooks app settings
4. **Regular token rotation** - Refresh tokens periodically
5. **Monitor Integration Logs** for suspicious activity

## Support Resources

- QuickBooks API Documentation: https://developer.intuit.com/app/developer/qbo/docs/api/accounting/all-entities/account
- Salesforce Flow Documentation: https://help.salesforce.com/articleView?id=flow.htm
- Integration Logs: Check `Integration_Log__c` object for errors

## Next Steps

1. **Set up monitoring dashboards** for sync status
2. **Create error handling flows** for failed syncs
3. **Implement batch sync** for initial data migration
4. **Add more entity types** (Bills, Vendors, etc.) as needed
5. **Configure field mappings** for custom fields

## Contact

For questions or issues with this integration, contact the Oxycell development team.