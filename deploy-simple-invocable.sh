#!/bin/bash

echo "======================================"
echo "Deploying QuickBooks Simple Invocable"
echo "======================================"

echo "Target Org: a@simple.company.oxycell"
echo ""

# Deploy the simple invocable class with its own test for coverage
echo "Deploying QuickBooksEstimateSimpleInvocable with test coverage..."
sf project deploy start \
  --source-dir force-app/main/default/classes/QuickBooksEstimateSimpleInvocable.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateSimpleInvocable.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksEstimateSimpleInvocableTest.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateSimpleInvocableTest.cls-meta.xml \
  --test-level RunSpecifiedTests \
  --tests QuickBooksEstimateSimpleInvocableTest \
  --target-org a@simple.company.oxycell \
  --wait 30 \
  --verbose

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    echo ""
    echo "Next steps:"
    echo "1. The QuickBooksEstimateSimpleInvocable is now available in your org"
    echo "2. You can use it in Flows with the label 'Create QuickBooks Estimate (Simple)'"
    echo "3. Required inputs: Company ID, Customer ID, and Amount"
    echo "4. Optional inputs: Customer Memo and Opportunity ID"
else
    echo ""
    echo "❌ Deployment failed. Please check the error messages above."
fi