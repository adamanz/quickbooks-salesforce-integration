@isTest
private class QuickBooksDTOsTest {

    @isTest
    static void testQuickBooksDTOs() {
        // Test CustomerRequest
        QuickBooksDTOs.CustomerRequest custReq = new QuickBooksDTOs.CustomerRequest();
        custReq.accountId = '001000000000000';
        custReq.companyId = '123';
        System.assertEquals('123', custReq.companyId);

        // Test CustomerResponse
        QuickBooksDTOs.CustomerResponse custRes = new QuickBooksDTOs.CustomerResponse();
        custRes.success = true;
        custRes.message = 'Success';
        custRes.quickBooksCustomerId = 'QB123';
        custRes.salesforceAccountId = '001000000000000';
        System.assertEquals(true, custRes.success);

        // Test InvoiceRequest
        QuickBooksDTOs.InvoiceRequest invReq = new QuickBooksDTOs.InvoiceRequest();
        invReq.opportunityId = '006000000000000';
        invReq.companyId = '123';
        System.assertEquals('123', invReq.companyId);

        // Test InvoiceResponse
        QuickBooksDTOs.InvoiceResponse invRes = new QuickBooksDTOs.InvoiceResponse();
        invRes.success = true;
        invRes.message = 'Success';
        invRes.quickBooksInvoiceId = 'INV123';
        invRes.quickBooksInvoiceNumber = '1001';
        invRes.salesforceOpportunityId = '006000000000000';
        System.assertEquals('INV123', invRes.quickBooksInvoiceId);

        // Test PaymentSyncRequest
        QuickBooksDTOs.PaymentSyncRequest payReq = new QuickBooksDTOs.PaymentSyncRequest();
        payReq.accountId = '001000000000000';
        payReq.quickBooksCustomerId = 'QB123';
        payReq.companyId = '123';
        System.assertEquals('QB123', payReq.quickBooksCustomerId);

        // Test PaymentSyncResponse
        QuickBooksDTOs.PaymentSyncResponse payRes = new QuickBooksDTOs.PaymentSyncResponse();
        payRes.success = true;
        payRes.message = 'Success';
        payRes.paymentsProcessed = 5;
        System.assertEquals(5, payRes.paymentsProcessed);

        // Test ItemRequest
        QuickBooksDTOs.ItemRequest itemReq = new QuickBooksDTOs.ItemRequest();
        itemReq.productId = '01t000000000000';
        itemReq.companyId = '123';
        System.assertEquals('01t000000000000', itemReq.productId);

        // Test ItemResponse
        QuickBooksDTOs.ItemResponse itemRes = new QuickBooksDTOs.ItemResponse();
        itemRes.success = true;
        itemRes.message = 'Success';
        itemRes.quickBooksItemId = 'ITEM123';
        itemRes.salesforceProductId = '01t000000000000';
        System.assertEquals('ITEM123', itemRes.quickBooksItemId);
    }

    @isTest
    static void testStandaloneDTOs() {
        // QuickBooksCustomerRequest
        QuickBooksCustomerRequest custReq = new QuickBooksCustomerRequest();
        custReq.accountId = '001000000000000';
        custReq.companyId = '123';
        custReq.fullName = 'John Doe';
        custReq.displayName = 'John Doe';
        custReq.firstName = 'John';
        custReq.lastName = 'Doe';
        custReq.companyName = 'Acme';
        custReq.email = 'john@example.com';
        custReq.phone = '555-1234';
        System.assertEquals('John Doe', custReq.fullName);

        // QuickBooksCustomerResponse
        QuickBooksCustomerResponse custRes = new QuickBooksCustomerResponse();
        custRes.success = true;
        custRes.message = 'Success';
        custRes.quickBooksCustomerId = 'QB123';
        custRes.salesforceAccountId = '001000000000000';
        System.assertEquals(true, custRes.success);

        // QuickBooksInvoiceRequest
        QuickBooksInvoiceRequest invReq = new QuickBooksInvoiceRequest();
        invReq.opportunityId = '006000000000000';
        invReq.companyId = '123';
        System.assertEquals('123', invReq.companyId);

        // QuickBooksInvoiceResponse
        QuickBooksInvoiceResponse invRes = new QuickBooksInvoiceResponse();
        invRes.success = true;
        invRes.message = 'Success';
        invRes.quickBooksInvoiceId = 'INV123';
        invRes.quickBooksInvoiceNumber = '1001';
        invRes.salesforceOpportunityId = '006000000000000';
        System.assertEquals('INV123', invRes.quickBooksInvoiceId);
    }

    /**
     * Test QuickBooksEstimateResponse fields
     */
    @isTest
    static void testEstimateResponse() {
        QuickBooksEstimateResponse estRes = new QuickBooksEstimateResponse();
        estRes.success = true;
        estRes.message = 'Estimate created successfully';
        estRes.quickBooksEstimateId = 'EST-999';
        estRes.quickBooksEstimateNumber = 'EST-1001';
        estRes.salesforceOpportunityId = '006000000000000';

        System.assertEquals(true, estRes.success);
        System.assertEquals('Estimate created successfully', estRes.message);
        System.assertEquals('EST-999', estRes.quickBooksEstimateId);
        System.assertEquals('EST-1001', estRes.quickBooksEstimateNumber);
        System.assertEquals('006000000000000', estRes.salesforceOpportunityId);
    }

    /**
     * Test QuickBooksEstimateRequest comprehensive fields
     */
    @isTest
    static void testEstimateRequestAllFields() {
        QuickBooksEstimateRequest estReq = new QuickBooksEstimateRequest();
        estReq.opportunityId = '006000000000000';
        estReq.companyId = 'COMPANY-789';
        estReq.customerRef = 'CUST-123';
        estReq.customerName = 'Test Customer';
        estReq.lineItemsJson = '[{"description":"Item 1","amount":100}]';
        estReq.discountPercent = 10.0;
        estReq.discountAmount = 50.0;
        estReq.applyTaxAfterDiscount = true;
        estReq.estimateDate = Date.today();
        estReq.expirationDate = Date.today().addDays(30);
        estReq.referenceNumber = 'REF-001';
        estReq.customerMemo = 'Thank you';
        estReq.privateMemo = 'Internal note';
        estReq.billToAddress = '123 Main St';
        estReq.shipToAddress = '456 Ship Ave';
        estReq.customerEmail = 'test@example.com';
        estReq.currencyRef = 'USD';
        estReq.taxCodeRef = 'TAX';

        System.assertEquals('006000000000000', estReq.opportunityId);
        System.assertEquals('COMPANY-789', estReq.companyId);
        System.assertEquals('CUST-123', estReq.customerRef);
        System.assertEquals('Test Customer', estReq.customerName);
        System.assertEquals(10.0, estReq.discountPercent);
        System.assertEquals(50.0, estReq.discountAmount);
        System.assertEquals(true, estReq.applyTaxAfterDiscount);
        System.assertEquals('REF-001', estReq.referenceNumber);
        System.assertEquals('Thank you', estReq.customerMemo);
        System.assertEquals('Internal note', estReq.privateMemo);
        System.assertEquals('123 Main St', estReq.billToAddress);
        System.assertEquals('456 Ship Ave', estReq.shipToAddress);
        System.assertEquals('test@example.com', estReq.customerEmail);
        System.assertEquals('USD', estReq.currencyRef);
        System.assertEquals('TAX', estReq.taxCodeRef);
    }

    /**
     * Test QuickBooksEstimateRequest parseLineItems with valid JSON
     */
    @isTest
    static void testParseLineItemsSuccess() {
        QuickBooksEstimateRequest estReq = new QuickBooksEstimateRequest();
        estReq.opportunityId = '006000000000000';
        estReq.companyId = 'COMPANY-789';
        estReq.lineItemsJson = '[{"description":"Item 1","amount":100,"quantity":2}]';

        Test.startTest();
        estReq.parseLineItems();
        Test.stopTest();

        System.assertNotEquals(null, estReq.lineItems, 'Line items should be parsed');
        System.assertEquals(1, estReq.lineItems.size(), 'Should have 1 line item');
    }

    /**
     * Test QuickBooksEstimateRequest parseLineItems with invalid JSON
     */
    @isTest
    static void testParseLineItemsError() {
        QuickBooksEstimateRequest estReq = new QuickBooksEstimateRequest();
        estReq.opportunityId = '006000000000000';
        estReq.companyId = 'COMPANY-789';
        estReq.lineItemsJson = 'invalid json {{{';

        Test.startTest();
        estReq.parseLineItems();
        Test.stopTest();

        System.assertNotEquals(null, estReq.lineItems, 'Line items should be initialized');
        System.assertEquals(0, estReq.lineItems.size(), 'Should have 0 items on error');
    }

    /**
     * Test QuickBooksEstimateRequest parseLineItems with blank JSON
     */
    @isTest
    static void testParseLineItemsBlank() {
        QuickBooksEstimateRequest estReq = new QuickBooksEstimateRequest();
        estReq.opportunityId = '006000000000000';
        estReq.companyId = 'COMPANY-789';
        estReq.lineItemsJson = '';

        Test.startTest();
        estReq.parseLineItems();
        Test.stopTest();

        System.assertEquals(null, estReq.lineItems, 'Line items should remain null');
    }

    /**
     * Test QuickBooksEstimateLineItem fields
     */
    @isTest
    static void testEstimateLineItem() {
        QuickBooksEstimateLineItem lineItem = new QuickBooksEstimateLineItem();
        lineItem.description = 'Test Item';
        lineItem.amount = 100.00;
        lineItem.quantity = 2;
        lineItem.itemRef = 'ITEM-123';
        lineItem.salesItemLineDetail = new Map<String, Object>{
            'ItemRef' => new Map<String, String>{'value' => 'ITEM-123'}
        };

        System.assertEquals('Test Item', lineItem.description);
        System.assertEquals(100.00, lineItem.amount);
        System.assertEquals(2, lineItem.quantity);
        System.assertEquals('ITEM-123', lineItem.itemRef);
        System.assertNotEquals(null, lineItem.salesItemLineDetail);
    }
}
