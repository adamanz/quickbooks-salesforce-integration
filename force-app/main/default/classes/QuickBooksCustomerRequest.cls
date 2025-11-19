public class QuickBooksCustomerRequest {
    @InvocableVariable(label='Salesforce Account ID' required=true) @AuraEnabled public Id accountId;
    @InvocableVariable(label='QuickBooks Company ID' required=true) @AuraEnabled public String companyId;
    @InvocableVariable(label='Full Name') @AuraEnabled public String fullName;
    @InvocableVariable(label='Display Name') @AuraEnabled public String displayName;
    @InvocableVariable(label='First Name') @AuraEnabled public String firstName;
    @InvocableVariable(label='Last Name') @AuraEnabled public String lastName;
    @InvocableVariable(label='Company Name') @AuraEnabled public String companyName;
    @InvocableVariable(label='Email') @AuraEnabled public String email;
    @InvocableVariable(label='Phone') @AuraEnabled public String phone;
}