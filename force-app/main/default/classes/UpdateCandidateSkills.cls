public with sharing class UpdateCandidateSkills {

    // Wrapper for Flow input
    public class Request {
        @InvocableVariable(required=true)
        public String skillInput;

        @InvocableVariable(required=true)
        public Id candidateId;
    }

    // DTO for parsed skill
    @TestVisible
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
        description='Updates candidate skills (Years Experience + Speciality) based on input'
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
                System.debug('Candidate Id: ' + req.candidateId);
                System.debug('Skill string: ' + req.skillInput);

                List<Candidate_Skill__c> updates = parseAndBuildSkillUpdates(req.skillInput, req.candidateId);

                if (!updates.isEmpty()) {
                    update updates;
                    System.debug('Updated ' + updates.size() + ' candidate skills for Candidate Id: ' + req.candidateId);
                } else {
                    System.debug('No matching candidate skills found to update for Candidate Id: ' + req.candidateId);
                }
            } catch (Exception e) {
                System.debug('Error processing Candidate Id ' + req.candidateId + ': ' + e.getMessage());
            }
        }
    }

    // -------------------------------
    // Private Helpers
    // -------------------------------

    @TestVisible
    private static List<Candidate_Skill__c> parseAndBuildSkillUpdates(String skillInput, Id candidateId) {
        List<Candidate_Skill__c> skillUpdates = new List<Candidate_Skill__c>();
        List<String> rawSkills = new List<String>();

        for (String skill : skillInput.split(',')) {
            if (!String.isBlank(skill)) {
                rawSkills.add(skill.trim());
            }
        }
        if (rawSkills.isEmpty()) return skillUpdates;

        // Parse details
        List<SkillDetail> parsedDetails = new List<SkillDetail>();
        Set<String> skillNames = new Set<String>();
        for (String rawSkill : rawSkills) {
            SkillDetail detail = parseSkill(rawSkill);
            if (detail != null && !String.isBlank(detail.skillName)) {
                parsedDetails.add(detail);
                skillNames.add(detail.skillName);
            }
        }

        if (skillNames.isEmpty()) return skillUpdates;

        // Query existing Candidate_Skill__c records
        Map<String, Candidate_Skill__c> existingMap = new Map<String, Candidate_Skill__c>();
        for (Candidate_Skill__c cs : [
            SELECT Id, Name, Candidate__c 
            FROM Candidate_Skill__c
            WHERE Candidate__c = :candidateId
            AND Name IN :skillNames
        ]) {
            existingMap.put(cs.Name.toLowerCase(), cs);
        }

        // Build updates
        for (SkillDetail detail : parsedDetails) {
            Candidate_Skill__c existing = existingMap.get(detail.skillName.toLowerCase());
            if (existing != null) {
                existing.Years_Experience__c = detail.experience;
                existing.Speciality__c = detail.isSpecialty;
                skillUpdates.add(existing);
            }
        }

        return skillUpdates;
    }

    @TestVisible
    private static SkillDetail parseSkill(String rawSkill) {
        SkillDetail detail = new SkillDetail();

        if (!rawSkill.contains('-')) {
            detail.skillName = rawSkill.trim();
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

    @TestVisible
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
