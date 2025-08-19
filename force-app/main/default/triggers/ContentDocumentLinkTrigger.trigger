trigger ContentDocumentLinkTrigger on ContentDocumentLink (after insert) {
    // Only process if we have records to process
    if (Trigger.isAfter && Trigger.isInsert) {
        // Set to store ContentDocument IDs
        Set<Id> contentDocumentIds = new Set<Id>();
        // Set to store Candidate IDs
        Set<Id> candidateIds = new Set<Id>();
        
        // Get the Candidate object's prefix to identify Candidate records
        String candidatePrefix = Schema.SObjectType.Candidate__c.getKeyPrefix();
        
        // Collect ContentDocument IDs and Candidate IDs from trigger records
        for (ContentDocumentLink cdl : Trigger.new) {
            // Check if the linked entity is a Candidate record
            if (String.valueOf(cdl.LinkedEntityId).startsWith(candidatePrefix)) {
                contentDocumentIds.add(cdl.ContentDocumentId);
                candidateIds.add(cdl.LinkedEntityId);
            }
        }
        
        // Only proceed if we have Candidate records to update
        if (!candidateIds.isEmpty()) {
            // Query ContentDocument records to get titles and FileType
            Map<Id, ContentDocument> contentDocuments = new Map<Id, ContentDocument>(
                [SELECT Id, Title, FileType FROM ContentDocument WHERE Id IN :contentDocumentIds]
            );
            
            // Create map to store Candidate ID to Document Title
            Map<Id, String> candidateToDocumentTitle = new Map<Id, String>();
            
            // Match ContentDocument titles to Candidates, excluding SNOTE types
            for (ContentDocumentLink cdl : Trigger.new) {
                if (String.valueOf(cdl.LinkedEntityId).startsWith(candidatePrefix)) {
                    ContentDocument cd = contentDocuments.get(cdl.ContentDocumentId);
                    if (cd != null && cd.FileType != 'SNOTE') {
                        candidateToDocumentTitle.put(cdl.LinkedEntityId, cd.Title);
                    }
                }
            }
            
            // Update Candidate records
            if (!candidateToDocumentTitle.isEmpty()) {
                List<Candidate__c> candidatesToUpdate = new List<Candidate__c>();
                
                for (Id candidateId : candidateToDocumentTitle.keySet()) {
                    candidatesToUpdate.add(new Candidate__c(
                        Id = candidateId,
                        CV_Title__c = candidateToDocumentTitle.get(candidateId)
                    ));
                }
                
                try {
                    update candidatesToUpdate;
                } catch (Exception e) {
                    // Add error to all affected records
                    for (ContentDocumentLink cdl : Trigger.new) {
                        cdl.addError('Failed to update CV Title: ' + e.getMessage());
                    }
                }
            }
        }
    }
}