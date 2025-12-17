trigger ContentDocumentLinkTrigger on ContentDocumentLink (after insert) {
    // Only process if we have records to process
    if (!Trigger.isAfter || !Trigger.isInsert) return;

    // Sets to collect IDs
    Set<Id> contentDocumentIds = new Set<Id>();
    Set<Id> candidateIds = new Set<Id>();

    // Candidate prefix
    String candidatePrefix = Schema.SObjectType.Candidate__c.getKeyPrefix();

    // Collect ContentDocument and Candidate IDs
    for (ContentDocumentLink cdl : Trigger.new) {
        if (String.valueOf(cdl.LinkedEntityId).startsWith(candidatePrefix)) {
            contentDocumentIds.add(cdl.ContentDocumentId);
            candidateIds.add(cdl.LinkedEntityId);
        }
    }

    if (contentDocumentIds.isEmpty() || candidateIds.isEmpty()) return;

    // Query latest ContentVersions for the documents
    Map<Id, ContentVersion> latestContentVersions = new Map<Id, ContentVersion>();
    for (ContentVersion cv : [
        SELECT Id, Title, FileType, Processed__c, ContentDocumentId, IsLatest
        FROM ContentVersion
        WHERE ContentDocumentId IN :contentDocumentIds
        AND IsLatest = true
    ]) {
        latestContentVersions.put(cv.ContentDocumentId, cv);
    }

    // Map CandidateId -> ContentVersion Title (only if unprocessed)
    Map<Id, Id> candidateToDocumentTitle = new Map<Id, Id>();
    List<ContentVersion> contentVersionsToUpdate = new List<ContentVersion>();

    for (ContentDocumentLink cdl : Trigger.new) {
        if (!String.valueOf(cdl.LinkedEntityId).startsWith(candidatePrefix)) continue;

        ContentVersion cv = latestContentVersions.get(cdl.ContentDocumentId);
        if (cv == null) continue;
        if (cv.FileType == 'SNOTE') continue;

        // Only process if Processed__c is null or false
        if (cv.Processed__c == null || cv.Processed__c == false) {
            candidateToDocumentTitle.put(cdl.LinkedEntityId, cv.ContentDocumentId);

            // // Optionally mark the version as processed
            // cv.Processed__c = true;
            // contentVersionsToUpdate.add(cv);
        }
    }

    // Update Candidate records with document titles
    if (!candidateToDocumentTitle.isEmpty()) {
        List<Candidate__c> candidatesToUpdate = new List<Candidate__c>();
        for (Id candidateId : candidateToDocumentTitle.keySet()) {
            candidatesToUpdate.add(new Candidate__c(
                Id = candidateId,
                Additional_Documents_Title__c = candidateToDocumentTitle.get(candidateId)
            ));
        }

        try {
            update candidatesToUpdate;
        } catch (Exception e) {
            for (ContentDocumentLink cdl : Trigger.new) {
                cdl.addError('Failed to update CV Title: ' + e.getMessage());
            }
        }
    }

    // // Update ContentVersions Processed__c
    // if (!contentVersionsToUpdate.isEmpty()) {
    //     try {
    //         update contentVersionsToUpdate;
    //     } catch (Exception e) {
    //         // You can log errors here or handle as needed
    //         System.debug('Failed to update Processed__c: ' + e.getMessage());
    //     }
    // }
}
