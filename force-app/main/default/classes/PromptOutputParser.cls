public class PromptOutputParser {
    
    // Inner wrapper class to hold the parsed and enriched candidate data
    public class CandidateMatch {
        @AuraEnabled public String fullName { get; set; }
        @AuraEnabled public String candidateLink { get; set; } // This will be the value from Candidate_Link__c
        @AuraEnabled public String resumeSummary { get; set; }
        @AuraEnabled public Integer matchScore { get; set; }
    }
    
    // Invocable method to be called from Flow
    @InvocableMethod(label='Parse Prompt Output' description='Parses JSON prompt response and returns a collection of candidate matches')
    public static List<List<CandidateMatch>> parsePromptOutput(List<String> promptResponses) {
        List<List<CandidateMatch>> results = new List<List<CandidateMatch>>();
        
        for (String promptResponse : promptResponses) {
            List<CandidateMatch> matches = new List<CandidateMatch>();
            
            // Parse the JSON string
            Map<String, Object> jsonData = (Map<String, Object>) JSON.deserializeUntyped(promptResponse);
            List<Object> candidatesJson = (List<Object>) jsonData.get('candidates');
            
            // Collect candidate IDs for querying
            Set<Id> candidateIds = new Set<Id>();
            Map<String, Object> candidateMap = new Map<String, Object>(); // Temp map to hold JSON data by ID
            for (Object candObj : candidatesJson) {
                Map<String, Object> cand = (Map<String, Object>) candObj;
                String candId = (String) cand.get('candidateId');
                candidateIds.add(candId);
                candidateMap.put(candId, cand);
            }
            
            // Query actual Candidate records to get Candidate_Link__c (and any other fields if needed)
            Map<Id, Candidate__c> candidateRecords = new Map<Id, Candidate__c>([
                SELECT Id, Name, Candidate_Link__c 
                FROM Candidate__c 
                WHERE Id IN :candidateIds
            ]);
            
            // Build the output collection, enriching with real data
            for (Id candId : candidateIds) {
                Candidate__c record = candidateRecords.get(candId);
                Map<String, Object> jsonCand = (Map<String, Object>) candidateMap.get(candId);
                
                if (record != null && jsonCand != null) {
                    CandidateMatch match = new CandidateMatch();
                    match.fullName = (String) jsonCand.get('fullName'); // Or use record.Name if you prefer the real name
                    match.candidateLink = record.Candidate_Link__c; // Formula field link
                    match.resumeSummary = (String) jsonCand.get('resumeSummary');
                    match.matchScore = (Integer) jsonCand.get('matchScore');
                    matches.add(match);
                }
            }
            
            results.add(matches);
        }
        
        return results;
    }
}