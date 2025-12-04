@IsTest
private class AcademicRecordPromptHandlerTest {
    @IsTest
    static void testCreateSingleRecord() {
        // Create a candidate (if lookup is required)
        Candidate__c cand = new Candidate__c(Name = 'Test Candidate');
        insert cand;

        String payload = JSON.serialize(new Map<String, Object>{
            'DocumentType' => 'Transcript',
            'AcademicRecordName' => 'BSc Computer Science',
            'CandidateId' => cand.Id,
            'InstitutionName' => 'UCT',
            'StudentName' => 'John Doe',
            'Qualification' => 'BSc CS',
            'AcademicLevel' => 'Undergraduate',
            'GraduationDate' => '2022-11-30',
            'GraduationStatus' => 'Graduated',
            'Average' => 75,
            'Modules' => new List<String>{ 'Computer Science', 'Mathematics' }
        });

        AcademicRecordPromptHandler.Request req = new AcademicRecordPromptHandler.Request();
        req.json = payload;

        Test.startTest();
        List<AcademicRecordPromptHandler.Result> res =
            AcademicRecordPromptHandler.create(new List<AcademicRecordPromptHandler.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals('Success', res[0].status, res[0].message);
        System.assertNotEquals(null, res[0].academicRecordId);

        Academic_Record__c ar = [SELECT Name, Candidate__c, Institution_Name__c, Academic_Level__c, Graduation_Status__c, Modules__c, Average__c, Qualification__c
                                 FROM Academic_Record__c WHERE Id = :res[0].academicRecordId];

        System.assertEquals('BSc Computer Science', ar.Name);
        System.assertEquals(cand.Id, ar.Candidate__c);
        System.assertEquals('UCT', ar.Institution_Name__c);
        System.assertEquals('Undergraduate', ar.Academic_Level__c);
        System.assertEquals('Graduated', ar.Graduation_Status__c);
        System.assertEquals('Computer Science; Mathematics', ar.Modules__c);
        System.assertEquals(75, ar.Average__c);
        System.assertEquals('BSc CS', ar.Qualification__c);
        
    }
}
