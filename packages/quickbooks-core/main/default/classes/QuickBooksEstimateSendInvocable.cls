public with sharing class QuickBooksEstimateSendInvocable {

    @InvocableMethod(label='Send QuickBooks Estimate' description='Sends a QuickBooks Estimate via email' category='QuickBooks')
    public static List<SendEstimateResponse> sendEstimate(List<SendEstimateRequest> requests) {
        List<SendEstimateResponse> responses = new List<SendEstimateResponse>();
        
        for (SendEstimateRequest request : requests) {
            SendEstimateResponse response = new SendEstimateResponse();
            try {
                QuickBooksAPIService.sendEstimate(request.estimateId, request.emailAddress, request.companyId);
                response.success = true;
                response.message = 'Estimate sent successfully' + (String.isNotBlank(request.emailAddress) ? ' to ' + request.emailAddress : '');
            } catch (Exception e) {
                response.success = false;
                response.message = 'Error sending estimate: ' + e.getMessage();
            }
            responses.add(response);
        }
        
        return responses;
    }

    public class SendEstimateRequest {
        @InvocableVariable(label='Company ID' required=true)
        public String companyId;
        
        @InvocableVariable(label='QuickBooks Estimate ID' required=true)
        public String estimateId;
        
        @InvocableVariable(label='Email Address' description='Optional override email address')
        public String emailAddress;
    }
    
    public class SendEstimateResponse {
        @InvocableVariable
        public Boolean success;
        
        @InvocableVariable
        public String message;
    }
}
