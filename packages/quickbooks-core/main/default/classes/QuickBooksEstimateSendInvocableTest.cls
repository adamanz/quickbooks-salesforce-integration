@isTest
public class QuickBooksEstimateSendInvocableTest {
    
    @TestSetup
    static void setup() {
        // Create Auth record
        QuickBooksTestDataFactory.createTestAuth('123456789', 'token', 'refresh', true);
    }

    @isTest
    static void testSendEstimate() {
        Test.setMock(HttpCalloutMock.class, new QuickBooksMockCallout());
        
        QuickBooksEstimateSendInvocable.SendEstimateRequest req = new QuickBooksEstimateSendInvocable.SendEstimateRequest();
        req.companyId = '123456789';
        req.estimateId = '100';
        req.emailAddress = 'test@example.com';
        
        Test.startTest();
        List<QuickBooksEstimateSendInvocable.SendEstimateResponse> responses = 
            QuickBooksEstimateSendInvocable.sendEstimate(new List<QuickBooksEstimateSendInvocable.SendEstimateRequest>{req});
        Test.stopTest();
        
        System.assertEquals(1, responses.size(), 'Should have 1 response');
        System.assertEquals(true, responses[0].success, 'Should be successful');
        System.assert(responses[0].message.contains('Estimate sent successfully'), 'Message should indicate success');
    }

    @isTest
    static void testSendEstimateError() {
        // Force error with 400 Bad Request
        Test.setMock(HttpCalloutMock.class, new QuickBooksMockCallout(400, '{"Fault":{"Error":[{"Message":"Invalid email"}]}}'));
        
        QuickBooksEstimateSendInvocable.SendEstimateRequest req = new QuickBooksEstimateSendInvocable.SendEstimateRequest();
        req.companyId = '123456789';
        req.estimateId = '100';
        
        Test.startTest();
        List<QuickBooksEstimateSendInvocable.SendEstimateResponse> responses = 
            QuickBooksEstimateSendInvocable.sendEstimate(new List<QuickBooksEstimateSendInvocable.SendEstimateRequest>{req});
        Test.stopTest();
        
        System.assertEquals(1, responses.size(), 'Should have 1 response');
        System.assertEquals(false, responses[0].success, 'Should handle error');
        System.assert(responses[0].message.contains('Invalid email'), 'Message should contain API error');
    }
}
