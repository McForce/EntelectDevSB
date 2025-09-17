@isTest
private class UpdateCandidateSkillsTest {

    @isTest
    static void testSkillDetailInitialization() {
        UpdateCandidateSkills.SkillDetail detail = new UpdateCandidateSkills.SkillDetail();

        System.assertEquals(0, detail.experience, 'Experience should default to 0');
        System.assertEquals(false, detail.isSpecialty, 'Specialty should default to false');
    }

    @isTest
    static void testUpdateSkillsWithNullRequests() {
        Test.startTest();
        UpdateCandidateSkills.updateSkills(null);
        Test.stopTest();

        // No exception thrown = success
        System.assertEquals(0, [SELECT COUNT() FROM Candidate_Skill__c]);
    }

    @isTest
    static void testParseSkillWithExperienceAndSpecialty() {
        UpdateCandidateSkills.SkillDetail detail = UpdateCandidateSkills.parseSkill('SkillX - 3 years - yes');

        System.assertEquals('SkillX', detail.skillName);
        System.assertEquals(3, detail.experience);
        System.assertEquals(true, detail.isSpecialty);
    }

    @isTest
    static void testParseExperienceWithInvalidInput() {
        Decimal exp = UpdateCandidateSkills.parseExperience('abc');
        System.assertEquals(0, exp, 'Invalid experience should default to 0');
    }

    @isTest
    static void testUpdateCandidateSkillSuccess() {
        // Setup: insert Candidate and an existing Candidate_Skill__c
        Candidate__c candidate = new Candidate__c(Name = 'Test Candidate');
        insert candidate;

        Candidate_Skill__c cs = new Candidate_Skill__c(
            Candidate__c = candidate.Id,
            Name = 'Apex',
            Years_Experience__c = 1,
            Speciality__c = false
        );
        insert cs;

        // Build request to update this skill
        UpdateCandidateSkills.Request req = new UpdateCandidateSkills.Request();
        req.candidateId = candidate.Id;
        req.skillInput = 'Apex - 5 years - yes';

        Test.startTest();
        UpdateCandidateSkills.updateSkills(new List<UpdateCandidateSkills.Request>{ req });
        Test.stopTest();

        // Verify update
        Candidate_Skill__c updated = [
            SELECT Years_Experience__c, Speciality__c
            FROM Candidate_Skill__c
            WHERE Id = :cs.Id
        ];
        System.assertEquals(5, updated.Years_Experience__c, 'Experience should be updated');
        System.assertEquals(true, updated.Speciality__c, 'Specialty should be updated');
    }

    @isTest
    static void testNoUpdateWhenSkillNotFound() {
        Candidate__c candidate = new Candidate__c(Name = 'Another Candidate');
        insert candidate;

        // No Candidate_Skill__c inserted here

        UpdateCandidateSkills.Request req = new UpdateCandidateSkills.Request();
        req.candidateId = candidate.Id;
        req.skillInput = 'NonExistingSkill - 2 years - yes';

        Test.startTest();
        UpdateCandidateSkills.updateSkills(new List<UpdateCandidateSkills.Request>{ req });
        Test.stopTest();

        // Since no match existed, nothing should be updated or inserted
        System.assertEquals(0, [SELECT COUNT() FROM Candidate_Skill__c]);
    }
}
