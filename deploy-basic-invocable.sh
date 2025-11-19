#!/bin/bash

echo "=============================================="
echo "Deploying QuickBooks Basic Invocable"
echo "=============================================="

echo "Target Org: a@simple.company.oxycell (Production)"
echo ""

echo "Deploying QuickBooksEstimateBasicInvocable with test coverage..."
sf project deploy start \
  --source-dir force-app/main/default/classes/QuickBooksEstimateBasicInvocable.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateBasicInvocable.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksEstimateBasicInvocableTest.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateBasicInvocableTest.cls-meta.xml \
  --test-level RunSpecifiedTests \
  --tests QuickBooksEstimateBasicInvocableTest \
  --target-org a@simple.company.oxycell \
  --wait 10 \
  --verbose

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    echo ""
    echo "The QuickBooksEstimateBasicInvocable is now available in your org."
    echo "You can use it in Flows with the label 'Create QuickBooks Estimate (Basic)'"
    echo ""
    echo "Available input fields:"
    echo "- Company ID (required)"
    echo "- Opportunity ID (required)"
    echo "- Estimate Date"
    echo "- Expiration Date"
    echo "- Discount Amount"
    echo "- Customer Memo"
    echo "- Apply Tax After Discount"
    echo ""
    echo "Note: This is a basic mock implementation for testing."
    echo "To enable actual QuickBooks API integration, additional components need to be deployed."
else
    echo ""
    echo "❌ Deployment failed. Please check the error messages above."
fi