global class CandidateEmailServiceHandler implements Messaging.InboundEmailHandler {
    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        try {
            // Create new Candidate record
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
            
            // Set of image file extensions to skip
            Set<String> imageExtensions = new Set<String>{
                '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.ico', '.svg'
            };
            
            // Process binary attachments
            if (email.binaryAttachments != null && email.binaryAttachments.size() > 0) {
                for (Messaging.InboundEmail.BinaryAttachment attachment : email.binaryAttachments) {
                    // Skip if it's an image file
                    Boolean isImage = false;
                    String fileName = attachment.fileName.toLowerCase();
                    
                    // Check file extension
                    for(String ext : imageExtensions) {
                        if(fileName.endsWith(ext)) {
                            isImage = true;
                            break;
                        }
                    }
                    
                    // Skip if it's an image
                    if(isImage) continue;
                    
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
            Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
            result.success = true;
            return result;
            
        } catch (Exception e) {
            // Handle any errors
            Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
            result.success = false;
            result.message = 'Error processing email: ' + e.getMessage();
            return result;
        }
    }
}