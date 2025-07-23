@IsTest
private class ContentDocumentLinkTriggerTest {
    @TestSetup
    static void setupTestData() {
        // Create test Candidate
        Candidate__c testCandidate = new Candidate__c(
            Name = 'Test Candidate'
            // Add other required fields
        );
        insert testCandidate;
    }
    
    @IsTest
    static void testSingleDocumentAttachment() {
        // Get the test candidate
        Candidate__c testCandidate = [SELECT Id FROM Candidate__c LIMIT 1];
        
        // Create ContentVersion (required for ContentDocument)
        ContentVersion cv = new ContentVersion(
            Title = 'Test CV',
            PathOnClient = 'TestCV.pdf',
            VersionData = Blob.valueOf('Test CV Content')
        );
        insert cv;
        
        // Get ContentDocument Id
        Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        
        Test.startTest();
        
        // Create ContentDocumentLink
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = conDocId,
            LinkedEntityId = testCandidate.Id,
            ShareType = 'V'
        );
        insert cdl;
        
        Test.stopTest();
        
        // Verify the CV Title was updated
        Candidate__c updatedCandidate = [SELECT CV_Title__c FROM Candidate__c WHERE Id = :testCandidate.Id];
        System.assertEquals('Test CV', updatedCandidate.CV_Title__c, 'CV Title should be updated with document title');
    }
    
    @IsTest
    static void testBulkDocumentAttachment() {
        // Get the test candidate
        Candidate__c testCandidate = [SELECT Id FROM Candidate__c LIMIT 1];
        
        // Create multiple ContentVersions
        List<ContentVersion> cvs = new List<ContentVersion>();
        for (Integer i = 1; i <= 3; i++) {
            cvs.add(new ContentVersion(
                Title = 'Test CV ' + i,
                PathOnClient = 'TestCV' + i + '.pdf',
                VersionData = Blob.valueOf('Test CV Content ' + i)
            ));
        }
        insert cvs;
        
        // Get ContentDocument Ids
        List<Id> conDocIds = new List<Id>();
        for (ContentVersion cv : [SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :cvs]) {
            conDocIds.add(cv.ContentDocumentId);
        }
        
        Test.startTest();
        
        // Create ContentDocumentLinks
        List<ContentDocumentLink> cdls = new List<ContentDocumentLink>();
        for (Id conDocId : conDocIds) {
            cdls.add(new ContentDocumentLink(
                ContentDocumentId = conDocId,
                LinkedEntityId = testCandidate.Id,
                ShareType = 'V'
            ));
        }
        insert cdls;
        
        Test.stopTest();
        
        // Verify the CV Title was updated with the last document
        Candidate__c updatedCandidate = [SELECT CV_Title__c FROM Candidate__c WHERE Id = :testCandidate.Id];
        System.assertEquals('Test CV 3', updatedCandidate.CV_Title__c, 'CV Title should be updated with last document title');
    }
    
    @IsTest
    static void testNonCandidateAttachment() {
        // Create a test Account (non-Candidate object)
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'Test Document',
            PathOnClient = 'TestDoc.pdf',
            VersionData = Blob.valueOf('Test Content')
        );
        insert cv;
        
        // Get ContentDocument Id
        Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        
        Test.startTest();
        
        // Create ContentDocumentLink for non-Candidate object
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = conDocId,
            LinkedEntityId = testAccount.Id,
            ShareType = 'V'
        );
        insert cdl;
        
        Test.stopTest();
        
        // Verify no errors occurred
        System.assert(true, 'Should not throw any errors for non-Candidate attachments');
    }
}