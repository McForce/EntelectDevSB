
public with sharing class AcademicRecordPromptHandler {

    public class Request {
        @InvocableVariable(required=true)
        public String json;
    }

    public class Result {
        @InvocableVariable public Id academicRecordId;
        @InvocableVariable public String status;
        @InvocableVariable public String message;
    }

    // DTO must match incoming JSON keys
    public class AcademicRecordDTO {
        public String DocumentType;
        public String AcademicRecordName;
        public String CandidateId;        // Salesforce Id string expected
        public String InstitutionName;
        public String StudentName;
        public String Qualification;
        public String AcademicLevel;
        public String Major;
        public String GraduationDate;      // 'YYYY-MM-DD' or some text like 'Not available'
        public String GraduationStatus;
        public String Average;             // <-- allow number OR string; we'll coerce to Decimal
        public List<String> Modules;
    }

    @InvocableMethod(label='Create Academic Record (Typed JSON)')
    public static List<Result> create(List<Request> requests) {
        System.debug('AcademicRecordPromptHandler.create called with ' + requests.size() + ' request(s)');
        List<Result> results = new List<Result>();
        List<Academic_Record__c> staged = new List<Academic_Record__c>();
        List<Integer> preparedIndices = new List<Integer>();

        for (Integer i = 0; i < requests.size(); i++) {
            Result r = new Result();
            results.add(r);

            try {
                if (requests[i] == null || String.isBlank(requests[i].json)) {
                    r.status = 'Error';
                    r.message = 'JSON payload is blank.';
                    continue;
                }

                
                String rawInput = requests[i].json;

                // Remove any leading/trailing code fences like ```json or ```
                String cleanedJson = rawInput.replaceAll('(?s)```json\\s*', '').replaceAll('(?s)```', '').trim();


                System.debug('Processing request index ' + i + ' raw json: ' + cleanedJson);
                AcademicRecordDTO dto = (AcademicRecordDTO) JSON.deserialize(cleanedJson, AcademicRecordDTO.class);
                System.debug('Deserialized AcademicRecordDTO for index ' + i + ': ' + JSON.serialize(dto));

                Academic_Record__c rec = new Academic_Record__c();

                // Basic required fields (adjust to your org's validation rules)
                rec.Name = dto.AcademicRecordName;
                rec.Institution_Name__c = dto.InstitutionName;
                rec.Qualification__c = dto.Qualification;
                rec.Academic_Level__c = dto.AcademicLevel;
                rec.Graduation_Status__c = dto.GraduationStatus;
                rec.Major__c = dto.Major;

                // Candidate lookup: ensure it looks like an Id (optional check)
                if (!String.isBlank(dto.CandidateId) && looksLikeId(dto.CandidateId)) {
                    rec.Candidate__c = dto.CandidateId;
                } else if (!String.isBlank(dto.CandidateId)) {
                    System.debug(LoggingLevel.WARN, 'CandidateId provided does not look like a Salesforce Id: ' + dto.CandidateId);
                }

                // Average: coerce to Decimal (supports "81.5" string or numeric)
                Decimal avgDec = coerceDecimal(dto.Average);
                rec.Average__c = avgDec;

                // Modules: join list for text area (use '; '), or ';' for multi-select picklist
                if (dto.Modules != null && !dto.Modules.isEmpty()) {
                    rec.Modules__c = String.join(dto.Modules, '; ');
                    System.debug('Joined modules for index ' + i + ': ' + rec.Modules__c);
                }

                System.debug('Prepared Academic_Record__c (before stage) for index ' + i + ': ' + JSON.serialize(rec));
                staged.add(rec);
                preparedIndices.add(i);
                r.status = 'Prepared';
                r.message = 'Record prepared for insert.';
            } catch (Exception e) {
                r.status = 'Error';
                r.message = 'Parsing/Mapping error: ' + e.getMessage();
                System.debug(LoggingLevel.ERROR, 'Error processing request index ' + i + ': ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, e.getStackTraceString());
            }
        }

        if (!staged.isEmpty()) {
            try {
                // Enforce FLS on create (recommended)
                SObjectAccessDecision decision = Security.stripInaccessible(
                    AccessType.CREATABLE,
                    staged
                );
                List<Academic_Record__c> safeToInsert = (List<Academic_Record__c>) decision.getRecords();

                System.debug('About to insert ' + safeToInsert.size() + ' Academic_Record__c record(s): ' + JSON.serialize(safeToInsert));
                insert safeToInsert;

                List<Id> insertedIds = new List<Id>();
                Integer k = 0;
                for (Integer idx : preparedIndices) {
                    results[idx].academicRecordId = safeToInsert[k].Id;
                    insertedIds.add(safeToInsert[k].Id);
                    results[idx].status = 'Success';
                    results[idx].message = 'Academic record created.';
                    k++;
                }
                System.debug('Insert successful. Inserted Ids: ' + JSON.serialize(insertedIds));
            } catch (DmlException dmle) {
                System.debug(LoggingLevel.ERROR, 'DML Exception when inserting Academic_Record__c: ' + dmle.getMessage());
                System.debug(LoggingLevel.ERROR, dmle.getStackTraceString());
                for (Integer idx : preparedIndices) {
                    results[idx].status = 'Error';
                    results[idx].message = dmle.getMessage();
                }
            }
        }

        return results;
    }

    // --- Helpers ---

    private static Boolean looksLikeId(String s) {
        if (String.isBlank(s)) return false;
        // 15 or 18 char, alphanumeric
        Integer len = s.length();
        if (len != 15 && len != 18) return false;
        for (Integer i = 0; i < len; i++) {
            String ch = s.substring(i, i+1);
            if (!Pattern.matches('[A-Za-z0-9]', ch)) return false;
        }
        return true;
    }

    private static Boolean isIsoDate(String s) {
        // Simple check for YYYY-MM-DD
        return Pattern.matches('\\d{4}-\\d{2}-\\d{2}', s);
    }


    /**
     * Coerces JSON value to Decimal. Accepts Decimal, Integer, Long, or String.
     * Returns null if value is null or not parsable.
     */
    private static Decimal coerceDecimal(Object raw) {
        if (raw == null) return null;
        try {
            if (raw instanceof Decimal) return (Decimal) raw;
            if (raw instanceof Integer) return Decimal.valueOf(String.valueOf((Integer) raw));
            if (raw instanceof Long)    return Decimal.valueOf(String.valueOf((Long) raw));
            // JSON may send "81.5" as a string, or even other types—normalize to string
            return Decimal.valueOf(String.valueOf(raw));
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Average value not parsable to Decimal: ' + String.valueOf(raw));
            return null;
        }
    }
}
