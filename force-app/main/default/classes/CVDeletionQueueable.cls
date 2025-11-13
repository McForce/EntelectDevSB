public class CVDeletionQueueable implements Queueable, Database.AllowsCallouts {
    private List<Id> candidateIds;

    public CVDeletionQueueable(List<Id> ids) {
        System.debug(LoggingLevel.FINE, 'CVDeletionQueueable constructor called. ids size=' + (ids == null ? 0 : ids.size()));
        this.candidateIds = ids;
    }

    public void execute(QueueableContext context) {
        System.debug(LoggingLevel.INFO, 'CVDeletionQueueable.execute started. candidateIds size=' + (candidateIds == null ? 0 : candidateIds.size()));
        try {
            // 1. Query linked files
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :candidateIds
            ];
            System.debug(LoggingLevel.INFO, 'Fetched ContentDocumentLink records. count=' + links.size());

            Map<Id, Id> docToCandidate = new Map<Id, Id>();
            for (ContentDocumentLink link : links) {
                docToCandidate.put(link.ContentDocumentId, link.LinkedEntityId);
            }


            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink l : links) docIds.add(l.ContentDocumentId);
            System.debug(LoggingLevel.FINE, 'Unique ContentDocumentIds count=' + docIds.size());

            List<ContentVersion> versions = [
                SELECT Id, ContentDocumentId, VersionData, Title
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds
                AND IsLatest = TRUE
            ];
            System.debug(LoggingLevel.INFO, 'Fetched latest ContentVersion records. count=' + versions.size());

            Integer approvedCount = 0;
            Integer deletedCount = 0;

            // 2. Send to external service
            for (ContentVersion v : versions) {
                Id candidateId = docToCandidate.get(v.ContentDocumentId);
                System.debug(LoggingLevel.FINE, 'Processing ContentVersion Id=' + v.Id + ', Title=' + v.Title + ', ContentDocumentId=' + v.ContentDocumentId);
                Blob cvBlob = v.VersionData;
                Boolean approved = false;
                try {
                    approved = ExternalCVService.sendCV(cvBlob, v.Title, candidateId);
                    System.debug(LoggingLevel.INFO, 'ExternalCVService.sendCV result for ContentDocumentId=' + v.ContentDocumentId + ' is approved=' + approved);
                } catch (Exception calloutEx) {
                    System.debug(LoggingLevel.ERROR, 'Error calling ExternalCVService for ContentDocumentId=' + v.ContentDocumentId + ': ' + calloutEx.getMessage());
                }

                // 3. Delete if approved
                if (approved) {
                    approvedCount++;
                    try {
                        delete [SELECT Id FROM ContentDocument WHERE Id = :v.ContentDocumentId];
                        deletedCount++;
                        System.debug(LoggingLevel.INFO, 'Deleted ContentDocument Id=' + v.ContentDocumentId);
                    } catch (Exception delEx) {
                        System.debug(LoggingLevel.ERROR, 'Failed to delete ContentDocument Id=' + v.ContentDocumentId + ': ' + delEx.getMessage());
                    }
                }
            }

            System.debug(LoggingLevel.INFO, 'CVDeletionQueueable.execute completed. approvedCount=' + approvedCount + ', deletedCount=' + deletedCount);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Unhandled exception in CVDeletionQueueable.execute: ' + e.getMessage() + ' | StackTrace=' + e.getStackTraceString());
            throw e;
        }
    }
}