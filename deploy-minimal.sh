#!/bin/bash

# Minimal QuickBooks Estimate Deployment
# Runs only the QuickBooksEstimateInvocableTest to minimize test execution time

echo "=================================================="
echo "Minimal QuickBooks Estimate Deployment"
echo "=================================================="
echo ""
echo "This deployment runs ONLY the QuickBooksEstimateInvocableTest"
echo "to minimize deployment time while meeting coverage requirements."
echo ""

# Deploy with only the estimate test class
sf project deploy start \
  --source-dir force-app/main/default/classes/QuickBooksEstimateInvocable.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateInvocableTest.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateLineItem.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateRequest.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateResponse.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateTestHelper.cls \
  --source-dir force-app/main/default/flows/QuickBooks_Create_MultiLine_Estimate.flow-meta.xml \
  --test-level RunSpecifiedTests \
  --tests QuickBooksEstimateInvocableTest \
  --target-org a@simple.company.oxycell \
  --wait 30 \
  --verbose

echo ""
echo "=================================================="
echo "Deployment Complete"
echo "=================================================="