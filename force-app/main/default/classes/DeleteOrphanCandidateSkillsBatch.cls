global class DeleteOrphanCandidateSkillsBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    // Track total deleted across all batches
    global Integer totalDeleted = 0;

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id FROM Candidate_Skill__c WHERE Candidate__c = NULL'
        );
    }

    global void execute(Database.BatchableContext bc, List<Candidate_Skill__c> scope) {
        if (!scope.isEmpty()) {
            Database.DeleteResult[] results = Database.delete(scope, false);

            for (Database.DeleteResult dr : results) {
                if (dr.isSuccess()) {
                    totalDeleted++;
                } else {
                    System.debug(
                        'Failed to delete Candidate_Skill__c: ' +
                        dr.getErrors()[0].getMessage()
                    );
                }
            }
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('TOTAL Candidate_Skill__c records deleted: ' + totalDeleted);
    }
}