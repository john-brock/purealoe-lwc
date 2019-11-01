public class TwilioSmsUtil {

    @InvocableMethod(label='Send SMS' description='Sends a text message to the toNumber with the body as the message.')
    public static void sendSMS(List<SmsMessage> messages) {
        Twilio_Auth_Setting__mdt twilio = [SELECT Account_SID__c, Account_Phone__c, Named_Cred_API_Name__c FROM Twilio_Auth_Setting__mdt WHERE DeveloperName='JB_Twilio'];
        for (SmsMessage message : messages) {
	        Contact customer = [SELECT Id, Name, Phone FROM Contact where AccountId =: message.accountId LIMIT 1];
        	makeCallout(twilio.Named_Cred_API_Name__c, twilio.Account_SID__c, buildEntityBody(buildBodyParamMap(customer.Phone, twilio.Account_Phone__c, message.body)));            
        }
    }
    
    @future(callout=true)
    private static void makeCallout(String namedCredName, String accountSid, String postBody) {
        HttpRequest req = new HttpRequest(); 
        req.setEndpoint('callout:' + namedCredName + '/2010-04-01/Accounts/' + accountSid + '/Messages.json');
        req.setMethod('POST');
		req.setHeader('Content-Type','application/x-www-form-urlencoded');
        req.setBody(postBody);
        Http http = new Http();
        HTTPResponse res = http.send(req);
        System.debug(res.getBody());        
    }

    private static Map<String, String> buildBodyParamMap(String toNumber, String fromNumber, String body) {
        return new Map<String, String> {
            'To' => toNumber,
            'From' => fromNumber,
            'Body' => body
        };
    }
    
    private static String buildEntityBody(Map<String,String> params) {
        String entityBody='';
        if (params != null) {
            for (String key : params.keySet()) {
                try {
                    entityBody += (entityBody=='' ? '' : '&')
                                    + key + '=' + EncodingUtil.urlEncode(params.get(key), 'UTF-8');
                } catch (Exception e) {
                    System.debug('ERROR: ' + e);
                }
            }
        }
        return entityBody;
    }
    
    public class SmsMessage {
        @InvocableVariable
        public Id accountId;
    
        @InvocableVariable
        public String body;
  	}
}