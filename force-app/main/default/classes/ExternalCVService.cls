public class ExternalCVService {
    public static Boolean sendCV(Blob cvBlob, String fileName, Id candidateId) {
        System.debug('ExternalCVService.sendCV invoked. fileName=' + fileName + ', candidateId=' + candidateId);
        // Construct the request
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Salesforce_Docker/cv/upload/' + candidateId);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/pdf');
        req.setHeader('Content-Disposition', 'attachment; filename="' + fileName + '"');
        req.setBodyAsBlob(cvBlob);

        // Send the callout
        Http http = new Http();
        HttpResponse res;
        try {
            res = http.send(req);
        } catch (Exception e) {
            System.debug('Error sending CV: ' + e.getMessage());
            return false;
        }

        // Debug response for testing
        System.debug('Response Status: ' + res.getStatus());
        System.debug('Response Body: ' + res.getBody());

        // Check for success
        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            return true;
        }
        return false;
    }
}
