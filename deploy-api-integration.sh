#!/bin/bash

echo "=============================================="
echo "Deploying QuickBooks API Integration"
echo "=============================================="

echo "Target Org: a@simple.company.oxycell (Production)"
echo ""

echo "This deployment includes:"
echo "  - QuickBooksAPIService (with createEstimate method)"
echo "  - QuickBooksAuthProvider (OAuth handling)"
echo "  - Updated QuickBooksEstimateMultiLineInvocable"
echo "  - Supporting classes and tests"
echo ""

echo "Starting deployment with minimal test coverage..."

# Deploy core API classes and OAuth components
sf project deploy start \
  --source-dir force-app/main/default/classes/QuickBooksAPIService.cls \
  --source-dir force-app/main/default/classes/QuickBooksAPIService.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksAPIServiceTest.cls \
  --source-dir force-app/main/default/classes/QuickBooksAPIServiceTest.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksAuthProvider.cls \
  --source-dir force-app/main/default/classes/QuickBooksAuthProvider.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksAuthProviderTest.cls \
  --source-dir force-app/main/default/classes/QuickBooksAuthProviderTest.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksAuthHelper.cls \
  --source-dir force-app/main/default/classes/QuickBooksAuthHelper.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksAuthHelperTest.cls \
  --source-dir force-app/main/default/classes/QuickBooksAuthHelperTest.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksOAuthController.cls \
  --source-dir force-app/main/default/classes/QuickBooksOAuthController.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksOAuthControllerTest.cls \
  --source-dir force-app/main/default/classes/QuickBooksOAuthControllerTest.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksEstimateMultiLineInvocable.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateMultiLineInvocable.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksEstimateMultiLineInvocableTest.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateMultiLineInvocableTest.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksLogger.cls \
  --source-dir force-app/main/default/classes/QuickBooksLogger.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksLoggerTest.cls \
  --source-dir force-app/main/default/classes/QuickBooksLoggerTest.cls-meta.xml \
  --test-level RunLocalTests \
  --target-org a@simple.company.oxycell \
  --wait 10 \
  --verbose

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    echo ""
    echo "=========================================="
    echo "NEXT STEPS TO ENABLE REAL API CALLS:"
    echo "=========================================="
    echo ""
    echo "1. Configure OAuth in Salesforce:"
    echo "   - Go to Setup > Named Credentials"
    echo "   - Create a new Named Credential for QuickBooks"
    echo "   - Use the Client ID and Secret from your .env file:"
    echo "     - Production Client ID: See .env file"
    echo "     - Production Client Secret: See .env file"
    echo ""
    echo "2. Set up QuickBooks OAuth:"
    echo "   - Create/update QuickBooks_OAuth__c custom setting"
    echo "   - Store the access token and refresh token"
    echo "   - Set the Company ID: 9341452808602382"
    echo ""
    echo "3. Authorize the connection:"
    echo "   - Navigate to the QuickBooks OAuth page in your Salesforce org"
    echo "   - Click 'Connect to QuickBooks'"
    echo "   - Authorize the app in QuickBooks"
    echo ""
    echo "4. Test the integration:"
    echo "   - Run your Flow with the multi-line estimate"
    echo "   - Check if real QuickBooks IDs are returned (not MLEST- prefixed)"
    echo "   - Verify the estimate appears in QuickBooks"
    echo ""
    echo "The QuickBooksEstimateMultiLineInvocable is now configured to:"
    echo "  - Try the real API first (QuickBooksAPIService.createEstimate)"
    echo "  - Fall back to mock data if the API call fails"
    echo "  - Support all line items and discounts from your Flow"
else
    echo ""
    echo "❌ Deployment failed. Please check the error messages above."
    echo ""
    echo "Common issues:"
    echo "  - Missing dependencies"
    echo "  - Test coverage requirements"
    echo "  - Check if QuickBooksCustomerResponse and other DTOs are deployed"
fi