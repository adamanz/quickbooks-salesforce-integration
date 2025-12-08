# Demo Script: Lead to Quote in 60 Seconds

## Opening (10 seconds)

"Let me show you how we've eliminated the back-and-forth between sales and accounting. What used to take 15-20 minutes now happens in under a minute - and we're open sourcing the tools that make this possible."

---

## Demo (60 seconds)

"Here's a new lead that just came in - John Smith, interested in our flagship product.

I click **Send Quote**, select the product from the dropdown, and hit Submit.

*[Click through the flow]*

That's it. Here's what just happened automatically:

1. The lead converted to an Account, Contact, and Opportunity
2. A customer was created in QuickBooks
3. A professional estimate with all line items and the correct discount was generated
4. The quote was emailed directly to the customer

*[Show QuickBooks estimate or email]*

No copying data between systems. No manual calculations. No waiting for accounting to send the quote."

---

## Open Source Components (30 seconds)

"The best part? We're open sourcing the building blocks that make this work:

**salesforce-quickbooks-integration**
The core integration - OAuth, API service, and Flow-ready invocable actions for customers, estimates, invoices, and payments.

**salesforce-lead-converter**
A simple invocable action that converts leads with full control - specify the Account, Contact, and Opportunity names right from Flow Builder.

Both are available on GitHub. Fork them, customize them, use them in your own projects."

---

## Close (20 seconds)

"Sales stays in Salesforce. Accounting stays in QuickBooks. The customer gets their quote in seconds instead of hours.

Check out the repos, give them a star, and let us know what you build.

Questions?"

---

## Key Talking Points (if needed)

- **Eliminates data entry errors** - No more typos or copy-paste mistakes
- **Quotes go out faster** - Higher close rates when you respond in minutes
- **Full audit trail** - Every transaction synced between both systems
- **Works on mobile** - Sales reps can send quotes from anywhere
- **Open source** - Customize to fit your business, contribute improvements back

---

## GitHub Repositories

| Repository | Description | Link |
|------------|-------------|------|
| `salesforce-quickbooks-integration` | QuickBooks Online API integration for Salesforce - OAuth, Customers, Estimates, Invoices, Payments | `packages/salesforce-quickbooks-integration` |
| `salesforce-lead-converter` | Flow-ready Lead conversion with custom naming | `packages/salesforce-lead-converter` |

### What's Included

**salesforce-quickbooks-integration:**
- `QuickBooksAPIService.cls` - Core API integration (648 lines)
- `QuickBooksAuthProvider.cls` - OAuth token management with auto-refresh
- `QuickBooksCustomerInvocable.cls` - Flow action for customer sync
- `QuickBooksEstimateMultiLineInvocable.cls` - Multi-line estimate creation
- `QuickBooksEstimateSendInvocable.cls` - Email estimates directly
- `QuickBooksInvoiceInvocable.cls` - Invoice creation from Opportunities
- Custom Objects: `QuickBooks_Auth__c`, `QuickBooks_Config__mdt`, `Integration_Log__c`
- Custom Fields on Account, Opportunity, Product2

**salesforce-lead-converter:**
- `LeadConverterInvocable.cls` - Single-action lead conversion for Flow Builder
- Supports custom naming for Account, Contact, and Opportunity

---

## Technical Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Salesforce Flow                          │
│  Lead Quote Screen → Lead Converter → QB Customer → QB Estimate │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Invocable Actions                            │
│  LeadConverterInvocable │ QuickBooksCustomerInvocable │ ...     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    QuickBooksAPIService                         │
│  OAuth Token Management │ API Calls │ Error Handling            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    QuickBooks Online API                        │
│  Customers │ Estimates │ Invoices │ Payments │ Attachments      │
└─────────────────────────────────────────────────────────────────┘
```
