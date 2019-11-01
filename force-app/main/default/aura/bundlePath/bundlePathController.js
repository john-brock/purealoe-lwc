({
    subscribe: function(component, event) {
        var empApi = component.find('empApi');
        var channel = component.get('v.channel');
        var replayId = -1;
        empApi.subscribe(
            channel,
            replayId,
            $A.getCallback(function(message) {
                console.log(message);
                console.log(message.data.payload.ChangeEventHeader.recordIds[0]);
                console.log(message.data.payload.Status__c);
                var bundle = component.get('v.record');
                if (message && message.data && message.data.payload && message.data.payload.ChangeEventHeader.recordIds[0]) {
                    var bundleId = message.data.payload.ChangeEventHeader.recordIds[0];
                    var status = message.data.payload.Status__c;
                    if (bundleId === bundle.Id && status !== bundle.Status__c) {
                        console.log('Reload requested');
                        component.find('bundleRecord').reloadRecord(true);
                    }
                }
            })
        );
    },

    onStepChange: function(component, event) {
        var bundle = component.get('v.record');
        if (bundle) {
            bundle.Status__c = event.getParam('step');
            component
                .find('bundleRecord')
                .saveRecord($A.getCallback(function(saveResult) {}));
        }
    },

    onRecordUpdated: function(component, event) {
        var changeType = event.getParams().changeType;
        if (changeType === 'LOADED') {
            component.find('accountService').reloadRecord();
        } else if (changeType === 'CHANGED') {
            component.find('bundleRecord').reloadRecord();
            component.find('accountService').reloadRecord();
        }
    }
});