/**
 * QuickBooks Test Data Factory
 * Provides reusable test data builders for QuickBooks integration tests
 */
public class QuickBooksTestDataFactory {

    /**
     * Create a test Account with QB-related fields
     */
    public static Account createTestAccount(String name) {
        String randomSuffix = String.valueOf(Math.random()).substring(2, 8);

        Account acc = new Account(
            Name = name != null ? name + '_' + randomSuffix : 'Test Account_' + randomSuffix,
            BillingStreet = '123 Test St',
            BillingCity = 'Test City',
            BillingState = 'CA',
            BillingPostalCode = '90210',
            BillingCountry = 'USA',
            Phone = '555-555-5555',
            Website = 'https://testaccount.com',
            Type = 'Customer',
            Industry = 'Technology',
            AccountNumber = 'ACC-' + randomSuffix
        );
        insert acc;
        return acc;
    }

    /**
     * Create test Account with QB Customer ID already set
     */
    public static Account createTestAccountWithQBId(String name, String qbId) {
        Account acc = createTestAccount(name);
        acc.QuickBooks_Customer_Id__c = qbId;
        acc.QuickBooks_Sync_Status__c = 'Synced';
        acc.QuickBooks_Last_Sync__c = DateTime.now();
        update acc;
        return acc;
    }

    /**
     * Create a test Product
     */
    public static Product2 createTestProduct(String name) {
        String randomSuffix = String.valueOf(Math.random()).substring(2, 8);

        Product2 prod = new Product2(
            Name = name != null ? name + '_' + randomSuffix : 'Test Product_' + randomSuffix,
            IsActive = true,
            ProductCode = 'PROD-' + randomSuffix
        );
        insert prod;
        return prod;
    }

    /**
     * Create a test Product with QB Item ID
     */
    public static Product2 createTestProductWithQBId(String name, String qbItemId) {
        Product2 prod = createTestProduct(name);
        prod.QuickBooks_Item_Id__c = qbItemId;
        update prod;
        return prod;
    }

    /**
     * Create a test PricebookEntry
     */
    public static PricebookEntry createTestPricebookEntry(Id productId, Decimal price) {
        Id pricebookId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = productId,
            UnitPrice = price != null ? price : 100.00,
            IsActive = true
        );
        insert pbe;
        return pbe;
    }

    /**
     * Create a test Opportunity
     */
    public static Opportunity createTestOpportunity(String name, Id accountId) {
        Opportunity opp = new Opportunity(
            Name = name != null ? name : 'Test Opportunity',
            AccountId = accountId,
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            Amount = 1000.00
        );
        insert opp;
        return opp;
    }

    /**
     * Create test Opportunity with QB fields pre-populated
     */
    public static Opportunity createTestOpportunityWithQBId(String name, Id accountId, String qbInvoiceId) {
        Opportunity opp = createTestOpportunity(name, accountId);
        opp.QuickBooks_Invoice_Id__c = qbInvoiceId;
        opp.QuickBooks_Invoice_Number__c = '1001';
        opp.QuickBooks_Sync_Status__c = 'Synced';
        opp.QuickBooks_Last_Sync__c = DateTime.now();
        update opp;
        return opp;
    }

    /**
     * Create a test OpportunityLineItem
     */
    public static OpportunityLineItem createTestOpportunityLineItem(
        Id opportunityId,
        Id pricebookEntryId,
        Decimal quantity,
        Decimal unitPrice
    ) {
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opportunityId,
            PricebookEntryId = pricebookEntryId,
            Quantity = quantity != null ? quantity : 1,
            UnitPrice = unitPrice != null ? unitPrice : 100.00
        );
        insert oli;
        return oli;
    }

    /**
     * Create multiple OpportunityLineItems for an Opportunity
     */
    public static List<OpportunityLineItem> createTestOpportunityLineItems(
        Id opportunityId,
        Integer count
    ) {
        List<OpportunityLineItem> items = new List<OpportunityLineItem>();
        Id pricebookId = Test.getStandardPricebookId();

        for (Integer i = 0; i < count; i++) {
            Product2 prod = createTestProduct('Product ' + i);
            PricebookEntry pbe = createTestPricebookEntry(prod.Id, 100.00 + (10 * i));

            OpportunityLineItem oli = new OpportunityLineItem(
                OpportunityId = opportunityId,
                PricebookEntryId = pbe.Id,
                Quantity = 1 + i,
                UnitPrice = 100.00 + (10 * i)
            );
            items.add(oli);
        }

        insert items;
        return items;
    }

    /**
     * Create test QuickBooks Auth record with unique values
     */
    public static QuickBooks_Auth__c createTestAuth(
        String companyId,
        String accessToken,
        String refreshToken,
        Boolean isActive
    ) {
        String randomSuffix = String.valueOf(Math.random()).substring(2, 8);

        // Only add random suffix if specific values not provided
        String finalCompanyId = companyId != null ? companyId : 'company_' + randomSuffix;
        String finalAccessToken = accessToken != null ? accessToken : 'test_access_token_' + randomSuffix;
        String finalRefreshToken = refreshToken != null ? refreshToken : 'test_refresh_token_' + randomSuffix;

        QuickBooks_Auth__c auth = new QuickBooks_Auth__c(
            Company_Id__c = finalCompanyId,
            Access_Token__c = finalAccessToken,
            Refresh_Token__c = finalRefreshToken,
            Token_Expiry__c = DateTime.now().addHours(1),
            Is_Active__c = isActive != null ? isActive : true
        );
        insert auth;
        return auth;
    }

    /**
     * Build a complete test scenario: Account + Product + Opportunity + LineItems + Auth
     */
    public static Map<String, Object> createCompleteTestScenario(String accountName) {
        Map<String, Object> scenario = new Map<String, Object>();

        // Create Account (without QB ID initially)
        Account acc = createTestAccount(accountName);
        scenario.put('account', acc);

        // Create Product
        Product2 prod = createTestProduct('Test Product');
        scenario.put('product', prod);

        // Create PricebookEntry
        PricebookEntry pbe = createTestPricebookEntry(prod.Id, 100.00);
        scenario.put('pricebookEntry', pbe);

        // Create Opportunity
        Opportunity opp = createTestOpportunity('Test Opp', acc.Id);
        scenario.put('opportunity', opp);

        // Create OpportunityLineItem
        OpportunityLineItem oli = createTestOpportunityLineItem(opp.Id, pbe.Id, 2, 100.00);
        scenario.put('opportunityLineItem', oli);

        // Create Auth with fixed company ID for consistency
        String companyId = '123456789';
        QuickBooks_Auth__c auth = createTestAuth(companyId, 'test_token', 'test_refresh', true);
        scenario.put('auth', auth);
        scenario.put('companyId', companyId);

        return scenario;
    }

    /**
     * Create test scenario with account that has QB Customer ID
     */
    public static Map<String, Object> createScenarioWithQBCustomer(String accountName, String qbCustomerId) {
        Map<String, Object> scenario = createCompleteTestScenario(accountName);

        Account acc = (Account) scenario.get('account');
        acc.QuickBooks_Customer_Id__c = qbCustomerId;
        acc.QuickBooks_Sync_Status__c = 'Synced';
        acc.QuickBooks_Last_Sync__c = DateTime.now();
        update acc;

        return scenario;
    }

    /**
     * Create Integration_Log__c test record
     */
    public static Integration_Log__c createIntegrationLog(
        String integrationType,
        String context,
        String errorMessage,
        Id recordId
    ) {
        Integration_Log__c log = new Integration_Log__c(
            Integration_Type__c = integrationType != null ? integrationType : 'QuickBooks',
            Context__c = context != null ? context : 'Test',
            Error_Message__c = errorMessage,
            Record_Id__c = recordId,
            Timestamp__c = DateTime.now()
        );
        insert log;
        return log;
    }

    /**
     * Build QuickBooksCustomerRequest
     */
    public static QuickBooksCustomerRequest buildCustomerRequest(Id accountId, String companyId) {
        QuickBooksCustomerRequest req = new QuickBooksCustomerRequest();
        req.accountId = accountId;
        req.companyId = companyId != null ? companyId : '123456789';
        return req;
    }

    /**
     * Build QuickBooksInvoiceRequest
     */
    public static QuickBooksInvoiceRequest buildInvoiceRequest(Id opportunityId, String companyId) {
        QuickBooksInvoiceRequest req = new QuickBooksInvoiceRequest();
        req.opportunityId = opportunityId;
        req.companyId = companyId != null ? companyId : '123456789';
        return req;
    }
}
