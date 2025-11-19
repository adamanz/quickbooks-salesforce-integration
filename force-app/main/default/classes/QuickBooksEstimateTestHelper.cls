/**
 * Test Helper class for QuickBooks Estimate functionality
 * Provides mock implementations and test data factory methods
 */
@isTest
public class QuickBooksEstimateTestHelper {

    /**
     * Mock implementation for HTTP callouts to QuickBooks API
     */
    public class QuickBooksEstimateMock implements HttpCalloutMock {
        private Integer statusCode;
        private String status;
        private String responseBody;

        public QuickBooksEstimateMock(Integer statusCode, String status, String responseBody) {
            this.statusCode = statusCode;
            this.status = status;
            this.responseBody = responseBody;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(statusCode);
            res.setStatus(status);
            res.setBody(responseBody);
            return res;
        }
    }

    /**
     * Mock for successful estimate creation
     */
    public static HttpCalloutMock getSuccessfulEstimateMock() {
        String responseBody = '{"Estimate":{"Id":"1001","DocNumber":"EST-1001","TotalAmt":85.00,"Line":[{"LineNum":1,"DetailType":"SalesItemLineDetail","Amount":35.00},{"DetailType":"SubTotalLineDetail","Amount":35.00}]}}';
        return new QuickBooksEstimateMock(200, 'OK', responseBody);
    }

    /**
     * Mock for failed estimate creation
     */
    public static HttpCalloutMock getFailedEstimateMock() {
        String responseBody = '{"Fault":{"Error":[{"Message":"Invalid customer reference","Detail":"Customer not found","code":"6000"}],"type":"ValidationFault"}}';
        return new QuickBooksEstimateMock(400, 'Bad Request', responseBody);
    }

    /**
     * Create test opportunity with line items
     */
    public static Opportunity createTestOpportunity(Boolean doInsert) {
        String randomSuffix = String.valueOf(Math.random()).substring(2, 8);
        Account acc = new Account(
            Name = 'Test Account ' + randomSuffix,
            BillingStreet = '123 Test St',
            BillingCity = 'San Francisco',
            BillingState = 'CA',
            BillingPostalCode = '94105'
        );

        if (doInsert) {
            insert acc;

            // Dynamically set QuickBooks Customer ID using SObject.put()
            // This works even if the field doesn't exist in the org schema
            try {
                acc.put('QuickBooks_Customer_Id__c', '3');
                acc.put('QuickBooks_Sync_Status__c', 'Synced');
                acc.put('QuickBooks_Last_Sync__c', DateTime.now());
                update acc;
            } catch (Exception e) {
                // If fields don't exist, that's OK - tests will handle it
                System.debug('Note: QuickBooks custom fields not in schema: ' + e.getMessage());
            }
        }

        // Create Products
        Product2 product1 = new Product2(
            Name = 'Pest Control',
            ProductCode = 'PC-001',
            IsActive = true
        );
        Product2 product2 = new Product2(
            Name = 'Lawn Care',
            ProductCode = 'LC-001',
            IsActive = true
        );
        if (doInsert) insert new List<Product2>{product1, product2};

        // Get standard pricebook
        Id pricebookId = Test.getStandardPricebookId();

        // Create PricebookEntries
        PricebookEntry pbe1 = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = product1.Id,
            UnitPrice = 35.00,
            IsActive = true
        );
        PricebookEntry pbe2 = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = product2.Id,
            UnitPrice = 50.00,
            IsActive = true
        );
        if (doInsert) insert new List<PricebookEntry>{pbe1, pbe2};

        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 85.00,
            Pricebook2Id = pricebookId
        );
        if (doInsert) {
            insert opp;

            // Create Opportunity Line Items
            OpportunityLineItem oli1 = new OpportunityLineItem(
                OpportunityId = opp.Id,
                Product2Id = product1.Id,
                PricebookEntryId = pbe1.Id,
                Quantity = 1,
                UnitPrice = 35.00
            );
            OpportunityLineItem oli2 = new OpportunityLineItem(
                OpportunityId = opp.Id,
                Product2Id = product2.Id,
                PricebookEntryId = pbe2.Id,
                Quantity = 1,
                UnitPrice = 50.00
            );
            insert new List<OpportunityLineItem>{oli1, oli2};
        }

        return opp;
    }

    /**
     * Create test estimate request
     */
    public static QuickBooksEstimateRequest createTestRequest(Id opportunityId) {
        QuickBooksEstimateRequest request = new QuickBooksEstimateRequest();
        request.opportunityId = opportunityId;
        request.companyId = '123456789';
        request.customerRef = '3';
        request.customerName = 'Test Customer';
        request.customerEmail = 'test@example.com';
        request.discountPercent = 10;
        request.applyTaxAfterDiscount = false;
        request.customerMemo = 'Thank you for your business!';
        request.billToAddress = '65 Ocean Dr., Half Moon Bay, CA, 94213';
        request.shipToAddress = '65 Ocean Dr., Half Moon Bay, CA, 94213';
        request.estimateDate = Date.today();
        request.expirationDate = Date.today().addDays(30);
        request.referenceNumber = 'REF-001';
        request.privateMemo = 'Internal note';
        request.currencyRef = 'USD';
        request.taxCodeRef = 'NON';
        return request;
    }

    /**
     * Create test line items
     */
    public static List<QuickBooksEstimateLineItem> createTestLineItems() {
        List<QuickBooksEstimateLineItem> items = new List<QuickBooksEstimateLineItem>();

        QuickBooksEstimateLineItem item1 = new QuickBooksEstimateLineItem();
        item1.description = 'Pest Control Services';
        item1.quantity = 1;
        item1.unitPrice = 35.00;
        item1.amount = 35.00;
        item1.itemRef = '10';
        item1.itemName = 'Pest Control';
        item1.taxCodeRef = 'NON';
        item1.detailType = 'SalesItemLineDetail';
        item1.lineNum = 1;
        items.add(item1);

        QuickBooksEstimateLineItem item2 = new QuickBooksEstimateLineItem();
        item2.description = 'Lawn Care Services';
        item2.quantity = 2;
        item2.unitPrice = 25.00;
        item2.amount = 50.00;
        item2.itemRef = '11';
        item2.itemName = 'Lawn Care';
        item2.taxCodeRef = 'TAX';
        item2.detailType = 'SalesItemLineDetail';
        item2.lineNum = 2;
        items.add(item2);

        return items;
    }

    /**
     * Create test QuickBooks auth record
     */
    public static void createTestAuthRecord() {
        QuickBooks_Auth__c auth = new QuickBooks_Auth__c(
            Company_Id__c = '123456789',
            Access_Token__c = 'test-access-token',
            Refresh_Token__c = 'test-refresh-token',
            Token_Expiry__c = DateTime.now().addHours(1),
            Is_Active__c = true
        );
        insert auth;
    }
}