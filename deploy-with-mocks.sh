#!/bin/bash

echo "======================================"
echo "Deploying QuickBooks Integration with Test Mocks"
echo "======================================"
echo ""
echo "Target Org: a@simple.company.oxycell (Production)"
echo ""

echo "This deployment includes:"
echo "  - QuickBooksMockCallout (HTTP mock for tests)"
echo "  - Updated test classes with mock support"
echo "  - QuickBooks API Service"
echo "  - Multi-line estimate invocable"
echo ""

echo "Deploying with comprehensive test coverage..."

# Deploy all classes including the mock
sf project deploy start \
  --source-dir force-app/main/default/classes/QuickBooksMockCallout.cls \
  --source-dir force-app/main/default/classes/QuickBooksMockCallout.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksAPIService.cls \
  --source-dir force-app/main/default/classes/QuickBooksAPIService.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksAPIServiceTest.cls \
  --source-dir force-app/main/default/classes/QuickBooksAPIServiceTest.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksEstimateMultiLineInvocable.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateMultiLineInvocable.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksEstimateMultiLineInvocableTest.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateMultiLineInvocableTest.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksAuthProvider.cls \
  --source-dir force-app/main/default/classes/QuickBooksAuthProvider.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksAuthProviderTest.cls \
  --source-dir force-app/main/default/classes/QuickBooksAuthProviderTest.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksAuthHelper.cls \
  --source-dir force-app/main/default/classes/QuickBooksAuthHelper.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksAuthHelperTest.cls \
  --source-dir force-app/main/default/classes/QuickBooksAuthHelperTest.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksEstimateRequest.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateRequest.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksEstimateResponse.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateResponse.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksEstimateLineItem.cls \
  --source-dir force-app/main/default/classes/QuickBooksEstimateLineItem.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksCustomerRequest.cls \
  --source-dir force-app/main/default/classes/QuickBooksCustomerRequest.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksCustomerResponse.cls \
  --source-dir force-app/main/default/classes/QuickBooksCustomerResponse.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksInvoiceRequest.cls \
  --source-dir force-app/main/default/classes/QuickBooksInvoiceRequest.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksInvoiceResponse.cls \
  --source-dir force-app/main/default/classes/QuickBooksInvoiceResponse.cls-meta.xml \
  --source-dir force-app/main/default/classes/QuickBooksTestDataFactory.cls \
  --source-dir force-app/main/default/classes/QuickBooksTestDataFactory.cls-meta.xml \
  --test-level RunLocalTests \
  --target-org a@simple.company.oxycell \
  --wait 10 \
  --verbose

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    echo ""
    echo "======================================"
    echo "QuickBooks Integration is Ready!"
    echo "======================================"
    echo ""
    echo "The integration now includes:"
    echo "  ✓ Proper HTTP mocking for tests"
    echo "  ✓ Multi-line estimate support"
    echo "  ✓ Real API connectivity (when OAuth configured)"
    echo "  ✓ Automatic fallback to mock data if API fails"
    echo ""
    echo "To use the real QuickBooks API:"
    echo "  1. Ensure OAuth tokens are set up in QuickBooks_Auth__c"
    echo "  2. Set Company ID: 9341452808602382"
    echo "  3. Run your Flow - it will attempt real API first"
    echo ""
    echo "The test classes now use QuickBooksMockCallout to:"
    echo "  - Prevent real API calls during tests"
    echo "  - Provide consistent test responses"
    echo "  - Ensure tests pass reliably"
else
    echo ""
    echo "❌ Deployment failed. Please check the error messages above."
    echo ""
    echo "Common issues:"
    echo "  - Missing dependencies (DTOs, helper classes)"
    echo "  - Test coverage below 75%"
    echo "  - Check that all referenced classes exist"
fi