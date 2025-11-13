trigger CandidateTrigger on Candidate__c (
    before insert, 
    before update, 
    after insert, 
    after update, 
    after delete, 
    after undelete
) {
    System.debug(LoggingLevel.INFO, 'CandidateTrigger invoked. Context - isBefore=' + Trigger.isBefore + ', isAfter=' + Trigger.isAfter + ', isInsert=' + Trigger.isInsert + ', isUpdate=' + Trigger.isUpdate + ', isDelete=' + Trigger.isDelete + ', isUndelete=' + Trigger.isUndelete + ', size=' + (Trigger.isDelete ? Trigger.old.size() : Trigger.new.size()));
    CandidateTriggerHandler handler = new CandidateTriggerHandler(Trigger.isBefore, Trigger.isAfter, Trigger.isInsert, Trigger.isUpdate, Trigger.isDelete, Trigger.isUndelete);

    // if (Trigger.isBefore) {
    //     if (Trigger.isInsert) {
    //         System.debug(LoggingLevel.FINE, 'Before Insert count=' + Trigger.new.size());
    //         handler.beforeInsert(Trigger.new);
    //     }
    //     if (Trigger.isUpdate) {
    //         System.debug(LoggingLevel.FINE, 'Before Update count=' + Trigger.new.size());
    //         handler.beforeUpdate(Trigger.new, Trigger.old, Trigger.newMap, Trigger.oldMap);
    //     }
    // }

    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            System.debug(LoggingLevel.FINE, 'After Insert count=' + Trigger.new.size());
            handler.afterInsert(Trigger.new, Trigger.newMap);
        }
        // if (Trigger.isUpdate) {
        //     System.debug(LoggingLevel.FINE, 'After Update count=' + Trigger.new.size());
        //     handler.afterUpdate(Trigger.new, Trigger.old, Trigger.newMap, Trigger.oldMap);
        // }
        // if (Trigger.isDelete) {
        //     System.debug(LoggingLevel.FINE, 'After Delete count=' + Trigger.old.size());
        //     handler.afterDelete(Trigger.old, Trigger.oldMap);
        // }
        // if (Trigger.isUndelete) {
        //     System.debug(LoggingLevel.FINE, 'After Undelete count=' + Trigger.new.size());
        //     handler.afterUndelete(Trigger.new, Trigger.newMap);
        // }
    }
    System.debug(LoggingLevel.INFO, 'CandidateTrigger completed.');
}
