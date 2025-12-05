/**
 * QuickBooksRecordMatcher
 * Finds matching Salesforce Accounts and Opportunities from QuickBooks data
 * Uses multiple strategies: Customer ID, Email, Name, Phone, Amount
 */
public class QuickBooksRecordMatcher {
    
    /**
     * Result class for matching operations
     */
    public class MatchResult {
        public Id accountId;
        public Id opportunityId;
        public Id contactId;
        public String matchStrategy;
        public Boolean isNewAccount = false;
        public Boolean isNewOpportunity = false;
    }
    
    /**
     * Find or create Account and Opportunity from QuickBooks customer data
     * @param customerRef - Map containing 'value' (customer ID) and 'name' (customer name)
     * @param email - Customer email address
     * @param phone - Customer phone number
     * @param amount - Transaction amount (for opportunity matching)
     * @param billAddr - Billing address map
     * @param createIfNotFound - Whether to create new records if no match found
     * @return MatchResult with matched/created record IDs
     */
    public static MatchResult findOrCreateRecords(
        Map<String, Object> customerRef,
        String email,
        String phone,
        Decimal amount,
        Map<String, Object> billAddr,
        Boolean createIfNotFound
    ) {
        MatchResult result = new MatchResult();
        
        String customerId = customerRef != null ? (String) customerRef.get('value') : null;
        String customerName = customerRef != null ? (String) customerRef.get('name') : null;
        
        // Strategy 1: Match by QuickBooks Customer ID
        if (String.isNotBlank(customerId)) {
            List<Account> accounts = [
                SELECT Id, Name FROM Account 
                WHERE QuickBooks_Customer_Id__c = :customerId 
                LIMIT 1
            ];
            if (!accounts.isEmpty()) {
                result.accountId = accounts[0].Id;
                result.matchStrategy = 'QuickBooks Customer ID';
            }
        }
        
        // Strategy 2: Match by Email → Contact → Account
        if (result.accountId == null && String.isNotBlank(email)) {
            List<Contact> contacts = [
                SELECT Id, AccountId, Account.Name 
                FROM Contact 
                WHERE Email = :email AND AccountId != null
                LIMIT 1
            ];
            if (!contacts.isEmpty()) {
                result.accountId = contacts[0].AccountId;
                result.contactId = contacts[0].Id;
                result.matchStrategy = 'Email → Contact';
            }
        }
        
        // Strategy 3: Match by Customer Name → Account Name (exact)
        if (result.accountId == null && String.isNotBlank(customerName)) {
            List<Account> accounts = [
                SELECT Id, Name FROM Account 
                WHERE Name = :customerName 
                LIMIT 1
            ];
            if (!accounts.isEmpty()) {
                result.accountId = accounts[0].Id;
                result.matchStrategy = 'Account Name (exact)';
            }
        }
        
        // Strategy 4: Match by Customer Name → Account Name (fuzzy)
        if (result.accountId == null && String.isNotBlank(customerName)) {
            String searchName = '%' + customerName + '%';
            List<Account> accounts = [
                SELECT Id, Name FROM Account 
                WHERE Name LIKE :searchName 
                LIMIT 1
            ];
            if (!accounts.isEmpty()) {
                result.accountId = accounts[0].Id;
                result.matchStrategy = 'Account Name (fuzzy)';
            }
        }
        
        // Strategy 5: Match by Phone
        if (result.accountId == null && String.isNotBlank(phone)) {
            // Normalize phone for matching
            String normalizedPhone = phone.replaceAll('[^0-9]', '');
            if (normalizedPhone.length() >= 10) {
                String phoneLast10 = '%' + normalizedPhone.right(10) + '%';
                List<Account> accounts = [
                    SELECT Id, Name FROM Account 
                    WHERE Phone LIKE :phoneLast10 
                    LIMIT 1
                ];
                if (!accounts.isEmpty()) {
                    result.accountId = accounts[0].Id;
                    result.matchStrategy = 'Phone Number';
                }
            }
        }
        
        // If we found an Account, try to find a matching Opportunity
        if (result.accountId != null) {
            result.opportunityId = findOpportunityForAccount(result.accountId, amount, customerId);
        }
        
        // Create new records if requested and no match found
        if (createIfNotFound && result.accountId == null && String.isNotBlank(customerName)) {
            result = createNewRecords(customerName, email, phone, amount, billAddr, customerId);
        }
        
        return result;
    }
    
    /**
     * Find best matching Opportunity for an Account
     */
    private static Id findOpportunityForAccount(Id accountId, Decimal amount, String customerId) {
        // First try: Opportunity with matching amount (not yet linked)
        if (amount != null && amount > 0) {
            List<Opportunity> opps = [
                SELECT Id FROM Opportunity
                WHERE AccountId = :accountId
                AND Amount = :amount
                AND QuickBooks_Invoice_Id__c = null
                ORDER BY CloseDate DESC
                LIMIT 1
            ];
            if (!opps.isEmpty()) return opps[0].Id;
        }
        
        // Second try: Most recent Opportunity without QuickBooks link
        List<Opportunity> opps = [
            SELECT Id FROM Opportunity
            WHERE AccountId = :accountId
            AND QuickBooks_Invoice_Id__c = null
            AND QuickBooks_Estimate_Id__c = null
            ORDER BY CloseDate DESC
            LIMIT 1
        ];
        if (!opps.isEmpty()) return opps[0].Id;
        
        // Third try: Any recent Opportunity
        opps = [
            SELECT Id FROM Opportunity
            WHERE AccountId = :accountId
            ORDER BY CloseDate DESC
            LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0].Id;
    }
    
    /**
     * Create new Account and Opportunity when no match found
     */
    private static MatchResult createNewRecords(
        String customerName, 
        String email, 
        String phone, 
        Decimal amount,
        Map<String, Object> billAddr,
        String customerId
    ) {
        MatchResult result = new MatchResult();
        
        // Create Account
        Account newAccount = new Account(
            Name = customerName,
            Phone = phone
        );
        
        // Set QuickBooks Customer ID if available
        if (String.isNotBlank(customerId)) {
            newAccount.QuickBooks_Customer_Id__c = customerId;
        }
        
        // Set address if available
        if (billAddr != null) {
            newAccount.BillingStreet = (String) billAddr.get('Line1');
            newAccount.BillingCity = (String) billAddr.get('City');
            newAccount.BillingState = (String) billAddr.get('CountrySubDivisionCode');
            newAccount.BillingPostalCode = (String) billAddr.get('PostalCode');
        }
        
        insert newAccount;
        result.accountId = newAccount.Id;
        result.isNewAccount = true;
        result.matchStrategy = 'Created New Account';
        
        // Create Contact if email provided
        if (String.isNotBlank(email)) {
            String[] nameParts = customerName.split(' ', 2);
            Contact newContact = new Contact(
                FirstName = nameParts.size() > 1 ? nameParts[0] : '',
                LastName = nameParts.size() > 1 ? nameParts[1] : customerName,
                Email = email,
                AccountId = newAccount.Id
            );
            insert newContact;
            result.contactId = newContact.Id;
        }
        
        // Create Opportunity
        Opportunity newOpp = new Opportunity(
            Name = customerName + ' - QuickBooks',
            AccountId = newAccount.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(30),
            Amount = amount
        );
        insert newOpp;
        result.opportunityId = newOpp.Id;
        result.isNewOpportunity = true;
        
        return result;
    }
    
    /**
     * Extract customer details from QuickBooks transaction data
     */
    public static Map<String, Object> extractCustomerDetails(Map<String, Object> transactionData) {
        Map<String, Object> details = new Map<String, Object>();
        
        // CustomerRef
        details.put('customerRef', transactionData.get('CustomerRef'));
        
        // Email from BillEmail
        Map<String, Object> billEmail = (Map<String, Object>) transactionData.get('BillEmail');
        if (billEmail != null) {
            details.put('email', billEmail.get('Address'));
        }
        
        // Phone from PrimaryPhone or BillAddr
        Map<String, Object> primaryPhone = (Map<String, Object>) transactionData.get('PrimaryPhone');
        if (primaryPhone != null) {
            details.put('phone', primaryPhone.get('FreeFormNumber'));
        }
        
        // Amount
        details.put('amount', transactionData.get('TotalAmt'));
        
        // Billing Address
        details.put('billAddr', transactionData.get('BillAddr'));
        
        return details;
    }
}

