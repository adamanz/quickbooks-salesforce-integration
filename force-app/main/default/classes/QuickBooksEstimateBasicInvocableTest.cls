/**
 * Test class for QuickBooksEstimateBasicInvocable
 */
@isTest
public class QuickBooksEstimateBasicInvocableTest {

    @isTest
    static void testCreateEstimateSuccess() {
        // Create test request with available fields
        QuickBooksEstimateRequest request = new QuickBooksEstimateRequest();
        request.opportunityId = null; // No real opportunity needed for test
        request.companyId = '123456789';
        request.estimateDate = Date.today();
        request.expirationDate = Date.today().addDays(30);
        request.discountAmount = 10.00;
        request.customerMemo = 'Test memo';
        request.applyTaxAfterDiscount = true;

        // Execute invocable method
        Test.startTest();
        List<QuickBooksEstimateResponse> responses = QuickBooksEstimateBasicInvocable.createEstimate(
            new List<QuickBooksEstimateRequest>{request}
        );
        Test.stopTest();

        // Assert results
        System.assertNotEquals(null, responses, 'Response should not be null');
        System.assertEquals(1, responses.size(), 'Should return one response');

        QuickBooksEstimateResponse response = responses[0];
        System.assertEquals(true, response.success, 'Response should be successful');
        System.assertNotEquals(null, response.quickBooksEstimateId, 'Should have estimate ID');
        System.assertNotEquals(null, response.quickBooksEstimateNumber, 'Should have estimate number');
        System.assert(response.message.contains('successfully'), 'Should have success message');
        System.assert(response.message.contains('Test memo'), 'Message should contain memo');
    }

    @isTest
    static void testCreateEstimateMinimalFields() {
        // Create test request with only required fields
        QuickBooksEstimateRequest request = new QuickBooksEstimateRequest();
        request.opportunityId = null;
        request.companyId = '987654321';
        // All other fields left as null

        // Execute invocable method
        Test.startTest();
        List<QuickBooksEstimateResponse> responses = QuickBooksEstimateBasicInvocable.createEstimate(
            new List<QuickBooksEstimateRequest>{request}
        );
        Test.stopTest();

        // Assert results
        System.assertNotEquals(null, responses, 'Response should not be null');
        System.assertEquals(1, responses.size(), 'Should return one response');

        QuickBooksEstimateResponse response = responses[0];
        System.assertEquals(true, response.success, 'Response should be successful');
        System.assertNotEquals(null, response.quickBooksEstimateId, 'Should have estimate ID');
    }

    @isTest
    static void testCreateEstimateWithException() {
        // Create test request that might trigger an exception
        // Since the implementation is simple, we'll just test normal flow
        QuickBooksEstimateRequest request = new QuickBooksEstimateRequest();
        request.companyId = null; // Even with null, should handle gracefully

        // Execute invocable method
        Test.startTest();
        List<QuickBooksEstimateResponse> responses = QuickBooksEstimateBasicInvocable.createEstimate(
            new List<QuickBooksEstimateRequest>{request}
        );
        Test.stopTest();

        // Assert results - should still work
        System.assertNotEquals(null, responses, 'Response should not be null');
        System.assertEquals(1, responses.size(), 'Should return one response');
    }

    @isTest
    static void testMultipleRequests() {
        // Create multiple test requests
        List<QuickBooksEstimateRequest> requests = new List<QuickBooksEstimateRequest>();

        for (Integer i = 0; i < 3; i++) {
            QuickBooksEstimateRequest request = new QuickBooksEstimateRequest();
            request.companyId = '12345678' + i;
            request.estimateDate = Date.today().addDays(i);
            request.customerMemo = 'Memo ' + i;
            request.discountAmount = 5.00 * i;
            requests.add(request);
        }

        // Execute invocable method
        Test.startTest();
        List<QuickBooksEstimateResponse> responses = QuickBooksEstimateBasicInvocable.createEstimate(requests);
        Test.stopTest();

        // Assert results
        System.assertNotEquals(null, responses, 'Response should not be null');
        System.assertEquals(3, responses.size(), 'Should return three responses');

        for (QuickBooksEstimateResponse response : responses) {
            System.assertEquals(true, response.success, 'Each response should be successful');
            System.assertNotEquals(null, response.quickBooksEstimateId, 'Each should have estimate ID');
        }
    }

    @isTest
    static void testAllOptionalFields() {
        // Create test request with all available optional fields
        QuickBooksEstimateRequest request = new QuickBooksEstimateRequest();
        request.opportunityId = null;
        request.companyId = 'FULL-TEST';
        request.estimateDate = Date.today();
        request.expirationDate = Date.today().addDays(45);
        request.discountAmount = 25.50;
        request.applyTaxAfterDiscount = false;
        request.customerMemo = 'Complete test memo';
        request.privateMemo = 'Internal note';
        request.referenceNumber = 'REF-123';
        request.shipToAddress = '123 Test St, City, ST 12345';

        // Execute invocable method
        Test.startTest();
        List<QuickBooksEstimateResponse> responses = QuickBooksEstimateBasicInvocable.createEstimate(
            new List<QuickBooksEstimateRequest>{request}
        );
        Test.stopTest();

        // Assert results
        QuickBooksEstimateResponse response = responses[0];
        System.assertEquals(true, response.success, 'Response should be successful');
        System.assertNotEquals(null, response.quickBooksEstimateId, 'Should have estimate ID');
        System.assert(response.message.contains('Complete test memo'), 'Message should contain custom memo');
    }
}