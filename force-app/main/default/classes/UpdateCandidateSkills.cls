public with sharing class UpdateCandidateSkills { 

    // Wrapper for Flow input
    public class Request {
        @InvocableVariable(required=true)
        public String skillInput;

        @InvocableVariable(required=true)
        public Id candidateId;
    }

    // DTO for parsed skill
    private class SkillDetail {
        public String skillName;
        public Decimal experience;
        public Boolean isSpecialty;

        public SkillDetail() {
            this.experience = 0;
            this.isSpecialty = false;
        }
    }

    @InvocableMethod(
        label='Update Candidate Skills' 
        description='Takes a skill input string and candidate Id from Flow and processes it'
    )
    public static void updateSkills(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            System.debug('No requests provided.');
            return;
        }

        for (Request req : requests) {
            if (String.isBlank(req.skillInput) || req.candidateId == null) {
                System.debug('Invalid request: candidateId or skillInput missing.');
                continue;
            }

            try {
                System.debug('Candidate Id passed from Flow: ' + req.candidateId);
                System.debug('Skill string passed from Flow: ' + req.skillInput);

                List<Candidate_Skill__c> skillRecords = parseAndBuildSkills(req.skillInput, req.candidateId);

                if (!skillRecords.isEmpty()) {
                    insert skillRecords;
                    System.debug('Inserted ' + skillRecords.size() + ' skill records for Candidate Id: ' + req.candidateId);
                } else {
                    System.debug('No valid skills parsed for Candidate Id: ' + req.candidateId);
                }
            } catch (Exception e) {
                // Prevent Flow from failing and provide context
                System.debug('Error processing Candidate Id ' + req.candidateId + ': ' + e.getMessage());
            }
        }
    }

    // -------------------------------
    // Private Helpers
    // -------------------------------

    private static List<Candidate_Skill__c> parseAndBuildSkills(String skillInput, Id candidateId) {
        List<Candidate_Skill__c> skillRecords = new List<Candidate_Skill__c>();
        List<String> rawSkills = new List<String>();

        for (String skill : skillInput.split(',')) {
            if (!String.isBlank(skill)) {
                rawSkills.add(skill.trim());
            }
        }
        if (rawSkills.isEmpty()) return skillRecords;

        // Bulk query all matching Skill__c records once
        Map<String, Id> skillNameToId = new Map<String, Id>();
        List<Skill__c> matchedSkills = [
            SELECT Id, Name FROM Skill__c 
            WHERE Name IN :rawSkills
        ];
        for (Skill__c s : matchedSkills) {
            skillNameToId.put(s.Name.toLowerCase(), s.Id);
        }

        // Build Candidate_Skill__c records
        for (String rawSkill : rawSkills) {
            SkillDetail detail = parseSkill(rawSkill);
            if (detail == null || String.isBlank(detail.skillName)) continue;

            Id skillId = skillNameToId.get(detail.skillName.toLowerCase());

            skillRecords.add(new Candidate_Skill__c(
                Candidate__c        = candidateId,
                Skill__c            = skillId,
                Name       = detail.skillName,
                Years_Experience__c = detail.experience,
                Speciality__c        = detail.isSpecialty
            ));
        }

        return skillRecords;
    }

    private static SkillDetail parseSkill(String rawSkill) {
        SkillDetail detail = new SkillDetail();

        if (!rawSkill.contains('-')) {
            detail.skillName = rawSkill;
            return detail;
        }

        List<String> parts = rawSkill.split('-');
        detail.skillName = parts[0].trim();

        if (parts.size() > 1) {
            detail.experience = parseExperience(parts[1].trim());
        }

        if (parts.size() > 2) {
            String specialty = parts[2].trim().toLowerCase();
            detail.isSpecialty = (specialty == 'yes' || specialty == 'true');
        }

        return detail;
    }

    private static Decimal parseExperience(String expPart) {
        if (String.isBlank(expPart)) return 0;

        try {
            return Decimal.valueOf(expPart.split(' ')[0]);
        } catch (Exception e) {
            System.debug('Error parsing experience from "' + expPart + '": ' + e.getMessage());
            return 0;
        }
    }
}
