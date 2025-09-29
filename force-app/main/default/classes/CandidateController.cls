public with sharing class CandidateController {
    public CandidateController() { }

    @AuraEnabled(cacheable=true)
    public static List<Candidate__c> getRecommendedCandidates(String projectRoleId) {
        // 1. Get the project role and its required skills
        Project_Role__c projectRole = [
            SELECT Id, Name, Role__c,
                (SELECT Id, Skill__c, Years_Experience__c, Speciality__c, Proficiency__c
                FROM Candidate_Skills__r)
            FROM Project_Role__c
            WHERE Id = :projectRoleId
            LIMIT 1
        ];

        // 2. Build a map of required skills for easy comparison
        Map<Id, Candidate_Skill__c> requiredSkills = new Map<Id, Candidate_Skill__c>();
        for (Candidate_Skill__c reqSkill : projectRole.Candidate_Skills__r) {
            requiredSkills.put(reqSkill.Skill__c, reqSkill);
        }

        // 3. Query candidates that match base filters
        List<Candidate__c> candidates = [
            SELECT Id, Name, Overview__c, Skills__c, Candidate_Link__c,
                (SELECT Id, Skill__c, Years_Experience__c, Speciality__c, Proficiency__c
                FROM Candidate_Skills__r)
            FROM Candidate__c
            WHERE Employee_Status__c = 'TFO'
            AND Role__c = :projectRole.Role__c
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];

        // 4. Proficiency ranking helper
        Map<String, Integer> proficiencyRank = new Map<String, Integer>{
            '0 - Unknown Level' => 0,
            '1 - Poor' => 1,
            '2 - Average' => 2,
            '3 - Decent' => 3,
            '4 - Excellent' => 4
        };

        // 5. Filter candidates based on required skills
        List<Candidate__c> matchingCandidates = new List<Candidate__c>();

        for (Candidate__c cand : candidates) {
            Boolean meetsAll = true;

            for (Candidate_Skill__c reqSkill : requiredSkills.values()) {
                Boolean foundMatch = false;
                for (Candidate_Skill__c candSkill : cand.Candidate_Skills__r) {
                    if (candSkill.Skill__c == reqSkill.Skill__c) {
                        // ---- Years of Experience check ----
                        Boolean yearsOk = true; 
                        if (reqSkill.Years_Experience__c != null) {
                            // Candidate must have a value and meet/exceed requirement
                            yearsOk = (candSkill.Years_Experience__c != null &&
                                    candSkill.Years_Experience__c >= reqSkill.Years_Experience__c);
                        }
                        
                        // ---- Proficiency check ----
                        Boolean profOk = true; 
                        if (reqSkill.Proficiency__c != null) {
                            // Treat null candidate proficiency as "0" (fails requirement)
                            Integer candProf = candSkill.Proficiency__c != null 
                                ? proficiencyRank.get(candSkill.Proficiency__c) 
                                : 0;
                            Integer reqProf = proficiencyRank.get(reqSkill.Proficiency__c);
                            
                            profOk = (reqProf != null && candProf >= reqProf);
                        }
                        
                        // If both checks pass, candidate matches this skill
                        if (yearsOk && profOk) {
                            foundMatch = true;
                            break;
                        }
                        if (!yearsOk || !profOk) {
                            meetsAll = false;
                            break; 
                        }
                    }
                }
                // If candidate doesn't have this required skill at all
                if (!foundMatch) {
                    meetsAll = false;
                }
                if (!meetsAll) break;
            }

            if (meetsAll) {
                matchingCandidates.add(cand);
            }
        }

        return matchingCandidates;
    }

    @AuraEnabled(cacheable=true)
    public static List<Skill__c> getAllSkills() {
        return [SELECT Id, Name FROM Skill__c ORDER BY Name];
    }
}
