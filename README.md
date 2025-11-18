# QuickBooks-Salesforce Integration for Oxycell

A comprehensive Salesforce integration with QuickBooks Online using Apex, invocable methods for Flow Builder, and OAuth 2.0 authentication.

## Features

### Core Functionality
- **OAuth 2.0 Authentication**: Secure authentication flow with token refresh capabilities
- **Customer Management**: Sync Salesforce Accounts to QuickBooks Customers
- **Invoice Creation**: Automatically create QuickBooks invoices from Opportunities
- **Product/Item Sync**: Sync Products from Salesforce to QuickBooks Items
- **Payment Sync**: Retrieve payment information from QuickBooks
- **Error Handling**: Comprehensive logging and error tracking

### Invocable Flow Actions
All integration features are exposed as invocable actions that can be used in Flow Builder:
- `Create QuickBooks Customer`
- `Create QuickBooks Invoice`
- `Sync QuickBooks Payments`
- `Create QuickBooks Item`

## Architecture

### Components

#### Apex Classes
1. **QuickBooksAuthProvider.cls**
   - Handles OAuth 2.0 authentication flow
   - Manages token storage and refresh
   - Provides secure token retrieval

2. **QuickBooksAPIService.cls**
   - Main service class with invocable methods
   - Handles all API interactions with QuickBooks
   - Implements error handling and logging

3. **QuickBooksAPIServiceTest.cls**
   - Comprehensive unit tests with 80%+ code coverage
   - Mock HTTP callouts for testing

#### Custom Objects
1. **QuickBooks_Auth__c**
   - Stores OAuth tokens securely
   - Fields: Access Token, Refresh Token, Company ID, Token Expiry

2. **Integration_Log__c**
   - Tracks all integration activities and errors
   - Fields: Integration Type, Context, Error Message, Record ID, Timestamp

#### Custom Metadata
1. **QuickBooks_Config__mdt**
   - Stores configuration settings
   - Fields: Client ID, Client Secret, Redirect URI, Is Sandbox

#### Custom Fields on Standard Objects
1. **Account**
   - QuickBooks_Customer_Id__c
   - QuickBooks_Sync_Status__c
   - QuickBooks_Last_Sync__c

2. **Opportunity**
   - QuickBooks_Invoice_Id__c
   - QuickBooks_Invoice_Number__c
   - QuickBooks_Sync_Status__c
   - QuickBooks_Last_Sync__c

3. **Product2**
   - QuickBooks_Item_Id__c
   - QuickBooks_Sync_Status__c
   - Type__c

#### Sample Flows
1. **QuickBooks_Create_Customer_From_Account**
   - Triggered when Account is created/updated
   - Creates QuickBooks customer automatically

2. **QuickBooks_Create_Invoice_From_Opportunity**
   - Triggered when Opportunity is Closed Won
   - Creates invoice with line items in QuickBooks

## Setup Instructions

### Prerequisites
1. QuickBooks Online account (sandbox or production)
2. Salesforce org (Enterprise Edition or higher)
3. Admin access to both systems

### QuickBooks App Setup
1. Go to https://developer.intuit.com
2. Create a new app for QuickBooks Online
3. Configure OAuth 2.0 settings:
   - Add redirect URI: `https://[your-domain].my.salesforce.com/apex/QuickBooksCallback`
   - Select scopes: `com.intuit.quickbooks.accounting`
4. Note down Client ID and Client Secret

### Salesforce Configuration

#### 1. Deploy Components
```bash
# Using Salesforce CLI
sfdx force:source:deploy -p force-app/main/default

# Or using metadata API
sfdx force:mdapi:deploy -d force-app/main/default -w 10
```

#### 2. Configure Custom Metadata
1. Go to Setup → Custom Metadata Types → QuickBooks Config
2. Click "Manage Records" → "New"
3. Enter configuration:
   - Label: Default
   - Client Id: [Your QuickBooks Client ID]
   - Client Secret: [Your QuickBooks Client Secret]
   - Redirect URI: `https://[your-domain].my.salesforce.com/apex/QuickBooksCallback`
   - Is Sandbox: Check for sandbox, uncheck for production

#### 3. Set Remote Site Settings
Add these remote sites in Setup → Remote Site Settings:
1. Name: QuickBooks_Auth
   - URL: https://oauth.platform.intuit.com
2. Name: QuickBooks_API_Sandbox
   - URL: https://sandbox-quickbooks.api.intuit.com
3. Name: QuickBooks_API_Production
   - URL: https://quickbooks.api.intuit.com

#### 4. Configure Named Credentials (Optional - Recommended)
For enhanced security, use Named Credentials instead of storing tokens:
1. Go to Setup → Named Credentials
2. Create new Named Credential for QuickBooks
3. Update Apex classes to use Named Credential

### Authentication Flow
1. Create a Visualforce page for OAuth callback handling
2. Initiate OAuth flow using `QuickBooksAuthProvider.initiateAuthFlow()`
3. Handle callback and store tokens
4. Tokens are automatically refreshed when needed

## Usage Examples

### Flow Builder Usage

#### Creating a Customer from Account
1. Create a new Flow (Record-Triggered)
2. Object: Account
3. Trigger: When Created or Updated
4. Add Action element
5. Search for "Create QuickBooks Customer"
6. Map Account ID and Company ID
7. Handle success/error responses

#### Creating Invoice from Opportunity
1. Create a new Flow (Record-Triggered)
2. Object: Opportunity
3. Trigger: When Updated (Stage = Closed Won)
4. Add Action element
5. Search for "Create QuickBooks Invoice"
6. Map Opportunity ID and Company ID
7. Handle success/error responses

### Apex Usage

```apex
// Create Customer
QuickBooksAPIService.CustomerRequest request = new QuickBooksAPIService.CustomerRequest();
request.accountId = '001XX000003DHPh';
request.companyId = 'YOUR_QB_COMPANY_ID';

List<QuickBooksAPIService.CustomerResponse> responses =
    QuickBooksAPIService.createCustomer(new List<QuickBooksAPIService.CustomerRequest>{request});

if (responses[0].success) {
    System.debug('Customer created: ' + responses[0].quickBooksCustomerId);
} else {
    System.debug('Error: ' + responses[0].message);
}
```

## Error Handling

### Integration Logs
All errors are logged to the `Integration_Log__c` object with:
- Timestamp
- Error message
- Context (operation being performed)
- Related record ID

### Monitoring
1. Create reports on Integration_Log__c for error tracking
2. Set up email alerts for critical errors
3. Monitor QuickBooks_Sync_Status__c fields

## Best Practices

### Data Sync
1. **One-Way Sync**: Initially implement one-way sync (Salesforce → QuickBooks)
2. **Batch Processing**: For large volumes, implement batch processing
3. **Error Recovery**: Implement retry logic for transient errors

### Security
1. **Token Storage**: Use encrypted fields for storing tokens
2. **Named Credentials**: Prefer Named Credentials over custom token storage
3. **Field-Level Security**: Set appropriate FLS for QuickBooks fields
4. **Profile Permissions**: Limit access to integration features

### Performance
1. **Bulk Operations**: Use collection variables in Flows for bulk processing
2. **Async Processing**: Use Platform Events or Queueable for large operations
3. **API Limits**: Monitor QuickBooks API rate limits (500 requests/minute)

## Testing

### Unit Tests
Run all tests:
```apex
// In Developer Console
Run All Tests

// Via CLI
sfdx force:apex:test:run -n QuickBooksAPIServiceTest -r human
```

### Manual Testing
1. Create test Account record
2. Verify QuickBooks customer creation
3. Create Opportunity with products
4. Close Opportunity as Won
5. Verify invoice creation in QuickBooks

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Verify Client ID and Secret
   - Check redirect URI configuration
   - Ensure tokens haven't expired

2. **API Errors**
   - Check QuickBooks company ID
   - Verify required fields are populated
   - Review Integration_Log__c records

3. **Flow Errors**
   - Enable debug logs for Flow
   - Check field mappings
   - Verify user permissions

## API Reference

### QuickBooks API Endpoints
- Customer: `/v3/company/{companyId}/customer`
- Invoice: `/v3/company/{companyId}/invoice`
- Item: `/v3/company/{companyId}/item`
- Payment: `/v3/company/{companyId}/payment`

### Rate Limits
- 500 requests per minute for QuickBooks Online
- Implement exponential backoff for rate limit errors

## Support and Maintenance

### Monitoring Checklist
- [ ] Daily: Check Integration_Log__c for errors
- [ ] Weekly: Review sync status reports
- [ ] Monthly: Audit token refresh logs
- [ ] Quarterly: Review and update field mappings

### Version History
- v1.0.0 - Initial release with core functionality
  - OAuth 2.0 authentication
  - Customer and Invoice sync
  - Invocable Flow actions

## License
Proprietary - Oxycell Internal Use Only

## Contact
For support or questions, contact the Oxycell development team.