public with sharing class CandidateController {
    public CandidateController() { }

    @AuraEnabled(cacheable=true)
    public static List<Candidate__c> getRecommendedCandidates(
        String projectRoleId,
        List<String> skillFilter,
        Integer minYearsExperience,
        String proficiencyFilter
    ) {
        // Get the project role
        Project_Role__c projectRole = [
            SELECT Id, Name, Role__c
            FROM Project_Role__c
            WHERE Id = :projectRoleId
            LIMIT 1
        ];

        // If no skill filters, run the base query (same as before)
        if (skillFilter == null || skillFilter.isEmpty()) {
            return [
                SELECT Id, Name, Overview__c, Skills__c, Candidate_Link__c,
                    (SELECT Id, Skill__c, Years_Experience__c, Speciality__c, Proficiency__c
                        FROM Candidate_Skills__r)
                FROM Candidate__c
                WHERE Employee_Status__c = 'TFO'
                AND Role__c = :projectRole.Role__c
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
        }

        // Step 1: Build the Candidate_Skill__c query dynamically
        String baseQuery = 
            'SELECT Id, Candidate__c, Skill__c, Years_Experience__c, Proficiency__c ' +
            'FROM Candidate_Skill__c ' +
            'WHERE Skill__c IN :skillFilter';

        if (minYearsExperience != null) {
            baseQuery += ' AND Years_Experience__c >= :minYearsExperience';
        }
        if (String.isNotBlank(proficiencyFilter)) {
            baseQuery += ' AND Proficiency__c = :proficiencyFilter';
        }

        List<Candidate_Skill__c> matchingSkills = Database.query(baseQuery);

        // Step 2: Group by candidate
        Map<Id, Set<Id>> candidateToSkills = new Map<Id, Set<Id>>();
        for (Candidate_Skill__c cs : matchingSkills) {
            if (!candidateToSkills.containsKey(cs.Candidate__c)) {
                candidateToSkills.put(cs.Candidate__c, new Set<Id>());
            }
            candidateToSkills.get(cs.Candidate__c).add(cs.Skill__c);
        }

        // Step 3: Only keep candidates that matched ALL required skills
        Set<Id> qualifiedCandidateIds = new Set<Id>();
        for (Id candId : candidateToSkills.keySet()) {
            if (candidateToSkills.get(candId).size() == skillFilter.size()) {
                qualifiedCandidateIds.add(candId);
            }
        }

        if (qualifiedCandidateIds.isEmpty()) {
            return new List<Candidate__c>();
        }

        // Step 4: Fetch candidate records
        return [
            SELECT Id, Name, Overview__c, Skills__c, Candidate_Link__c,
                (SELECT Id, Skill__c, Years_Experience__c, Speciality__c, Proficiency__c
                    FROM Candidate_Skills__r)
            FROM Candidate__c
            WHERE Id IN :qualifiedCandidateIds
            AND Employee_Status__c = 'TFO'
            AND Role__c = :projectRole.Role__c
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Skill__c> getAllSkills() {
        return [SELECT Id, Name FROM Skill__c ORDER BY Name];
    }
}
