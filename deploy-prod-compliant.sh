#!/bin/bash

echo "=============================================="
echo "Production Deployment - QuickBooks Estimate"
echo "=============================================="

echo "Target Org: a@simple.company.oxycell (Production)"
echo ""

echo "Deploying all QuickBooks Estimate components with test coverage..."
echo "This will use RunLocalTests for production compliance."
echo ""

sf project deploy start \
  --source-dir force-app/main/default/classes/QuickBooksEstimateLineItem.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateLineItem.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksEstimateTestHelper.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateTestHelper.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksEstimateSimpleInvocable.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateSimpleInvocable.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksEstimateSimpleInvocableTest.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateSimpleInvocableTest.cls-meta.xml \
  --test-level RunLocalTests \
  --target-org a@simple.company.oxycell \
  --wait 30

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    echo ""
    echo "Components deployed:"
    echo "- QuickBooksEstimateLineItem (data model class)"
    echo "- QuickBooksEstimateTestHelper (test utilities)"
    echo "- QuickBooksEstimateSimpleInvocable (invocable action for Flows)"
    echo "- QuickBooksEstimateSimpleInvocableTest (test coverage)"
    echo ""
    echo "The QuickBooksEstimateSimpleInvocable is now available for use in Flows."
    echo "Look for 'Create QuickBooks Estimate (Simple)' in the Flow builder."
else
    echo ""
    echo "❌ Deployment failed."
    echo ""
    echo "Note: Production deployments require 75% code coverage."
    echo "If the deployment failed due to coverage, you may need to:"
    echo "1. Add more test methods to increase coverage"
    echo "2. Fix any failing tests in the org"
    echo "3. Use RunSpecifiedTests with tests that provide coverage"
fi