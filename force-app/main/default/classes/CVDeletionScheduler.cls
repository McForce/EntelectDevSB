public with sharing class CVDeletionScheduler implements Schedulable {
    @AuraEnabled
    public static void scheduleJob(List<Id> candidateIds) {
        System.debug(LoggingLevel.INFO, 'CVDeletionScheduler.scheduleJob invoked. CandidateIds size=' + (candidateIds == null ? 0 : candidateIds.size()));
        
        String jobName = 'CVDeletion_' + System.now().getTime();
        String cron = System.now().addMinutes(5).format('s m H d M ? yyyy');
        
        System.debug(LoggingLevel.INFO, 'Scheduling job. name=' + jobName + ', cron=' + cron);
        System.schedule(jobName, cron, new CVDeletionScheduler(candidateIds));
        System.debug(LoggingLevel.INFO, 'Job scheduled successfully for candidateIds=' + candidateIds);
    }

    private List<Id> candidateIds;

    public CVDeletionScheduler(List<Id> ids) {
        System.debug(LoggingLevel.FINE, 'CVDeletionScheduler constructor called. ids size=' + (ids == null ? 0 : ids.size()));
        this.candidateIds = ids;
    }

    public void execute(SchedulableContext sc) {
        System.debug(LoggingLevel.INFO, 'CVDeletionScheduler.execute started. Enqueuing CVDeletionQueueable for candidateIds size=' + (candidateIds == null ? 0 : candidateIds.size()));
        System.enqueueJob(new CVDeletionQueueable(candidateIds));
        System.debug(LoggingLevel.INFO, 'CVDeletionScheduler.execute completed. Queueable enqueued.');
    }
}
