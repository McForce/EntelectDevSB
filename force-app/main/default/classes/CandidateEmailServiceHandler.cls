global class CandidateEmailServiceHandler implements Messaging.InboundEmailHandler {
    // Set of allowed file extensions for candidate creation
    private static final Set<String> ALLOWED_EXTENSIONS = new Set<String>{
        '.pdf', '.doc', '.docx', '.rtf', '.txt'
    };
    
    // Set of image file extensions to skip
    private static final Set<String> IMAGE_EXTENSIONS = new Set<String>{
        '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.ico', '.svg'
    };
    
    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        
        try {
            // Check if there are valid attachments before proceeding
            Boolean hasValidAttachment = false;
            
            // Check binary attachments
            if (email.binaryAttachments != null && email.binaryAttachments.size() > 0) {
                for (Messaging.InboundEmail.BinaryAttachment attachment : email.binaryAttachments) {
                    if (isAllowedFileType(attachment.fileName)) {
                        hasValidAttachment = true;
                        break;
                    }
                }
            }
            
            // Check text attachments if no valid binary attachments were found
            if (!hasValidAttachment && email.textAttachments != null && email.textAttachments.size() > 0) {
                for (Messaging.InboundEmail.TextAttachment attachment : email.textAttachments) {
                    if (isAllowedFileType(attachment.fileName)) {
                        hasValidAttachment = true;
                        break;
                    }
                }
            }
            
            // If no valid attachments, return without creating a Candidate
            if (!hasValidAttachment) {
                result.success = true; // Still mark as success to avoid retries
                return result;
            }
            
            // Create new Candidate record since we have valid attachments
            Candidate__c candidate = new Candidate__c();
            
            // Set the name from the email sender's name
            if (email.fromName != null && email.fromName != '') {
                candidate.Name = email.fromName;
            } else {
                // If no name is provided, use the email address
                candidate.Name = envelope.fromAddress;
            }
            
            // Set the sender's email address
            if (envelope.fromAddress != null && envelope.fromAddress != '') {
                candidate.From_Email__c = envelope.fromAddress;
            }
            
            // Set the email subject
            if (email.subject != null && email.subject != '') {
                candidate.Email_Subject__c = email.subject;
                
                // Check if subject contains "New submission from Application Form"
                if (email.subject.contains('New submission from Application Form')) {
                    candidate.Creation_Source__c = 'Culture Site Application Form Email';
                } else {
                    candidate.Creation_Source__c = 'Direct Candidate Email';
                }
            }
            
            //Set the email body
            if (email.plainTextBody != null && email.plainTextBody != '') {
                candidate.Email_Body__c = email.plainTextBody;
            }
            
            // Insert the candidate record
            insert candidate;
            
            // Handle all attachments by converting them to Files (ContentVersion)
            List<ContentVersion> contentVersions = new List<ContentVersion>();
            
            // Process binary attachments
            if (email.binaryAttachments != null && email.binaryAttachments.size() > 0) {
                for (Messaging.InboundEmail.BinaryAttachment attachment : email.binaryAttachments) {
                    // Skip if it's an image file
                    if (isImageFile(attachment.fileName)) continue;
                    
                    ContentVersion cv = new ContentVersion();
                    cv.Title = attachment.fileName;
                    cv.PathOnClient = attachment.fileName;
                    cv.VersionData = attachment.body;
                    cv.FirstPublishLocationId = candidate.Id;
                    contentVersions.add(cv);
                }
            }
            
            // Process text attachments
            if (email.textAttachments != null && email.textAttachments.size() > 0) {
                for (Messaging.InboundEmail.TextAttachment attachment : email.textAttachments) {
                    ContentVersion cv = new ContentVersion();
                    cv.Title = attachment.fileName;
                    cv.PathOnClient = attachment.fileName;
                    cv.VersionData = Blob.valueOf(attachment.body);
                    cv.FirstPublishLocationId = candidate.Id;
                    contentVersions.add(cv);
                }
            }
            
            // Insert all content versions
            if (!contentVersions.isEmpty()) {
                insert contentVersions;
            }
            
            // Return success result
            result.success = true;
            return result;
            
        } catch (Exception e) {
            // Handle any errors
            result.success = false;
            result.message = 'Error processing email: ' + e.getMessage();
            return result;
        }
    }
    
    // Helper method to check if a file is an allowed type for candidate creation
    private Boolean isAllowedFileType(String fileName) {
        if (fileName == null) return false;
        
        String lowerFileName = fileName.toLowerCase();
        
        // Check if it's one of the allowed file types
        for (String extension : ALLOWED_EXTENSIONS) {
            if (lowerFileName.endsWith(extension)) {
                return true;
            }
        }
        
        return false;
    }
    
    // Helper method to check if a file is an image
    private Boolean isImageFile(String fileName) {
        if (fileName == null) return false;
        
        String lowerFileName = fileName.toLowerCase();
        
        // Check if it's an image file
        for (String extension : IMAGE_EXTENSIONS) {
            if (lowerFileName.endsWith(extension)) {
                return true;
            }
        }
        
        return false;
    }
}