// Update QuickBooks Configuration with Webhook Verifier Token
// Run this script after setting up the webhook in QuickBooks

// Update the existing configuration
QuickBooks_Config__mdt config = [
    SELECT Id, DeveloperName, MasterLabel
    FROM QuickBooks_Config__mdt
    WHERE DeveloperName = 'Default'
    LIMIT 1
];

if (config != null) {
    // Create metadata update
    Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
    customMetadata.fullName = 'QuickBooks_Config__mdt.Default';
    customMetadata.label = 'Default Configuration';

    // Add Webhook Verifier Token
    Metadata.CustomMetadataValue verifierTokenField = new Metadata.CustomMetadataValue();
    verifierTokenField.field = 'Webhook_Verifier_Token__c';
    // Webhook verifier token from QuickBooks Developer Portal
    verifierTokenField.value = '84914756-c24b-4e4a-8bda-84db13845e73';
    customMetadata.values.add(verifierTokenField);

    // Keep existing fields
    Metadata.CustomMetadataValue clientIdField = new Metadata.CustomMetadataValue();
    clientIdField.field = 'Client_Id__c';
    clientIdField.value = 'ABVXMjcDNzYm3f969avshDh9lXGB1kkAwLiDP2hpSIFBcKRmJZ';
    customMetadata.values.add(clientIdField);

    Metadata.CustomMetadataValue clientSecretField = new Metadata.CustomMetadataValue();
    clientSecretField.field = 'Client_Secret__c';
    clientSecretField.value = 'LvDScfQyE0VPOAgTh5P6EzRnw2D06OxkdLk04DM5';
    customMetadata.values.add(clientSecretField);

    Metadata.CustomMetadataValue redirectUriField = new Metadata.CustomMetadataValue();
    redirectUriField.field = 'Redirect_URI__c';
    String baseUrl = URL.getOrgDomainUrl().toExternalForm();
    redirectUriField.value = baseUrl + '/apex/qboOAuthRedirect';
    customMetadata.values.add(redirectUriField);

    Metadata.CustomMetadataValue isSandboxField = new Metadata.CustomMetadataValue();
    isSandboxField.field = 'Is_Sandbox__c';
    isSandboxField.value = true;
    customMetadata.values.add(isSandboxField);

    // Deploy the metadata
    Metadata.DeployContainer container = new Metadata.DeployContainer();
    container.addMetadata(customMetadata);

    Id jobId = Metadata.Operations.enqueueDeployment(container, null);

    System.debug('Webhook configuration updated. Job ID: ' + jobId);
    System.debug('Remember to replace YOUR_WEBHOOK_VERIFIER_TOKEN_HERE with actual token');
} else {
    System.debug('No configuration found. Please run setupQuickBooksConfig.apex first');
}