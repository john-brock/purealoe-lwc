public class TwilioSmsUtil {

    @InvocableMethod(label='Send SMS' description='Sends a text message to the toNumber with the body as the message.')
    public static void sendSMS(List<SmsMessage> messages) {
        Twilio_Auth_Setting__mdt twilioWhatsApp = [SELECT Account_SID__c, Account_Phone__c, Named_Cred_API_Name__c, Use_Whatsapp__c FROM Twilio_Auth_Setting__mdt WHERE DeveloperName='JB_Twilio_WhatsApp'];
        Twilio_Auth_Setting__mdt twilioSms = [SELECT Account_SID__c, Account_Phone__c, Named_Cred_API_Name__c, Use_Whatsapp__c FROM Twilio_Auth_Setting__mdt WHERE DeveloperName='JB_Twilio'];
        for (SmsMessage message : messages) {
            Contact customer = [SELECT Id, Name, Phone, SMS_Opt_Out__c FROM Contact where AccountId =: message.accountId LIMIT 1];
            if (customer.SMS_Opt_Out__c) {
                // use WhatsApp
                makeCallout(twilioWhatsApp.Named_Cred_API_Name__c, twilioWhatsApp.Account_SID__c, buildEntityBody(buildBodyParamMap(true, customer.Phone, twilioWhatsApp.Account_Phone__c, message.body)));            
            } else {
                // use SMS 
                makeCallout(twilioSms.Named_Cred_API_Name__c, twilioSms.Account_SID__c, buildEntityBody(buildBodyParamMap(false, customer.Phone, twilioSms.Account_Phone__c, message.body)));            
            }
        }
    }
    
    @future(callout=true)
    private static void makeCallout(String namedCredName, String accountSid, String postBody) {
        System.debug(postBody);
        HttpRequest req = new HttpRequest(); 
        req.setEndpoint('callout:' + namedCredName + '/2010-04-01/Accounts/' + accountSid + '/Messages.json');
        req.setMethod('POST');
        req.setHeader('Content-Type','application/x-www-form-urlencoded');
        req.setBody(postBody);
        Http http = new Http();
        HTTPResponse res = http.send(req);
        System.debug(res.getBody());        
    }

    private static Map<String, String> buildBodyParamMap(Boolean useWhatsapp, String toNumber, String fromNumber, String body) {
        final String toNumString = useWhatsapp ? 'whatsapp:' + toNumber : toNumber;
        final String fromNumString = useWhatsapp ? 'whatsapp:' + fromNumber : fromNumber;
        System.debug('TO NUM: ' + toNumString);
        System.debug('FROM NUM: ' + toNumString);
        Map<String, String> requestBody = new Map<String, String> {
            'To' => toNumString,
            'From' => fromNumString,
            'Body' => body
        };
        System.debug(requestBody);
        return requestBody;
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