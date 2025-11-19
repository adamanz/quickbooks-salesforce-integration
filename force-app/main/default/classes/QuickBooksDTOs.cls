/**
 * Data Transfer Objects for QuickBooks Integration
 * Shared types for Invocable Actions and Service layer
 */
global with sharing class QuickBooksDTOs {

    global class CustomerRequest {
        @InvocableVariable(label='Salesforce Account ID' required=true) @AuraEnabled global Id accountId;
        @InvocableVariable(label='QuickBooks Company ID' required=true) @AuraEnabled global String companyId;
    }

    global class CustomerResponse {
        @InvocableVariable(label='Success') @AuraEnabled global Boolean success;
        @InvocableVariable(label='Message') @AuraEnabled global String message;
        @InvocableVariable(label='QuickBooks Customer ID') @AuraEnabled global String quickBooksCustomerId;
        @InvocableVariable(label='Salesforce Account ID') @AuraEnabled global Id salesforceAccountId;
    }

    global class InvoiceRequest {
        @InvocableVariable(label='Salesforce Opportunity ID' required=true) @AuraEnabled global Id opportunityId;
        @InvocableVariable(label='QuickBooks Company ID' required=true) @AuraEnabled global String companyId;
    }

    global class InvoiceResponse {
        @InvocableVariable(label='Success') @AuraEnabled global Boolean success;
        @InvocableVariable(label='Message') @AuraEnabled global String message;
        @InvocableVariable(label='QuickBooks Invoice ID') @AuraEnabled global String quickBooksInvoiceId;
        @InvocableVariable(label='QuickBooks Invoice Number') @AuraEnabled global String quickBooksInvoiceNumber;
        @InvocableVariable(label='Salesforce Opportunity ID') @AuraEnabled global Id salesforceOpportunityId;
    }

    global class PaymentSyncRequest {
        @InvocableVariable(label='Salesforce Account ID' required=true) @AuraEnabled global Id accountId;
        @InvocableVariable(label='QuickBooks Customer ID' required=true) @AuraEnabled global String quickBooksCustomerId;
        @InvocableVariable(label='QuickBooks Company ID' required=true) @AuraEnabled global String companyId;
    }

    global class PaymentSyncResponse {
        @InvocableVariable(label='Success') @AuraEnabled global Boolean success;
        @InvocableVariable(label='Message') @AuraEnabled global String message;
        @InvocableVariable(label='Payments Processed') @AuraEnabled global Integer paymentsProcessed;
    }

    global class ItemRequest {
        @InvocableVariable(label='Salesforce Product ID' required=true) @AuraEnabled global Id productId;
        @InvocableVariable(label='QuickBooks Company ID' required=true) @AuraEnabled global String companyId;
    }

    global class ItemResponse {
        @InvocableVariable(label='Success') @AuraEnabled global Boolean success;
        @InvocableVariable(label='Message') @AuraEnabled global String message;
        @InvocableVariable(label='QuickBooks Item ID') @AuraEnabled global String quickBooksItemId;
        @InvocableVariable(label='Salesforce Product ID') @AuraEnabled global Id salesforceProductId;
    }
}