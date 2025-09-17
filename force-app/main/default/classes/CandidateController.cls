public with sharing class CandidateController {
    public CandidateController() {

    }

    @AuraEnabled(cacheable=true)
    public static List<Candidate__c> getRecommendedCandidates(String projectRoleId) {

        List<Project_Role__c> projectRoles = [SELECT Id, Name, Role__c FROM Project_Role__c WHERE Id = :projectRoleId];
        if(projectRoles.isEmpty()) {
            return new List<Candidate__c>();
        }

        Project_Role__c projectRole = projectRoles[0];

        List<Candidate__c> availableCandidates =  [SELECT Id, Name, Email__c, Phone__c, Current_Employer__c, Current_Role__c,
                (SELECT Id, Skill__c, Years_Experience__c, Speciality__c FROM Candidate_Skills__r)
                FROM Candidate__c
                WHERE  Employee_Status__c = 'TFO' AND Role__c = projectRole.Role__c
                ORDER BY CreatedDate DESC
                LIMIT 5];
    }
}