#!/bin/bash

echo "=========================================="
echo "Deploying Missing QuickBooks Classes"
echo "=========================================="

echo "Target Org: a@simple.company.oxycell"
echo ""

# First deploy QuickBooksEstimateLineItem (dependency for others)
echo "1. Deploying QuickBooksEstimateLineItem..."
sf project deploy start \
  --source-dir force-app/main/default/classes/QuickBooksEstimateLineItem.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateLineItem.cls-meta.xml \
  --test-level NoTestRun \
  --target-org a@simple.company.oxycell \
  --wait 10

if [ $? -ne 0 ]; then
    echo "❌ Failed to deploy QuickBooksEstimateLineItem"
    exit 1
fi

# Deploy QuickBooksEstimateTestHelper
echo ""
echo "2. Deploying QuickBooksEstimateTestHelper..."
sf project deploy start \
  --source-dir force-app/main/default/classes/QuickBooksEstimateTestHelper.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateTestHelper.cls-meta.xml \
  --test-level NoTestRun \
  --target-org a@simple.company.oxycell \
  --wait 10

if [ $? -ne 0 ]; then
    echo "❌ Failed to deploy QuickBooksEstimateTestHelper"
    exit 1
fi

# Deploy QuickBooksEstimateSimpleInvocable
echo ""
echo "3. Deploying QuickBooksEstimateSimpleInvocable..."
sf project deploy start \
  --source-dir force-app/main/default/classes/QuickBooksEstimateSimpleInvocable.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateSimpleInvocable.cls-meta.xml \
  --test-level NoTestRun \
  --target-org a@simple.company.oxycell \
  --wait 10

if [ $? -ne 0 ]; then
    echo "❌ Failed to deploy QuickBooksEstimateSimpleInvocable"
    exit 1
fi

# Finally deploy the test class
echo ""
echo "4. Deploying QuickBooksEstimateSimpleInvocableTest..."
sf project deploy start \
  --source-dir force-app/main/default/classes/QuickBooksEstimateSimpleInvocableTest.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateSimpleInvocableTest.cls-meta.xml \
  --test-level NoTestRun \
  --target-org a@simple.company.oxycell \
  --wait 10

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ All components deployed successfully!"
    echo ""
    echo "Components deployed:"
    echo "- QuickBooksEstimateLineItem"
    echo "- QuickBooksEstimateTestHelper"
    echo "- QuickBooksEstimateSimpleInvocable"
    echo "- QuickBooksEstimateSimpleInvocableTest"
else
    echo "❌ Failed to deploy QuickBooksEstimateSimpleInvocableTest"
fi