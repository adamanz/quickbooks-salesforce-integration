/**
 * Test class for QuickBooksEstimateSimpleInvocable
 * Provides comprehensive test coverage for the simplified invocable action
 */
@isTest
public class QuickBooksEstimateSimpleInvocableTest {

    @isTest
    static void testCreateEstimateWithLineItems() {
        // Create test request with line items
        QuickBooksEstimateRequest request = new QuickBooksEstimateRequest();
        request.opportunityId = null; // No real opportunity needed for mock
        request.companyId = '123456789';
        request.customerRef = '3';
        request.customerName = 'Test Customer';
        request.customerMemo = 'Thank you for your business!';
        request.estimateDate = Date.today();
        request.expirationDate = Date.today().addDays(30);

        // Create line items JSON
        List<QuickBooksEstimateLineItem> lineItems = new List<QuickBooksEstimateLineItem>();
        lineItems.add(new QuickBooksEstimateLineItem('Pest Control Service', 1, 35.00, '10'));
        lineItems.add(new QuickBooksEstimateLineItem('Lawn Care Service', 2, 25.00, '11'));
        request.lineItemsJson = JSON.serialize(lineItems);

        request.discountPercent = 10;
        request.applyTaxAfterDiscount = false;

        // Execute invocable method
        Test.startTest();
        List<QuickBooksEstimateResponse> responses = QuickBooksEstimateSimpleInvocable.createEstimate(
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
    }

    @isTest
    static void testCreateEstimateWithoutLineItems() {
        // Create test request without line items JSON
        QuickBooksEstimateRequest request = new QuickBooksEstimateRequest();
        request.companyId = '123456789';
        request.customerRef = '3';
        request.customerName = 'Simple Customer';
        request.customerMemo = 'Basic estimate';

        // Execute invocable method
        Test.startTest();
        List<QuickBooksEstimateResponse> responses = QuickBooksEstimateSimpleInvocable.createEstimate(
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
    static void testCreateEstimateWithDiscount() {
        // Create test request with discount
        QuickBooksEstimateRequest request = new QuickBooksEstimateRequest();
        request.companyId = '123456789';
        request.customerRef = '5';
        request.customerName = 'Discount Customer';

        // Create line item with discount
        List<QuickBooksEstimateLineItem> lineItems = new List<QuickBooksEstimateLineItem>();
        lineItems.add(new QuickBooksEstimateLineItem('Service', 1, 100.00, '1'));
        request.lineItemsJson = JSON.serialize(lineItems);

        request.discountPercent = 15;
        request.discountAmount = null;
        request.applyTaxAfterDiscount = true;

        // Execute invocable method
        Test.startTest();
        List<QuickBooksEstimateResponse> responses = QuickBooksEstimateSimpleInvocable.createEstimate(
            new List<QuickBooksEstimateRequest>{request}
        );
        Test.stopTest();

        // Assert results
        QuickBooksEstimateResponse response = responses[0];
        System.assertEquals(true, response.success, 'Response should be successful');
        System.assertNotEquals(null, response.quickBooksEstimateId, 'Should have estimate ID');
    }

    @isTest
    static void testCreateEstimateWithException() {
        // Create test request with invalid JSON to trigger exception
        QuickBooksEstimateRequest request = new QuickBooksEstimateRequest();
        request.companyId = '123456789';
        request.customerRef = '3';
        request.lineItemsJson = 'INVALID_JSON{[}]';

        // Execute invocable method
        Test.startTest();
        List<QuickBooksEstimateResponse> responses = QuickBooksEstimateSimpleInvocable.createEstimate(
            new List<QuickBooksEstimateRequest>{request}
        );
        Test.stopTest();

        // Even with parse error, the mock implementation should handle it gracefully
        System.assertNotEquals(null, responses, 'Response should not be null');
        System.assertEquals(1, responses.size(), 'Should return one response');

        // Mock implementation should still succeed even with parse errors
        QuickBooksEstimateResponse response = responses[0];
        System.assertNotEquals(null, response, 'Response should not be null');
    }

    @isTest
    static void testMultipleRequests() {
        // Create multiple test requests
        List<QuickBooksEstimateRequest> requests = new List<QuickBooksEstimateRequest>();

        for (Integer i = 0; i < 3; i++) {
            QuickBooksEstimateRequest request = new QuickBooksEstimateRequest();
            request.companyId = '123456789';
            request.customerRef = String.valueOf(i + 1);
            request.customerName = 'Customer ' + i;
            request.customerMemo = 'Test memo ' + i;

            // Add line item
            List<QuickBooksEstimateLineItem> lineItems = new List<QuickBooksEstimateLineItem>();
            lineItems.add(new QuickBooksEstimateLineItem('Item ' + i, 1, 100.00 * (i + 1), String.valueOf(i + 1)));
            request.lineItemsJson = JSON.serialize(lineItems);

            requests.add(request);
        }

        // Execute invocable method
        Test.startTest();
        List<QuickBooksEstimateResponse> responses = QuickBooksEstimateSimpleInvocable.createEstimate(requests);
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
    static void testWithAllOptionalFields() {
        // Create test request with all optional fields
        QuickBooksEstimateRequest request = new QuickBooksEstimateRequest();
        request.companyId = '123456789';
        request.customerRef = '3';
        request.customerName = 'Full Customer';
        request.customerEmail = 'test@example.com';
        request.customerMemo = 'Complete estimate';
        request.privateMemo = 'Internal note';
        request.estimateDate = Date.today();
        request.expirationDate = Date.today().addDays(30);
        request.referenceNumber = 'REF-001';
        request.billToAddress = '123 Main St, City, ST 12345';
        request.shipToAddress = '456 Ship St, City, ST 12345';
        request.currencyRef = 'USD';
        request.taxCodeRef = 'NON';
        request.discountPercent = 5;
        request.discountAmount = 10;
        request.applyTaxAfterDiscount = true;

        // Add line items
        List<QuickBooksEstimateLineItem> lineItems = new List<QuickBooksEstimateLineItem>();
        QuickBooksEstimateLineItem item = new QuickBooksEstimateLineItem();
        item.description = 'Full Service';
        item.itemName = 'Service Item';
        item.itemRef = '10';
        item.quantity = 2;
        item.unitPrice = 50.00;
        item.taxCodeRef = 'TAX';
        item.detailType = 'SalesItemLineDetail';
        item.lineNum = 1;
        lineItems.add(item);
        request.lineItemsJson = JSON.serialize(lineItems);

        // Execute invocable method
        Test.startTest();
        List<QuickBooksEstimateResponse> responses = QuickBooksEstimateSimpleInvocable.createEstimate(
            new List<QuickBooksEstimateRequest>{request}
        );
        Test.stopTest();

        // Assert results
        QuickBooksEstimateResponse response = responses[0];
        System.assertEquals(true, response.success, 'Response should be successful');
        System.assertNotEquals(null, response.quickBooksEstimateId, 'Should have estimate ID');
        System.assert(response.message.contains('Full Customer'), 'Message should contain customer name');
    }
}