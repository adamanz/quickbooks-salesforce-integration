/**
 * Test class for QuickBooksEstimateInvocable
 * Tests creating QuickBooks estimates with multiple line items, discounts, and tax
 */
@isTest
public class QuickBooksEstimateInvocableTest {

    @isTest
    static void testCreateEstimateSuccess() {
        // Create test data
        QuickBooksEstimateTestHelper.createTestAuthRecord();
        Opportunity opp = QuickBooksEstimateTestHelper.createTestOpportunity(true);
        QuickBooksEstimateRequest request = QuickBooksEstimateTestHelper.createTestRequest(opp.Id);

        // Set mock callout
        Test.setMock(HttpCalloutMock.class, QuickBooksEstimateTestHelper.getSuccessfulEstimateMock());

        Test.startTest();
        List<QuickBooksEstimateResponse> responses = QuickBooksEstimateInvocable.createEstimate(
            new List<QuickBooksEstimateRequest>{request}
        );
        Test.stopTest();

        // Assertions
        System.assertEquals(1, responses.size(), 'Should return one response');
        QuickBooksEstimateResponse response = responses[0];
        System.assertEquals(true, response.success, 'Estimate should be created successfully');
        System.assertEquals('1001', response.quickBooksEstimateId, 'Should have QB estimate ID');
        System.assertEquals('EST-1001', response.quickBooksEstimateNumber, 'Should have QB estimate number');
    }

    @isTest
    static void testCreateEstimateWithCustomLineItems() {
        // Create test data
        QuickBooksEstimateTestHelper.createTestAuthRecord();
        Opportunity opp = QuickBooksEstimateTestHelper.createTestOpportunity(true);
        QuickBooksEstimateRequest request = QuickBooksEstimateTestHelper.createTestRequest(opp.Id);

        // Add custom line items
        List<QuickBooksEstimateLineItem> lineItems = QuickBooksEstimateTestHelper.createTestLineItems();
        request.lineItemsJson = JSON.serialize(lineItems);

        // Set mock callout
        Test.setMock(HttpCalloutMock.class, QuickBooksEstimateTestHelper.getSuccessfulEstimateMock());

        Test.startTest();
        List<QuickBooksEstimateResponse> responses = QuickBooksEstimateInvocable.createEstimate(
            new List<QuickBooksEstimateRequest>{request}
        );
        Test.stopTest();

        // Assertions
        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assertEquals(true, responses[0].success, 'Estimate should be created successfully');
    }

    @isTest
    static void testCreateEstimateAPIError() {
        // Create test data
        QuickBooksEstimateTestHelper.createTestAuthRecord();
        Opportunity opp = QuickBooksEstimateTestHelper.createTestOpportunity(true);
        QuickBooksEstimateRequest request = QuickBooksEstimateTestHelper.createTestRequest(opp.Id);

        // Set mock callout for error
        Test.setMock(HttpCalloutMock.class, QuickBooksEstimateTestHelper.getFailedEstimateMock());

        Test.startTest();
        List<QuickBooksEstimateResponse> responses = QuickBooksEstimateInvocable.createEstimate(
            new List<QuickBooksEstimateRequest>{request}
        );
        Test.stopTest();

        // Assertions
        System.assertEquals(1, responses.size(), 'Should return one response');
        QuickBooksEstimateResponse response = responses[0];
        System.assertEquals(false, response.success, 'Estimate creation should fail');
        System.assert(response.message.contains('Invalid customer reference'), 'Should contain error message');
    }

    @isTest
    static void testCreateEstimateNoCustomerId() {
        // Create test data
        Opportunity opp = QuickBooksEstimateTestHelper.createTestOpportunity(true);
        QuickBooksEstimateRequest request = QuickBooksEstimateTestHelper.createTestRequest(opp.Id);
        request.customerRef = null; // Remove customer ID

        Test.startTest();
        List<QuickBooksEstimateResponse> responses = QuickBooksEstimateInvocable.createEstimate(
            new List<QuickBooksEstimateRequest>{request}
        );
        Test.stopTest();

        // Assertions
        System.assertEquals(1, responses.size(), 'Should return one response');
        QuickBooksEstimateResponse response = responses[0];
        System.assertEquals(false, response.success, 'Estimate creation should fail');
        System.assert(response.message.contains('Customer'), 'Should mention customer in error');
    }

    @isTest
    static void testEstimateRequestClass() {
        QuickBooksEstimateRequest req = new QuickBooksEstimateRequest();
        req.opportunityId = '006000000000000AAA';
        req.companyId = '123456789';
        req.customerRef = '3';
        req.customerName = 'Test Customer';
        req.discountPercent = 10;
        req.discountAmount = 5.00;
        req.applyTaxAfterDiscount = true;
        req.estimateDate = Date.today();
        req.expirationDate = Date.today().addDays(30);
        req.referenceNumber = 'REF-001';
        req.customerMemo = 'Test memo';
        req.privateMemo = 'Private memo';
        req.billToAddress = '123 Test St';
        req.shipToAddress = '456 Ship St';
        req.customerEmail = 'test@example.com';
        req.currencyRef = 'USD';
        req.taxCodeRef = 'TAX';

        // Test line items JSON parsing
        List<QuickBooksEstimateLineItem> items = QuickBooksEstimateTestHelper.createTestLineItems();
        req.lineItemsJson = JSON.serialize(items);
        req.parseLineItems();

        System.assertEquals(2, req.lineItems.size());
        System.assertEquals('Test Customer', req.customerName);
    }

    @isTest
    static void testEstimateLineItemClass() {
        QuickBooksEstimateLineItem item = new QuickBooksEstimateLineItem();
        item.description = 'Test Product';
        item.itemName = 'Product Name';
        item.itemRef = '10';
        item.quantity = 3;
        item.unitPrice = 25.00;
        item.amount = 75.00;
        item.taxCodeRef = 'NON';
        item.discountPercent = 10;
        item.discountAmount = 7.50;
        item.detailType = 'SalesItemLineDetail';
        item.lineNum = 1;

        item.calculateAmount();
        System.assertEquals(75.00, item.amount);

        // Test constructor with params
        QuickBooksEstimateLineItem item2 = new QuickBooksEstimateLineItem('Test', 2, 30.00, '5');
        System.assertEquals(60.00, item2.amount);
        System.assertEquals('Test', item2.description);
    }

    @isTest
    static void testEstimateResponseClass() {
        QuickBooksEstimateResponse response = new QuickBooksEstimateResponse();
        response.success = true;
        response.quickBooksEstimateId = '123';
        response.quickBooksEstimateNumber = 'EST-123';
        response.salesforceOpportunityId = '006000000000000AAA';
        response.message = 'Success';

        System.assertEquals(true, response.success);
        System.assertEquals('123', response.quickBooksEstimateId);
    }

    @isTest
    static void testQuickBooksException() {
        try {
            throw new QuickBooksEstimateInvocable.QuickBooksException('Test error');
        } catch(QuickBooksEstimateInvocable.QuickBooksException e) {
            System.assertEquals('Test error', e.getMessage());
        }
    }

    @isTest
    static void testDiscountAmountInsteadOfPercent() {
        QuickBooksEstimateTestHelper.createTestAuthRecord();
        Opportunity opp = QuickBooksEstimateTestHelper.createTestOpportunity(true);
        QuickBooksEstimateRequest request = QuickBooksEstimateTestHelper.createTestRequest(opp.Id);
        request.discountPercent = null;
        request.discountAmount = 10.00;

        Test.setMock(HttpCalloutMock.class, QuickBooksEstimateTestHelper.getSuccessfulEstimateMock());

        Test.startTest();
        List<QuickBooksEstimateResponse> responses = QuickBooksEstimateInvocable.createEstimate(
            new List<QuickBooksEstimateRequest>{request}
        );
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals(true, responses[0].success);
    }

    @isTest
    static void testWithDatesAndAddresses() {
        QuickBooksEstimateTestHelper.createTestAuthRecord();
        Opportunity opp = QuickBooksEstimateTestHelper.createTestOpportunity(true);
        QuickBooksEstimateRequest request = QuickBooksEstimateTestHelper.createTestRequest(opp.Id);
        request.estimateDate = Date.today().addDays(5);
        request.expirationDate = Date.today().addDays(35);
        request.billToAddress = '123 Main St, San Francisco, CA, 94105';
        request.shipToAddress = '456 Ship Ave, Oakland, CA, 94612';

        Test.setMock(HttpCalloutMock.class, QuickBooksEstimateTestHelper.getSuccessfulEstimateMock());

        Test.startTest();
        List<QuickBooksEstimateResponse> responses = QuickBooksEstimateInvocable.createEstimate(
            new List<QuickBooksEstimateRequest>{request}
        );
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals(true, responses[0].success);
    }
}