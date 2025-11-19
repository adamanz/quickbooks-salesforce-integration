#!/bin/bash

# QuickBooks Estimate Feature Deployment Script
# This script deploys the QuickBooks Estimate feature with specific test coverage

echo "=================================================="
echo "QuickBooks Estimate Feature Deployment"
echo "=================================================="

# Configuration
ORG_ALIAS="a@simple.company.oxycell"
DEPLOY_DIR="force-app/main/default"

# Test classes to run (only run QuickBooks-related tests)
TEST_CLASSES="QuickBooksEstimateInvocableTest,QuickBooksAPIServiceTest,QuickBooksOAuthControllerTest,QuickBooksWebhookHandlerTest,QuickBooksSyncQueueableTest"

echo ""
echo "🎯 Target Org: $ORG_ALIAS"
echo "📁 Deploy Directory: $DEPLOY_DIR"
echo ""

# Option 1: Deploy with specific test classes (recommended for production)
echo "Option 1: Deploy with specific test classes"
echo "-------------------------------------------"
echo "Running deployment with specified tests..."
echo ""

sf project deploy start \
  --source-dir "$DEPLOY_DIR/classes/QuickBooksEstimateInvocable.cls" \
  --source-dir "$DEPLOY_DIR/classes/QuickBooksEstimateInvocable.cls-meta.xml" \
  --source-dir "$DEPLOY_DIR/classes/QuickBooksEstimateInvocableTest.cls" \
  --source-dir "$DEPLOY_DIR/classes/QuickBooksEstimateInvocableTest.cls-meta.xml" \
  --source-dir "$DEPLOY_DIR/classes/QuickBooksEstimateLineItem.cls" \
  --source-dir "$DEPLOY_DIR/classes/QuickBooksEstimateLineItem.cls-meta.xml" \
  --source-dir "$DEPLOY_DIR/classes/QuickBooksEstimateRequest.cls" \
  --source-dir "$DEPLOY_DIR/classes/QuickBooksEstimateRequest.cls-meta.xml" \
  --source-dir "$DEPLOY_DIR/classes/QuickBooksEstimateResponse.cls" \
  --source-dir "$DEPLOY_DIR/classes/QuickBooksEstimateResponse.cls-meta.xml" \
  --source-dir "$DEPLOY_DIR/classes/QuickBooksEstimateTestHelper.cls" \
  --source-dir "$DEPLOY_DIR/classes/QuickBooksEstimateTestHelper.cls-meta.xml" \
  --source-dir "$DEPLOY_DIR/flows/QuickBooks_Create_MultiLine_Estimate.flow-meta.xml" \
  --test-level RunSpecifiedTests \
  --tests $TEST_CLASSES \
  --target-org $ORG_ALIAS \
  --wait 30

# Check deployment status
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    echo ""
    echo "Next steps:"
    echo "1. Navigate to Setup > Process Automation > Flows"
    echo "2. Open 'QuickBooks Multi-Line Estimate Creator'"
    echo "3. Click 'Run' to test the flow manually"
else
    echo ""
    echo "❌ Deployment failed. Please check the error messages above."
    echo ""
    echo "Troubleshooting options:"
    echo ""
    echo "Option 2: Deploy to sandbox first (no test requirement)"
    echo "-------------------------------------------"
    echo "sf project deploy start \\"
    echo "  --source-dir $DEPLOY_DIR/classes/QuickBooksEstimate*.cls \\"
    echo "  --source-dir $DEPLOY_DIR/flows/QuickBooks_Create_MultiLine_Estimate.flow-meta.xml \\"
    echo "  --test-level NoTestRun \\"
    echo "  --target-org your-sandbox-alias"
    echo ""
    echo "Option 3: Validate deployment without saving (dry run)"
    echo "-------------------------------------------"
    echo "sf project deploy start \\"
    echo "  --source-dir $DEPLOY_DIR/classes/QuickBooksEstimate*.cls \\"
    echo "  --source-dir $DEPLOY_DIR/flows/QuickBooks_Create_MultiLine_Estimate.flow-meta.xml \\"
    echo "  --test-level RunLocalTests \\"
    echo "  --target-org $ORG_ALIAS \\"
    echo "  --dry-run"
fi