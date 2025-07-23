global class EmailService implements Messaging.InboundEmailHandler {
    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        List<Attachment> att = new List<Attachment>();
        Contact con = new Contact();
        
        // Handle contact name from email
        if (email.fromName != null && email.fromName != '') {
            con.FirstName = email.fromName.substring(0, email.fromName.indexOf(' '));
            con.LastName = email.fromName.substring(email.fromName.indexOf(' '));
        }
        
        // Set contact email and other fields
        con.Email = envelope.fromAddress;
        
        if (email.plainTextBody != null && email.plainTextBody != '') {
            con.Description = email.plainTextBody;
        }
        
        if (email.subject != null && email.subject != '') {
            con.Title = email.subject;
        }
        
        insert con;
        
        // Handle binary attachments
        if (email.binaryAttachments != null && email.binaryAttachments.size() > 0) {
            for (Integer i = 0; i < email.binaryAttachments.size(); i++) {
                Attachment attachment = new Attachment();
                attachment.ParentId = con.Id;
                attachment.Name = email.binaryAttachments[i].filename;
                attachment.Body = email.binaryAttachments[i].body;
                att.add(attachment);
            }
            insert att;
        }
        
        // Handle text attachments
        if (email.textAttachments != null && email.textAttachments.size() > 0) {
            for (Integer i = 0; i < email.textAttachments.size(); i++) {
                Attachment attachment = new Attachment();
                attachment.ParentId = con.Id;
                attachment.Name = email.textAttachments[i].filename;
                attachment.Body = Blob.valueOf(email.textAttachments[i].body);
                att.add(attachment);
            }
            insert att;
        }
        
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        return result;
    }
}