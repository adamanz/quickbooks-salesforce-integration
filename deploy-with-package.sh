#!/bin/bash

echo "=================================================="
echo "QuickBooks Estimate Deployment using package.xml"
echo "=================================================="
echo ""
echo "This deployment uses package.xml with RunSpecifiedTests"
echo "Running only QuickBooksEstimateInvocableTest"
echo ""

# Method 1: Using sf project deploy with manifest
echo "Method 1: Using sf project deploy with manifest"
echo "------------------------------------------------"
sf project deploy start \
  --manifest manifest/package.xml \
  --test-level RunSpecifiedTests \
  --tests QuickBooksEstimateInvocableTest \
  --target-org a@simple.company.oxycell \
  --wait 30

# Check if first method failed
if [ $? -ne 0 ]; then
    echo ""
    echo "Method 1 failed. Trying Method 2..."
    echo ""

    # Method 2: Using metadata API deploy
    echo "Method 2: Using metadata API deploy"
    echo "------------------------------------"

    # First, convert source to metadata format
    echo "Converting source to metadata format..."
    sf project convert source \
      --source-dir force-app/main/default/classes \
      --source-dir force-app/main/default/flows \
      --output-dir mdapi-deploy

    # Deploy using metadata API
    echo "Deploying using metadata API..."
    sf project deploy start \
      --metadata-dir mdapi-deploy \
      --test-level RunSpecifiedTests \
      --tests QuickBooksEstimateInvocableTest \
      --target-org a@simple.company.oxycell \
      --wait 30
fi

echo ""
echo "=================================================="
echo "Deployment Complete"
echo "=================================================="