public with sharing class CVDeletionScheduler implements Schedulable {
     @AuraEnabled
    public static void scheduleJob(List<Id> candidateIds) {
        String jobName = 'CVDeletion_' + System.now().getTime();
        String cron = System.now().addMinutes(5).format('s m H d M ? yyyy');
        System.schedule(jobName, cron, new CVDeletionScheduler(candidateIds));
    }

    private List<Id> candidateIds;

    public CVDeletionScheduler(List<Id> ids) {
        this.candidateIds = ids;
    }

    global void execute(SchedulableContext sc) {
        System.enqueueJob(new CVDeletionQueueable(candidateIds));
    }
}