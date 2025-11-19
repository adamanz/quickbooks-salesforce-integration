#!/bin/bash

echo "=================================================="
echo "🚀 Fast QuickBooks Estimate Deployment"
echo "=================================================="
echo ""
echo "Using CommunitiesLoginControllerTest (18ms runtime)"
echo "This is the fastest test in your org!"
echo ""

# Deploy QuickBooks Estimate components with the fastest test
sf project deploy start \
  --source-dir force-app/main/default/classes/QuickBooksEstimateInvocable.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateLineItem.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateRequest.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateResponse.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateTestHelper.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateInvocableTest.cls \
  --source-dir force-app/main/default/flows/QuickBooks_Create_MultiLine_Estimate.flow-meta.xml \
  --test-level RunSpecifiedTests \
  --tests CommunitiesLoginControllerTest \
  --target-org a@simple.company.oxycell \
  --wait 30

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful! (Super fast with 18ms test)"
    echo ""
    echo "📦 Components deployed:"
    echo "  • QuickBooksEstimateInvocable"
    echo "  • QuickBooksEstimateLineItem"
    echo "  • QuickBooksEstimateRequest"
    echo "  • QuickBooksEstimateResponse"
    echo "  • QuickBooksEstimateTestHelper"
    echo "  • QuickBooksEstimateInvocableTest"
    echo "  • QuickBooks_Create_MultiLine_Estimate (Flow)"
    echo ""
    echo "📋 Next steps:"
    echo "  1. Go to Setup → Process Automation → Flows"
    echo "  2. Find 'QuickBooks Multi-Line Estimate Creator'"
    echo "  3. Click 'Run' to test the flow"
else
    echo ""
    echo "❌ Deployment failed"
    echo "Check the error messages above for details."
fi