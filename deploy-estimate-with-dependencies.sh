#!/bin/bash

echo "=========================================="
echo "Deploying QuickBooks Estimate Components"
echo "=========================================="

echo "Target Org: a@simple.company.oxycell"
echo ""

# Deploy all estimate-related components including dependencies
echo "Deploying QuickBooks Estimate components with dependencies..."
sf project deploy start \
  --source-dir force-app/main/default/classes/QuickBooksEstimateLineItem.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateLineItem.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksEstimateSimpleInvocable.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateSimpleInvocable.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksEstimateSimpleInvocableTest.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateSimpleInvocableTest.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksEstimateTestHelper.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateTestHelper.cls-meta.xml \
  --test-level RunSpecifiedTests \
  --tests QuickBooksEstimateSimpleInvocableTest \
  --target-org a@simple.company.oxycell \
  --wait 30 \
  --verbose

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    echo ""
    echo "Components deployed:"
    echo "- QuickBooksEstimateLineItem (data model)"
    echo "- QuickBooksEstimateTestHelper (test utilities)"
    echo "- QuickBooksEstimateSimpleInvocable (invocable action)"
    echo "- QuickBooksEstimateSimpleInvocableTest (test coverage)"
    echo ""
    echo "Next steps:"
    echo "1. The QuickBooksEstimateSimpleInvocable is now available in your org"
    echo "2. You can use it in Flows with the label 'Create QuickBooks Estimate (Simple)'"
    echo "3. Required inputs: Company ID and Customer Ref"
    echo "4. Optional: Line Items JSON, Customer Details, Discounts, Addresses"
else
    echo ""
    echo "❌ Deployment failed. Please check the error messages above."
fi