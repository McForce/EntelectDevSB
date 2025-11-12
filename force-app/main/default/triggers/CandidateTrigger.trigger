trigger CandidateTrigger on Candidate__c (
    before insert, 
    before update, 
    after insert, 
    after update, 
    after delete, 
    after undelete
) {
    CandidateTriggerHandler handler = new CandidateTriggerHandler(Trigger.isBefore, Trigger.isAfter, Trigger.isInsert, Trigger.isUpdate, Trigger.isDelete, Trigger.isUndelete);

    // if (Trigger.isBefore) {
    //     if (Trigger.isInsert) {
    //         handler.beforeInsert(Trigger.new);
    //     }
    //     if (Trigger.isUpdate) {
    //         handler.beforeUpdate(Trigger.new, Trigger.old, Trigger.newMap, Trigger.oldMap);
    //     }
    // }

    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            handler.afterInsert(Trigger.new, Trigger.newMap);
        }
        // if (Trigger.isUpdate) {
        //     handler.afterUpdate(Trigger.new, Trigger.old, Trigger.newMap, Trigger.oldMap);
        // }
        // if (Trigger.isDelete) {
        //     handler.afterDelete(Trigger.old, Trigger.oldMap);
        // }
        // if (Trigger.isUndelete) {
        //     handler.afterUndelete(Trigger.new, Trigger.newMap);
        // }
    }
}
