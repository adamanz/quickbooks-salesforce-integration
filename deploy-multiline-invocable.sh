#!/bin/bash

echo "=============================================="
echo "Deploying QuickBooks Multi-Line Invocable"
echo "=============================================="

echo "Target Org: a@simple.company.oxycell (Production)"
echo ""

echo "This deployment includes:"
echo "  - QuickBooksEstimateMultiLineInvocable.cls"
echo "  - QuickBooksEstimateMultiLineInvocableTest.cls"
echo ""
echo "The invocable action supports creating estimates with multiple line items"
echo "similar to the Oxycell estimate format you provided."
echo ""

echo "Starting deployment with test coverage..."
sf project deploy start \
  --source-dir force-app/main/default/classes/QuickBooksEstimateMultiLineInvocable.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateMultiLineInvocable.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksEstimateMultiLineInvocableTest.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateMultiLineInvocableTest.cls-meta.xml \
  --test-level RunSpecifiedTests \
  --tests QuickBooksEstimateMultiLineInvocableTest \
  --target-org a@simple.company.oxycell \
  --wait 10 \
  --verbose

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    echo ""
    echo "The QuickBooksEstimateMultiLineInvocable is now available in your org."
    echo "You can use it in Flows with the label 'Create QuickBooks Multi-Line Estimate'"
    echo ""
    echo "=========================================="
    echo "HOW TO USE IN SALESFORCE FLOWS:"
    echo "=========================================="
    echo ""
    echo "1. Available Input Fields:"
    echo "   - Company ID (required) - QuickBooks Company ID"
    echo "   - Line Items JSON (required) - JSON array of line items"
    echo "   - Customer ID - QuickBooks Customer ID"
    echo "   - Opportunity ID - Salesforce Opportunity ID"
    echo "   - Estimate Date"
    echo "   - Expiration Date"
    echo "   - Discount Amount"
    echo "   - Customer Memo"
    echo "   - Private Memo"
    echo "   - Apply Tax After Discount"
    echo ""
    echo "2. Line Items JSON Format:"
    echo '   [
     {
       "itemId": "ITEM-001",
       "sku": "PROD-SKU-001",
       "description": "Product description",
       "quantity": 10,
       "unitPrice": 100.00,
       "amount": 1000.00
     },
     {
       "itemId": "ITEM-002",
       "description": "Another product",
       "quantity": 5,
       "unitPrice": 200.00,
       "amount": 1000.00
     }
   ]'
    echo ""
    echo "3. The action will:"
    echo "   - Create an estimate with multiple line items"
    echo "   - Apply discounts if specified"
    echo "   - Calculate subtotals and totals"
    echo "   - Return estimate ID and number"
    echo ""
    echo "Note: This is currently a mock implementation for testing."
    echo "To enable actual QuickBooks API integration, you'll need to:"
    echo "  1. Deploy the full QuickBooksAPIService"
    echo "  2. Configure QuickBooks OAuth credentials"
    echo "  3. Update the invocable to call the actual API"
else
    echo ""
    echo "❌ Deployment failed. Please check the error messages above."
    echo ""
    echo "Common issues:"
    echo "  - Missing dependencies (QuickBooksEstimateRequest/Response classes)"
    echo "  - Test coverage requirements"
    echo "  - API version mismatches"
fi