// Create QuickBooks Configuration Metadata Record
// This script sets up the initial configuration for QuickBooks integration

// First, check if a default config already exists
List<QuickBooks_Config__mdt> existingConfigs = [
    SELECT Id, DeveloperName, MasterLabel
    FROM QuickBooks_Config__mdt
    WHERE DeveloperName = 'Default'
];

if (!existingConfigs.isEmpty()) {
    System.debug('Default QuickBooks configuration already exists. Skipping creation.');
} else {
    // Create the metadata record using Metadata API
    Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
    customMetadata.fullName = 'QuickBooks_Config__mdt.Default';
    customMetadata.label = 'Default Configuration';

    // Add Client ID field
    Metadata.CustomMetadataValue clientIdField = new Metadata.CustomMetadataValue();
    clientIdField.field = 'Client_Id__c';
    clientIdField.value = 'ABVXMjcDNzYm3f969avshDh9lXGB1kkAwLiDP2hpSIFBcKRmJZ';
    customMetadata.values.add(clientIdField);

    // Add Client Secret field
    Metadata.CustomMetadataValue clientSecretField = new Metadata.CustomMetadataValue();
    clientSecretField.field = 'Client_Secret__c';
    clientSecretField.value = 'LvDScfQyE0VPOAgTh5P6EzRnw2D06OxkdLk04DM5';
    customMetadata.values.add(clientSecretField);

    // Add Redirect URI field - using the Visualforce page we created
    Metadata.CustomMetadataValue redirectUriField = new Metadata.CustomMetadataValue();
    redirectUriField.field = 'Redirect_URI__c';
    // Build the redirect URI dynamically based on the org
    String baseUrl = URL.getOrgDomainUrl().toExternalForm();
    redirectUriField.value = baseUrl + '/apex/qboOAuthRedirect';
    customMetadata.values.add(redirectUriField);

    // Add Is Sandbox field (using sandbox for testing)
    Metadata.CustomMetadataValue isSandboxField = new Metadata.CustomMetadataValue();
    isSandboxField.field = 'Is_Sandbox__c';
    isSandboxField.value = true; // Set to true for testing with QuickBooks sandbox
    customMetadata.values.add(isSandboxField);

    // Deploy the metadata
    Metadata.DeployContainer container = new Metadata.DeployContainer();
    container.addMetadata(customMetadata);

    // Create callback
    Id jobId = Metadata.Operations.enqueueDeployment(container, null);

    System.debug('QuickBooks configuration metadata deployment initiated. Job ID: ' + jobId);
    System.debug('Redirect URI will be: ' + baseUrl + '/apex/qboOAuthRedirect');
    System.debug('Client ID: ABVXMjcDNzYm3f969avshDh9lXGB1kkAwLiDP2hpSIFBcKRmJZ');
}

// Also create a sample QuickBooks_Auth__c record for testing if needed
List<QuickBooks_Auth__c> existingAuth = [
    SELECT Id FROM QuickBooks_Auth__c LIMIT 1
];

if (existingAuth.isEmpty()) {
    System.debug('No existing QuickBooks Auth records found. Ready for OAuth flow.');
} else {
    System.debug('Existing QuickBooks Auth record found: ' + existingAuth[0].Id);
}