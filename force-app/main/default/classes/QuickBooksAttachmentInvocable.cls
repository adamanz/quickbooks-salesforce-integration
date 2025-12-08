public with sharing class QuickBooksAttachmentInvocable {

    @InvocableMethod(label='Upload Attachment to QuickBooks' 
                     description='Uploads a Salesforce file to QuickBooks and attaches it to a record' 
                     category='QuickBooks')
    public static List<AttachmentResponse> uploadAttachment(List<AttachmentRequest> requests) {
        List<AttachmentResponse> responses = new List<AttachmentResponse>();
        
        for (AttachmentRequest request : requests) {
            AttachmentResponse response = new AttachmentResponse();
            try {
                // Get file content
                ContentVersion file = [SELECT Id, Title, PathOnClient, VersionData, FileExtension 
                                     FROM ContentVersion 
                                     WHERE Id = :request.contentVersionId 
                                     LIMIT 1];
                                     
                QuickBooksAPIService.uploadAttachment(
                    request.quickBooksRecordId, 
                    request.quickBooksRecordType,
                    file.Title + '.' + file.FileExtension,
                    getContentType(file.FileExtension),
                    file.VersionData,
                    request.companyId
                );
                
                response.success = true;
                response.message = 'Attachment uploaded successfully';
            } catch (Exception e) {
                response.success = false;
                response.message = 'Error uploading attachment: ' + e.getMessage();
            }
            responses.add(response);
        }
        
        return responses;
    }

    private static String getContentType(String extension) {
        String ext = extension.toLowerCase();
        if (ext == 'pdf') return 'application/pdf';
        if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
        if (ext == 'png') return 'image/png';
        if (ext == 'doc' || ext == 'docx') return 'application/msword';
        if (ext == 'xls' || ext == 'xlsx') return 'application/vnd.ms-excel';
        return 'application/octet-stream';
    }

    public class AttachmentRequest {
        @InvocableVariable(label='Company ID' required=true)
        public String companyId;
        
        @InvocableVariable(label='QuickBooks Record ID' required=true description='ID of Estimate, Invoice, etc.')
        public String quickBooksRecordId;

        @InvocableVariable(label='QuickBooks Record Type' required=true description='Estimate, Invoice, Bill, etc.')
        public String quickBooksRecordType;
        
        @InvocableVariable(label='Content Version ID' required=true description='Salesforce File (ContentVersion) ID')
        public String contentVersionId;
    }
    
    public class AttachmentResponse {
        @InvocableVariable
        public Boolean success;
        
        @InvocableVariable
        public String message;
    }
}

