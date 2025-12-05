@isTest
private class QuickBooksAttachmentInvocableTest {

    @isTest
    static void testUploadAttachment() {
        // 1. Setup Mock
        Test.setMock(HttpCalloutMock.class, new QuickBooksMockCallout());
        
        // 2. Insert Mock Auth Record
        QuickBooks_Auth__c auth = new QuickBooks_Auth__c(
            Company_Id__c = '123456789',
            Access_Token__c = 'mock_access_token',
            Refresh_Token__c = 'mock_refresh_token',
            Token_Expiry__c = DateTime.now().addHours(1),
            Expires_In__c = 3600,
            Is_Active__c = true
        );
        insert auth;

        // 3. Create Test File
        ContentVersion cv = new ContentVersion(
            Title = 'Test Document',
            PathOnClient = 'TestDocument.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;
        
        // Re-query to get the ID
        cv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id];

        // 4. Setup Request
        QuickBooksAttachmentInvocable.AttachmentRequest req = new QuickBooksAttachmentInvocable.AttachmentRequest();
        req.companyId = '123456789';
        req.quickBooksRecordId = '100';
        req.quickBooksRecordType = 'Estimate';
        req.contentVersionId = cv.Id;
        
        List<QuickBooksAttachmentInvocable.AttachmentRequest> requests = new List<QuickBooksAttachmentInvocable.AttachmentRequest>{req};
        
        // 5. Execute
        Test.startTest();
        List<QuickBooksAttachmentInvocable.AttachmentResponse> responses = QuickBooksAttachmentInvocable.uploadAttachment(requests);
        Test.stopTest();
        
        // 6. Verify
        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assertEquals(true, responses[0].success, 'Should succeed: ' + responses[0].message);
    }
}

