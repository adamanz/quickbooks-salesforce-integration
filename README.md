# QuickBooks-Salesforce Integration

[![Salesforce Package](https://img.shields.io/badge/Salesforce-Unlocked%20Package-00A1E0?logo=salesforce)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tfo000001FYIXAA4)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Code Coverage](https://img.shields.io/badge/Code%20Coverage-78%25-brightgreen)](https://github.com/adamanz/quickbooks-salesforce-integration)

A complete Salesforce integration with QuickBooks Online using OAuth 2.0 authentication and Flow-compatible invocable actions.

## Installation

### One-Click Install (Production)

[![Install in Production](https://img.shields.io/badge/Install%20in-Production-blue?logo=salesforce)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tfo000001FYIXAA4)

### One-Click Install (Sandbox)

[![Install in Sandbox](https://img.shields.io/badge/Install%20in-Sandbox-orange?logo=salesforce)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tfo000001FYIXAA4)

### Manual Install via CLI

```bash
sf package install --package 04tfo000001FYIXAA4 --target-org YOUR_ORG_ALIAS --wait 10
```

## Features

- **OAuth 2.0 Authentication**: Secure token-based authentication with automatic refresh
- **Customer Sync**: Create and sync customers between Salesforce Accounts and QuickBooks
- **Estimates**: Create estimates with single or multiple line items
- **Invoices**: Generate invoices from Opportunities
- **Payments**: Track and record payments
- **Flow Actions**: All functionality available as invocable actions for use in Flows
- **Webhook Support**: Real-time sync via QuickBooks webhooks
- **Logging**: Comprehensive integration logging for troubleshooting

## Components

### Custom Objects

| Object | Description |
|--------|-------------|
| `QuickBooks_Auth__c` | Stores OAuth tokens and credentials |
| `QuickBooks_OAuth__c` | OAuth state management |
| `QuickBooks_Config__mdt` | Custom metadata for configuration |
| `Estimate__c` | QuickBooks estimates |
| `Invoice__c` | QuickBooks invoices |
| `Payment__c` | QuickBooks payments |
| `Integration_Log__c` | Integration audit logs |

### Custom Fields on Standard Objects

**Account**
- `QuickBooks_Customer_Id__c` - QuickBooks Customer ID
- `QuickBooks_Sync_Status__c` - Sync status
- `QuickBooks_Last_Sync__c` - Last sync timestamp

**Opportunity**
- `QuickBooks_Estimate_Id__c` / `QuickBooks_Estimate_Number__c` - Estimate references
- `QuickBooks_Invoice_Id__c` / `QuickBooks_Invoice_Number__c` - Invoice references
- `QuickBooks_Sync_Status__c` / `QuickBooks_Last_Sync__c` - Sync tracking

**Product2**
- `QuickBooks_Item_Id__c` - QuickBooks Item/Product ID
- `QuickBooks_Sync_Status__c` - Sync status

### Invocable Actions (for Flows)

| Action | Description |
|--------|-------------|
| `QuickBooksCustomerInvocable` | Create/sync customers |
| `QuickBooksEstimateInvocable` | Create single-line estimates |
| `QuickBooksEstimateMultiLineInvocable` | Create multi-line estimates |
| `QuickBooksEstimateSendInvocable` | Email estimates to customers |
| `QuickBooksInvoiceInvocable` | Create invoices |
| `QuickBooksSyncQueueable` | Async sync operations |
| `QuickBooksAttachmentInvocable` | Attach files to QuickBooks entities |

## Setup

### 1. QuickBooks Developer Setup

1. Go to [QuickBooks Developer Portal](https://developer.intuit.com/)
2. Create an app and get your Client ID and Client Secret
3. Set the OAuth redirect URI to your Salesforce site URL + `/services/apexrest/quickbooks/oauth/callback`

### 2. Salesforce Configuration

1. Install the package using the links above
2. Assign the `QuickBooks_Integration_Access` permission set to integration users
3. Create a Custom Metadata record for `QuickBooks_Config__mdt` with your credentials
4. Configure Remote Site Settings (included in package):
   - IntuitOAuth
   - QuickBooksProductionAPI
   - QuickBooksSandboxAPI

### 3. Connect Your QuickBooks Account

Navigate to the QuickBooksAuthStart Visualforce page to initiate the OAuth flow.

## Usage Examples

### Create Customer from Account (Flow)

Use the `QuickBooksCustomerInvocable` action in your Flow:
- Input: Account record
- Output: QuickBooks Customer ID

### Create Multi-Line Estimate (Flow)

Use the `QuickBooksEstimateMultiLineInvocable` action:
- Input: Account ID, Line Items JSON, Customer Email
- Output: Estimate ID, Estimate Number

### Line Items JSON Format

```json
[
  {
    "itemId": "123",
    "quantity": 1,
    "amount": 1500.00,
    "description": "Product Description"
  },
  {
    "itemId": "456",
    "quantity": 2,
    "amount": 500.00,
    "description": "Another Product"
  }
]
```

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Salesforce    │────▶│  QuickBooks API  │────▶│   QuickBooks    │
│   (Flows/Apex)  │◀────│   Service Layer  │◀────│     Online      │
└─────────────────┘     └──────────────────┘     └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌──────────────────┐
│ Custom Objects  │     │   OAuth 2.0      │
│ (Estimates,     │     │   Token Mgmt     │
│  Invoices, etc) │     └──────────────────┘
└─────────────────┘
```

## Security

- All OAuth tokens are stored encrypted in Salesforce
- Automatic token refresh before expiration
- Field-level security via Permission Sets
- No hardcoded credentials - all configuration via Custom Metadata

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- Create an issue on GitHub for bugs or feature requests
- Check the Integration_Log__c object for troubleshooting

---

**Package Version**: 0.1.0.1
**Subscriber Package Version ID**: `04tfo000001FYIXAA4`
