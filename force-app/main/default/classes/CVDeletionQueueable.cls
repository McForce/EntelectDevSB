public class CVDeletionQueueable implements Queueable, Database.AllowsCallouts {
    private List<Id> candidateIds;

    public CVDeletionQueueable(List<Id> ids) {
        this.candidateIds = ids;
    }

    public void execute(QueueableContext context) {
        // 1. Query linked files
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :candidateIds
        ];

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : links) docIds.add(l.ContentDocumentId);

        List<ContentVersion> versions = [
            SELECT Id, ContentDocumentId, VersionData, Title
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND IsLatest = TRUE
        ];

        // 2. Send to external service
        for (ContentVersion v : versions) {
            Blob cvBlob = v.VersionData;
            Boolean approved = ExternalCVService.sendCV(cvBlob, v.Title);

            // 3. Delete if approved
            if (approved) {
                delete [SELECT Id FROM ContentDocument WHERE Id = :v.ContentDocumentId];
            }
        }
    }
}
