global class CandidateEmailServiceHandler implements Messaging.InboundEmailHandler {

    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email,
                                                          Messaging.InboundEnvelope envelope) {
        
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        
        try {
            // Create Candidate record
            Candidate__c candidate = new Candidate__c();
            
            // Extract sender's name from fromName or email address
            String senderName = String.isNotBlank(email.fromName) ? email.fromName : email.fromAddress;
            
            // Populate Candidate fields
            candidate.Name = senderName;
            candidate.From_Email__c = email.fromAddress;
            candidate.Email_Subject__c = email.subject;
            candidate.Email_Body__c = email.plainTextBody != null ? email.plainTextBody : email.htmlBody;
            
            insert candidate;
            
            // Save attachments, if any
            List<Attachment> attachmentList = new List<Attachment>();
            
            // Process text attachments
            if (email.textAttachments != null && !email.textAttachments.isEmpty()) {
                for (Messaging.InboundEmail.TextAttachment tAttachment : email.textAttachments) {
                    Attachment attachment = new Attachment();
                    attachment.Name = tAttachment.fileName;
                    attachment.Body = Blob.valueOf(tAttachment.body);
                    attachment.ParentId = candidate.Id;
                    attachmentList.add(attachment);
                }
            }
            
            // Process binary attachments
            if (email.binaryAttachments != null && !email.binaryAttachments.isEmpty()) {
                for (Messaging.InboundEmail.BinaryAttachment bAttachment : email.binaryAttachments) {
                    Attachment attachment = new Attachment();
                    attachment.Name = bAttachment.fileName;
                    attachment.Body = bAttachment.body;
                    attachment.ParentId = candidate.Id;
                    attachmentList.add(attachment);
                }
            }
            
            // Insert all attachments at once
            if (!attachmentList.isEmpty()) {
                insert attachmentList;
            }
            
            result.success = true;
            
        } catch (Exception e) {
            result.success = false;
            result.message = 'Error creating Candidate record: ' + e.getMessage();
        }
        
        return result;
    }
    }
        