public with sharing class CandidateSkillsFromText {
    public class Input {
        @InvocableVariable(required=true) public Id candidateId;
        @InvocableVariable(required=false) public String skillsText;
    }
    public class Output {
        @InvocableVariable public Id candidateId;
        @InvocableVariable public Integer createdCount;
        @InvocableVariable public List<String> unmatchedSkills;
        @InvocableVariable public List<String> errors;
        @InvocableVariable public String message;
    }

    @InvocableMethod(
        label='Sync Candidate Skills from Text'
        description='Parses a Candidate skills text and creates Candidate_Skill__c records for matching Skill__c by Name.'
    )
    public static List<Output> sync(List<Input> inputs) {
        List<Output> outs = new List<Output>();
        if (inputs == null || inputs.isEmpty()) return outs;

        // Build per-candidate token sets and union of all tokens
        Map<Id, Set<String>> candToTokens = new Map<Id, Set<String>>();
        Set<String> allTokens = new Set<String>();
        Set<Id> candidateIds = new Set<Id>();

        for (Input req : inputs) {
            if (req == null || req.candidateId == null) continue;
            candidateIds.add(req.candidateId);
            Set<String> tokens = tokenize(req.skillsText);
            candToTokens.put(req.candidateId, tokens);
            allTokens.addAll(tokens);
        }

// Map normalized skill name -> Skill__c
Map<String, Skill__c> nameToSkill = new Map<String, Skill__c>();
for (Skill__c s : [SELECT Id, Name FROM Skill__c]) {
    nameToSkill.put(normalize(s.Name), s);
}

        // Collect all skill Ids referenced
        Set<Id> allSkillIds = new Set<Id>();
        for (Set<String> tokens : candToTokens.values()) {
            for (String token : tokens) {
                Skill__c s = nameToSkill.get(normalize(token));
                if (s != null) allSkillIds.add(s.Id);
            }
        }

        // Existing junctions by Candidate
        Map<Id, Set<Id>> existingByCand = new Map<Id, Set<Id>>();
        if (!candidateIds.isEmpty() && !allSkillIds.isEmpty()) {
            for (Candidate_Skill__c cs : [
                SELECT Id, Candidate__c, Skill__c
                FROM Candidate_Skill__c
                WHERE Candidate__c IN :candidateIds AND Skill__c IN :allSkillIds
            ]) {
                Set<Id> setForCand = existingByCand.get(cs.Candidate__c);
                if (setForCand == null) {
                    setForCand = new Set<Id>();
                    existingByCand.put(cs.Candidate__c, setForCand);
                }
                setForCand.add(cs.Skill__c);
            }
        }

        // Prepare inserts
        List<Candidate_Skill__c> toInsert = new List<Candidate_Skill__c>();
        List<Id> ownerCandForRow = new List<Id>();

        Map<Id, List<String>> unmatchedByCandidate = new Map<Id, List<String>>();

        for (Id candId : candToTokens.keySet()) {
            Set<String> tokens = candToTokens.get(candId);
            if (tokens == null || tokens.isEmpty()) {
                continue;
            }
            Set<Id> existingSkills = existingByCand.containsKey(candId) ? existingByCand.get(candId) : new Set<Id>();

            for (String token : tokens) {
                Skill__c skill = nameToSkill.get(normalize(token));
                if (skill == null) {
                    List<String> unmatched = unmatchedByCandidate.get(candId);
                    if (unmatched == null) { unmatched = new List<String>(); unmatchedByCandidate.put(candId, unmatched); }
                    unmatched.add(token);
                    continue;
                }
                if (existingSkills.contains(skill.Id)) {
                    continue; // already linked
                }

                Candidate_Skill__c jxn = new Candidate_Skill__c();
                jxn.Candidate__c = candId;
                jxn.Skill__c = skill.Id;

                // If Name is an Auto Number, this will throw and we ignore it.
                try {
                    jxn.put('Name', skill.Name);
                } catch (Exception ignore) {}

                toInsert.add(jxn);
                ownerCandForRow.add(candId);
                existingSkills.add(skill.Id); // prevent dupes within this run
            }
        }

        // DML with partial success
        Map<Id, Integer> actualCreatedCounts = new Map<Id, Integer>();
        Map<Id, List<String>> errorsByCand = new Map<Id, List<String>>();

        if (!toInsert.isEmpty()) {
            Database.SaveResult[] srs = Database.insert(toInsert, false);
            for (Integer i = 0; i < srs.size(); i++) {
                Id candId = ownerCandForRow[i];
                if (srs[i].isSuccess()) {
                    actualCreatedCounts.put(candId, (actualCreatedCounts.get(candId) == null ? 1 : actualCreatedCounts.get(candId) + 1));
                } else {
                    for (Database.Error err : srs[i].getErrors()) {
                        List<String> errs = errorsByCand.get(candId);
                        if (errs == null) { errs = new List<String>(); errorsByCand.put(candId, errs); }
                        errs.add(err.getStatusCode() + ': ' + err.getMessage());
                    }
                }
            }
        }

        // Build outputs (preserve input order)
        for (Input req : inputs) {
            if (req == null || req.candidateId == null) continue;

            Output outRec = new Output();
            outRec.candidateId = req.candidateId;
            outRec.createdCount = actualCreatedCounts.containsKey(req.candidateId) ? actualCreatedCounts.get(req.candidateId) : 0;
            outRec.unmatchedSkills = unmatchedByCandidate.containsKey(req.candidateId) ? unmatchedByCandidate.get(req.candidateId) : new List<String>();
            outRec.errors = errorsByCand.containsKey(req.candidateId) ? errorsByCand.get(req.candidateId) : new List<String>();

            Set<String> parsed = candToTokens.get(req.candidateId);
            if (parsed == null || parsed.isEmpty()) {
                outRec.message = 'No skills parsed from text.';
            } else if (!outRec.errors.isEmpty()) {
                outRec.message = 'Completed with errors.';
            } else {
                outRec.message = 'Success.';
            }
            outs.add(outRec);
        }
        return outs;
    }

    // Split on common delimiters: comma, semicolon, pipe, newline, tab
    private static Set<String> tokenize(String raw) {
        Set<String> tokens = new Set<String>();
        if (String.isBlank(raw)) return tokens;
        List<String> parts = raw.split('[,;|\\n\\r\\t]+');
        for (String part : parts) {
            if (part == null) continue;
            String t = part.trim();
            if (t.length() == 0) continue;
            t = t.replaceAll('\\s+', ' ');
            tokens.add(t);
        }
        return tokens;
    }
private static String normalize(String s) {
    if (s == null) return null;
    String noParen = stripParentheticals(s);
    noParen = noParen.replaceAll('\\s+', ' ').trim(); // collapse whitespace
    return noParen.toLowerCase();
}

private static String stripParentheticals(String s) {
    if (s == null) return null;
    Integer depth = 0;
    String out = '';
    for (Integer i = 0; i < s.length(); i++) {
        String ch = s.substring(i, i+1);
        if (ch == '(') {
            depth++;
        } else if (ch == ')') {
            if (depth > 0) depth--;
        } else if (depth == 0) {
            out += ch;
        }
    }
    return out;
}
}