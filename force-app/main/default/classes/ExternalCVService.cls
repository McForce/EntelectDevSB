public class ExternalCVService {
    public static Boolean sendCV(Blob cvBlob, String fileName) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:ExternalService/cv/analyze');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/pdf');
        req.setBodyAsBlob(cvBlob);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            return true;
        }
        return false;
    }
}
