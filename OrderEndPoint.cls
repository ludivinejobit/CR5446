/*
Order custom API to insert/update order 
    Class Name: OrderEndPoint
    Created by: Brajesh Kumar
    Created Date: 6th November 2023
*/
@RestResource(urlMapping='/api/Order/*')
global class OrderEndPoint {
    private static final string ORDER_UNIQUE_ID_IS_MISSING = 'Order Unique Id cannot be blank';
    public static EndpointUtils.responseWrapper response;
    public static List<EndpointUtils.responseWrapper> jsonResponse = new List<EndpointUtils.responseWrapper>();
    public static Map<Object, Object> operationOnRecord = new Map<Object, Object>();
    public static final Id SALES_ORDER_RECORDTYPE_ID = Schema.SObjectType.Order.getRecordTypeInfosByDeveloperName().get('Sales_Order').getRecordTypeId();
    public static final Id SALES_ORDER_ITEM_RECORDTYPE_ID = Schema.SObjectType.Order_Item__c.getRecordTypeInfosByDeveloperName().get('Sales_Order_Item').getRecordTypeId();
    public static final Id SALES_ORDER_SCHEDULE_RECORDTYPE_ID = Schema.SObjectType.Order_Schedule_Line__c.getRecordTypeInfosByDeveloperName().get('Order_Schedule_Line').getRecordTypeId();

    @HttpPost 
    global static List<EndpointUtils.responseWrapper> processSalesOrder() {
        List<EndpointUtils.responseWrapper> jsonResponse = new List<EndpointUtils.responseWrapper>();
        EndpointUtils.responseWrapper response;
        List<Order> ordersToUpsert = new List<Order>();
        List<Order_Item__c> orderLineItemToUpsert = new List<Order_Item__c>();
        List<Order_Schedule_Line__c> orderScheduleLineToUpsert = new List<Order_Schedule_Line__c>();
        List<Order_Item__c> orderLineWithOrderNumber;
        List<Order_Schedule_Line__c> orderScheduleWithOrderItem;
        Map<String,List<Order_Item__c>> orderWithLineMap = new Map<String,List<Order_Item__c>>();
        Map<String,List<Order_Schedule_Line__c>> orderWithLineSHMap = new Map<String,List<Order_Schedule_Line__c>>();
        Map<String,List<Order_Schedule_Line__c>> orderWithScheduleMap = new Map<String,List<Order_Schedule_Line__c>>();
        List<Map<String, Object>> parsedData = new List<Map<String, Object>>();
        Set<String> itemIdsToDelete = new Set<String>();
        Set<String> orderToDelete = new Set<String>();
        Set<String> scheduleIdsToDelete = new Set<String>();
        Set<String> caseIDs = new Set<String>();
        Boolean orderConfirmed;
        //Map<String, Boolean> mapConfirmedOI = new Map<String, Boolean>(); //HotFix PROD BUG-5186
        Set<String> decimalFields = new Set<String>{
            'convnetval__c', 'netvalue__c', 'quantity__c', 'orderqtym2__c', 'convnetval1__c',
            'quantityuom__c', 'firstquantityuom__c', 'firstquantitym2__c', 'totcumqty__c',
            'netprice__c', 'netvalue__c', 'netvalue1__c', 'unitprice__c',
            'schlqty__c', 'schlqtym2__c', 'confqty__c', 'confqtym2__c', 'quantity__c', 'orderqtym2__c'
        };
        
        //Lookup Map and List
        List<String> accountList = new List<String>();
        List<String> productList = new List<String>();
        List<String> orderList = new List<String>();
		List<String> orderItemList = new List<String>();
        List<String> invoiceList = new List<String>();
		List<String> invoiceItemList = new List<String>();

        // Order line Salesforce Ids for remove schedule lines
        Set<String> orderLineItemInsertedIds = new Set<String>();

        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        System.debug('req::-' + req);

        //START CHUNK APPROACH
        Blob requestBodyBlob = req.requestBody;
        String jsonString = '';
        if (requestBodyBlob != null) {
            jsonString = requestBodyBlob.toString();
        }
        System.debug('Request Body: ' + jsonString);
        //END CHUNK APPROACH

        //Deserialize the JOSN Payload 
        Map<String,Object> deserialized = (Map<String,Object>)JSON.deserializeUntyped(jsonString);
        System.debug('deserialized:-' + deserialized);
        
        for(Object instance : (List<Object>)deserialized.get('Order'))
            parsedData.add((Map<String, Object>)instance);  
        
        //Iterate through each order in the JSON array
        for(Map<String, Object> itrParsedData : parsedData)  {  
            Order newOrderList = new Order();
            Map<String, Boolean> mapConfirmedOI = new Map<String, Boolean>(); //HotFix PROD BUG-5186
            orderScheduleWithOrderItem = new List<Order_Schedule_Line__c>();
            for(String itrJSONField : itrParsedData.keySet())    { 
                orderLineWithOrderNumber = new List<Order_Item__c>(); 
                String fieldName = itrJSONField;
                Object fieldValue = itrParsedData.get(itrJSONField);
                if(fieldName != 'SOHEADTOITEM' && fieldName != 'Operation_Type'){
                    if(fieldName == 'EffectiveDate' || fieldName == 'EndDate' || fieldName == 'CreatedOn__c' || 
                       fieldName == 'RequestedDate__c' || fieldName == 'ConfirmedDate__c' || fieldName == 'MaterialAvaDate__c'){
                        if(!String.isBlank(String.valueof(fieldValue)) && !String.isEmpty(String.valueof(fieldValue))){
                            try {
                                // Converte la stringa in un oggetto Date
                                Date dateValue = Date.valueOf(String.valueof(fieldValue));
                                // Comment debug // System.debug('@@@ dateValue: '+ dateValue + 'of dateString: ' + String.valueof(fieldValue));
                                newOrderList.put(fieldName,dateValue);
                            } catch (Exception e) {
                                // Comment debug // System.debug('@@@ dateValue conversion error: ' + e.getMessage());
                                newOrderList.put(fieldName, null);
                            }
                        }
                    }
                    else if(fieldName == 'Shiptoparty_gid__c' || fieldName == 'Soldtoparty_gid__c' || fieldName == 'Billtoparty_gid__c'){
                        if(!String.isBlank(String.valueof(fieldValue)) && !String.isEmpty(String.valueof(fieldValue))){
                            accountList.add(String.valueof(fieldValue));
                            newOrderList.put(fieldName, String.valueof(fieldValue));
                        }
                    }
                    else if(decimalFields.contains(fieldName.toLowerCase())){
                        newOrderList.put(fieldName, Decimal.valueof(String.valueof(fieldValue)));
                    }
                    else if(fieldName == 'CaseID__c'){
                        if(!String.isBlank(String.valueof(fieldValue)) && !String.isEmpty(String.valueof(fieldValue))){
                            if(fieldValue != 'Not applicable' && fieldValue != 'N/A'){ newOrderList.put(fieldName,String.valueof(fieldValue)); caseIDs.add(String.valueof(fieldValue));}
                        }
                    }
                    else if(fieldName == 'Delindicator__c' && fieldValue != null){
                        if(fieldValue == 'D'){
                            String orderId = String.valueOf(itrParsedData.get('SalesDocNumber__c'));
                            if (orderId != null) { orderToDelete.add(orderId); }
                        }
                    }
                    // Number range fix
                    else if(fieldName == 'SalesDocNumber__c'){
                        String val = String.valueOf(fieldValue);
                        newOrderList.put(fieldName, val);
                        if(val.contains('?')) {
                            List<String> parts = val.split('\\?');
                            if(parts.size() > 1) {
                                newOrderList.put('SalesDocNumber_layout__c', parts[1]);
                            }
                        } else {
                            newOrderList.put('SalesDocNumber_layout__c', val);
                        }
                    }
                    else
                        newOrderList.put(fieldName, fieldValue);
                }
                else if(fieldName != 'SOHEADTOITEM' && fieldName == 'Operation_Type'){
                    operationOnRecord.put(itrParsedData.get('SalesDocNumber__c'), fieldValue);
                    if (fieldValue == 'insert') {
                        newOrderList.put('Status', 'Open');
                    }
                }
            }
            /*if(!orderToDelete.contains(newOrderList.SalesDocNumber__c)){
                ordersToUpsert.add(newOrderList);
            }*/
            
            //Access and process Order Lines
            List<Object> orderLines = (List<Object>)itrParsedData.get('SOHEADTOITEM');
            System.debug('orderLines:-'+ orderLines);
            //Iterate orderLineItem
            for (Object itemObj : orderLines) {
                orderConfirmed = false;
                Map<String, Object> itrOrderListLine = (Map<String, Object>) itemObj;
                System.debug('itrOrderListLine:-'+ itrOrderListLine);
                Order_Item__c orderLineItem = new Order_Item__c();
                List<Object> orderScheduleList = (List<Object>)itrOrderListLine.get('ORDERSCHEDULE');
                
                for(String itrChildJSONField : itrOrderListLine.keySet()){ 
                    String childFieldName = itrChildJSONField;
                    Object childFieldValue = itrOrderListLine.get(itrChildJSONField);
                    
                    if(childFieldName != 'ORDERSCHEDULE' && childFieldName != 'Operation_Type'){
                        if(childFieldName == 'ConfirmedDate__c' || childFieldName == 'MaterialAvaDate__c' || childFieldName == 'RequestedDate__c'){
                            if(!String.isBlank(String.valueof(childFieldValue)) && !String.isEmpty(String.valueof(childFieldValue))){
                                try {
                                    // Converte la stringa in un oggetto Date
                                    Date dateValue = Date.valueOf(String.valueof(childFieldValue));
                                    // Comment debug // System.debug('@@@ dateValue: '+ dateValue + 'of dateString: ' + String.valueof(childFieldValue));
                                    orderLineItem.put(childFieldName,dateValue);
                                } catch (Exception e) {
                                    // Comment debug // System.debug('@@@ dateValue conversion error: ' + e.getMessage());
                                    orderLineItem.put(childFieldName, null);
                                }
                            }
                        }
                        else if(decimalFields.contains(childFieldName.toLowerCase())){
                            orderLineItem.put(childFieldName, Decimal.valueof(String.valueof(childFieldValue)));
                        }
                        else if(childFieldName == 'Amcormatnum__c' && childFieldValue != null){
                            if(!String.isBlank(String.valueof(childFieldValue)) && !String.isEmpty(String.valueof(childFieldValue))){
                                String matVal = String.valueof(childFieldValue);
                                productList.add(matVal);
                                orderLineItem.put(childFieldName, matVal);
                                if(matVal.contains('?')) {
                                    List<String> matParts = matVal.split('\\?');
                                    if(matParts.size() > 1) {
                                        orderLineItem.put('Amcor_Material_Number__c', matParts[1]);
                                    }
                                } else {
                                    orderLineItem.put('Amcor_Material_Number__c', matVal);
                                }
                            }
                        }
                        else if(childFieldName == 'ReferenceLineItem__c'){
                            if(!String.isBlank(String.valueof(childFieldValue)) && !String.isEmpty(String.valueof(childFieldValue))){
                                //if (String.valueof(childFieldValue).startsWith('INV')) {
                                if (String.valueof(childFieldValue).contains('?INV')) {
                                    String originalString = String.valueOf(childFieldValue);
                                    String cleanReferenceDocument = originalString.replace('?INV', '?');
                                    System.debug('@@@@@COSA STO INSERENDO ITEM? ' + cleanReferenceDocument);
                                    invoiceItemList.add(cleanReferenceDocument);
                                    orderLineItem.put('ReferenceInvoiceItem__c', cleanReferenceDocument);
                                } else {
                                    orderItemList.add(String.valueof(childFieldValue));
                                    orderLineItem.put(childFieldName, String.valueof(childFieldValue));
                                }
                            }
                        }
                        else if(childFieldName == 'ReferenceDocument__c'){
                            if(!String.isBlank(String.valueof(childFieldValue)) && !String.isEmpty(String.valueof(childFieldValue))){
                                //if (String.valueof(childFieldValue).startsWith('INV')) {
                                if (String.valueof(childFieldValue).contains('?INV')) {
                                    String originalString = String.valueOf(childFieldValue);
                                    String cleanReferenceDocument = originalString.replace('?INV', '?');
                                    System.debug('@@@@@COSA STO INSERENDO ? ' + cleanReferenceDocument);
                                    invoiceList.add(cleanReferenceDocument);
                                    orderLineItem.put('ReferenceInvoice__c', cleanReferenceDocument);
                                } else {
                                    orderList.add(String.valueof(childFieldValue));
                                    orderLineItem.put(childFieldName, String.valueof(childFieldValue));
                                }
                            }
                        }
                        else if(childFieldName == 'Soldtoparty_gid__c' || childFieldName == 'Shiptoparty_gid__c' || 
                                childFieldName == 'Billtoparty_gid__c'){
                            if(!String.isBlank(String.valueof(childFieldValue)) && !String.isEmpty(String.valueof(childFieldValue))){
                                accountList.add(String.valueof(childFieldValue));
                                orderLineItem.put(childFieldName, String.valueof(childFieldValue));
                            }
                        }
                        else if(childFieldName == 'Delindicator__c' && childFieldValue != null){
                            if(childFieldValue == 'D'){
                                String itemId = String.valueOf(itrOrderListLine.get('Order_Line_Azure_Id__c'));
                                if (itemId != null) {
                                    itemIdsToDelete.add(itemId);
                                }
                            }
                        }
                        // Number range fix
                        else if(childFieldName == 'Order_Line_Azure_Id__c'){
                            String val = String.valueOf(childFieldValue);
                            orderLineItem.put(childFieldName, val);
                            if(val.contains('?')) {
                                List<String> parts = val.split('\\?');
                                if(parts.size() > 1) {
                                    orderLineItem.put('Order_Line_Azure_Id_layout__c', parts[1]);
                                }
                            } else {
                                orderLineItem.put('Order_Line_Azure_Id_layout__c', val);
                            }
                        }
                        else
                            orderLineItem.put(childFieldName, childFieldValue);
                    }
                }
                orderLineItemInsertedIds.add(orderLineItem.Order_Line_Azure_Id__c);

                if(!itemIdsToDelete.contains(orderLineItem.Order_Line_Azure_Id__c)){
                    orderLineItemToUpsert.add(orderLineItem);  
                    orderLineWithOrderNumber.add(orderLineItem);
                }

                // Process Schedule Lines for each Order Item
                if(orderScheduleList != null && !orderScheduleList.isEmpty()) {
                    Decimal sumConfirmedQty = 0;
                    Decimal totalQty;
                    for (Object scheduleObj : orderScheduleList) {
                        Map<String, Object> itrScheduleLine = (Map<String, Object>) scheduleObj;
                        Order_Schedule_Line__c scheduleLine = new Order_Schedule_Line__c();

                        for(String scheduleField : itrScheduleLine.keySet()) {
                            Object scheduleValue = itrScheduleLine.get(scheduleField);
                            
                            /*if(scheduleField == 'Quantity__c'){totalQty = Double.valueOf(scheduleValue); System.debug('###Current Total Quantity: ' + totalQty);}
                            if(scheduleField == 'Confqty__c'){sumConfirmedQty = sumConfirmedQty+Double.valueOf(scheduleValue); System.debug('###Current Sum Schedule Line Quantity: ' + sumConfirmedQty);}*/
                            
                            if(scheduleField == 'Quantity__c'){
                                String stringValue = String.valueOf(scheduleValue);
                                totalQty = Decimal.valueOf(stringValue);
                                System.debug('###Current Total Quantity: ' + totalQty);
                            }
                            if(scheduleField == 'Confqty__c'){
                                String stringValue = String.valueOf(scheduleValue);
                                sumConfirmedQty = sumConfirmedQty + Decimal.valueOf(stringValue);
                                System.debug('###Current Sum Schedule Line Quantity: ' + sumConfirmedQty);
                            }

                            if(scheduleField != 'Operation_Type') {
                                if(scheduleField == 'Confdeldt__c' || scheduleField == 'Requesteddate__c' || 
                                   scheduleField == 'Materialavadate__c') {
                                    if(!String.isBlank(String.valueOf(scheduleValue))){
                                        try {
                                            // Converte la stringa in un oggetto Date
                                            Date dateValue = Date.valueOf(String.valueof(scheduleValue));
                                            // Comment debug // System.debug('@@@ dateValue: '+ dateValue + 'of dateString: ' + String.valueof(scheduleValue));
                                            scheduleLine.put(scheduleField,dateValue);
                                        } catch (Exception e) {
                                            // Comment debug // System.debug('@@@ dateValue conversion error: ' + e.getMessage());
                                            scheduleLine.put(scheduleField, null);
                                        }
                                    }
                                }
                                else if(decimalFields.contains(scheduleField.toLowerCase())){
                                    scheduleLine.put(scheduleField, Decimal.valueof(String.valueof(scheduleValue)));
                                }
                                else if(scheduleField == 'Amcormatnum__c' && scheduleValue != null) {
                                    if(!String.isBlank(String.valueOf(scheduleValue))) {
                                        if(!String.isBlank(String.valueof(scheduleValue)) && !String.isEmpty(String.valueof(scheduleValue))){
                                            String matVal = String.valueof(scheduleValue);
                                            productList.add(matVal);
                                            scheduleLine.put(scheduleField, matVal);
                                            if(matVal.contains('?')) {
                                                List<String> matParts = matVal.split('\\?');
                                                if(matParts.size() > 1) {
                                                    scheduleLine.put('Amcor_Material_Number__c', matParts[1]);
                                                }
                                            } else {
                                                scheduleLine.put('Amcor_Material_Number__c', matVal);
                                            }
                                        }
                                    }
                                }
                                else if(scheduleField == 'Soldtoparty_gid__c' || scheduleField == 'Shiptoparty_gid__c' || 
                                        scheduleField == 'Billtoparty_gid__c') {
                                    if(!String.isBlank(String.valueOf(scheduleValue))) {
                                        accountList.add(String.valueOf(scheduleValue));
                                        scheduleLine.put(scheduleField, String.valueOf(scheduleValue));
                                    }
                                }
                                else if(scheduleField == 'Delindicator__c'){
                                    if(scheduleValue == 'D'){
                                        String scheduleId = String.valueOf(itrScheduleLine.get('Order_Schedule_Azure_Id__c'));
                                        if (scheduleId != null) {
                                            scheduleIdsToDelete.add(scheduleId);
                                        }
                                    }
                                }
                                // Number range fix
                                else if(scheduleField == 'Order_Schedule_Azure_Id__c'){
                                    String val = String.valueOf(scheduleValue);
                                    scheduleLine.put(scheduleField, val);
                                    if(val.contains('?')) {
                                        List<String> parts = val.split('\\?');
                                        if(parts.size() > 1) {
                                            scheduleLine.put('Order_Schedule_Azure_Id_layout__c', parts[1]);
                                        }
                                    } else {
                                        scheduleLine.put('Order_Schedule_Azure_Id_layout__c', val);
                                    }
                                }
                                else {
                                    scheduleLine.put(scheduleField, scheduleValue);
                                }
                            }
                            else {
                                operationOnRecord.put(itrScheduleLine.get('Order_Schedule_Azure_Id__c'), scheduleValue);
                            }
                        }

                        scheduleLine.RecordTypeId = SALES_ORDER_SCHEDULE_RECORDTYPE_ID;
                        if(!scheduleIdsToDelete.contains(scheduleLine.Order_Schedule_Azure_Id__c)){
                            orderScheduleLineToUpsert.add(scheduleLine);
                            orderScheduleWithOrderItem.add(scheduleLine);
                        }
                    }
                    if(totalQty == sumConfirmedQty) {mapConfirmedOI.put(orderLineItem.Order_Line_Azure_Id__c, true);}
                    else{mapConfirmedOI.put(orderLineItem.Order_Line_Azure_Id__c, false);}
                    System.debug('###Total Quantity: ' + totalQty + ' - Schedule Line Sum Quantity: ' + sumConfirmedQty);
                    orderWithScheduleMap.put(orderLineItem.Order_Line_Azure_Id__c, orderScheduleWithOrderItem);
                    
                }else{
                    mapConfirmedOI.put(orderLineItem.Order_Line_Azure_Id__c, true);
                    System.debug('###No Schedule Lines for Order Item: ' + orderLineItem.Order_Line_Azure_Id__c + ' - Setting as Confirmed');
                }
            }
            orderWithLineMap.put((String)itrParsedData.get('SalesDocNumber__c'), orderLineWithOrderNumber);
            orderWithLineSHMap.put((String)itrParsedData.get('SalesDocNumber__c'), orderScheduleWithOrderItem);
            //START HotFix PROD BUG-5186
            if(!orderToDelete.contains(newOrderList.SalesDocNumber__c)){
                Boolean allItemsConfirmed = !mapConfirmedOI.isEmpty() && !mapConfirmedOI.values().contains(false);
                if(allItemsConfirmed) {
                    newOrderList.Order_Lines_Confirmed__c = true;
                    newOrderList.Status = 'Confirmed';
                }else{
                    newOrderList.Status = 'Open';
                }
                ordersToUpsert.add(newOrderList); 
            }
            //END HotFix PROD BUG-5186
        }

        // Process Orders
        if (!ordersToUpsert.isEmpty()) {
            try{
                //AccountLookup 
                Map<String, Id> mapAccountId = new Map<String, Id>();
                if(!accountList.isEmpty()){
                    for (Account soldTo : [SELECT Id, Customer_ID__c FROM Account WHERE Customer_ID__c IN :accountList]) {
                        mapAccountId.put(soldTo.Customer_ID__c, soldTo.Id);
                    }
                }

                Map<String, Id> mapCaseOwner = new Map<String, Id>();
                if(!caseIDs.isEmpty()){
                    for (Case thisCase : [SELECT Id, OwnerId FROM Case WHERE Id IN :caseIDs]) {
                        mapCaseOwner.put(thisCase.Id, thisCase.OwnerId);
                    }
                    Map<Id, Case> validCaseMap = new Map<Id, Case>([SELECT Id FROM Case WHERE Id IN :caseIDs]);
                    for (Order thisOrder : ordersToUpsert) {
                        if(thisOrder.CaseID__c != null && !validCaseMap.containsKey(thisOrder.CaseID__c)) {
                            thisOrder.CaseID__c = null;
                        }
                    }
                }
                for (Order thisOrder : ordersToUpsert) {
                    if(!mapAccountId.isEmpty()){
                        if (mapAccountId.get(thisOrder.Soldtoparty_gid__c) != null) {
                            Id accountId = mapAccountId.get(thisOrder.Soldtoparty_gid__c);
                            thisOrder.Soldtoparty_gid__c = accountId;
                            thisOrder.AccountId = accountId;
                        }
                        if(mapAccountId.get(thisOrder.Shiptoparty_gid__c) != null){
                            Id accountId = mapAccountId.get(thisOrder.Shiptoparty_gid__c);
                            thisOrder.Shiptoparty_gid__c = accountId;
                            thisOrder.AccountId = accountId;
                        }
                        if(mapAccountId.get(thisOrder.Billtoparty_gid__c) != null){
                            Id accountId = mapAccountId.get(thisOrder.Billtoparty_gid__c);
                            thisOrder.Billtoparty_gid__c = accountId;
                            thisOrder.AccountId = accountId;
                        }
                        //FIX-5360: Only set Related_Case_Owner__c when the Case owner is a User (005...)
                        Id ownerId = mapCaseOwner.get(thisOrder.CaseID__c);
                        if (ownerId != null && String.valueOf(ownerId).startsWith('005')) {
                            thisOrder.Related_Case_Owner__c = ownerId;
                        } else {
                            thisOrder.Related_Case_Owner__c = null; // (alternativa: não mexer)
                        }
                    }
                    /*START HotFix PROD BUG-5186
                    if(orderConfirmed){ thisOrder.Order_Lines_Confirmed__c = true; thisOrder.Status = 'Confirmed';}
                    Boolean allItemsConfirmed = true;
                    for(Boolean isConfirmed : mapConfirmedOI.values()) {
                        if(!isConfirmed) {
                            allItemsConfirmed = false;
                            break;
                        }
                    }

                    if(allItemsConfirmed) {
                        thisOrder.Order_Lines_Confirmed__c = true;
                        thisOrder.Status = 'Confirmed';
                    }
                    END HotFix PROD BUG-5186*/
                    thisOrder.EffectiveDate = thisOrder.CreatedOn__c;
                    thisOrder.RecordTypeId = SALES_ORDER_RECORDTYPE_ID;
                    thisOrder.CurrencyIsoCode = thisOrder.DocCurrency__c;
                }
                System.debug('ordersToUpsert:-' + ordersToUpsert);
                List<Database.upsertResult> upsertOrderResults = Database.upsert(ordersToUpsert, 
                                                                                	Order.SalesDocNumber__c, 
                                                                                	false);
                integer iterate=0;
                for (Database.upsertResult result : upsertOrderResults) {
                    if (result.isSuccess()) {
                        response = new EndpointUtils.responseWrapper(true,'success',
                                                                     'Order successfully inserted/updated',
                                                                     ordersToUpsert[iterate].SalesDocNumber__c,
                                                                     result.getId());
                    } else {
                        // Handle the errors if needed
                        string errorMessage;
                        for (Database.Error error : result.getErrors()) {
                            System.debug('Error Message: ' + error.getMessage());
                            errorMessage+=error.getMessage();
                        }
                        response = new EndpointUtils.responseWrapper(false,'Failure',
                                                                     errorMessage,
                                                                     ordersToUpsert[iterate].SalesDocNumber__c,
                                                                     '');
                    }
                    jsonResponse.add(response);
                    iterate++;
                }
                EndpointUtils.insertTransactionLog('Request Body', 
                                                   JSON.serialize(jsonResponse), 
                                                   '200', 
                                                   'Success', 
                                                   '');
            } catch (DmlException e) {
                String errorResponse;
                EndpointUtils.insertTransactionLog('Request Body', 
                                                   errorResponse, 
                                                   '501', 
                                                   'Error', 
                                                   e.getMessage());
            }
        }

        // Process Order Items
        if (!orderLineItemToUpsert.isEmpty()) {
            try{
                Map<String, Id> mapAccountId = new Map<String, Id>();
                if(!accountList.isEmpty()){
                    for (Account soldTo : [SELECT Id, Customer_ID__c FROM Account WHERE Customer_ID__c IN :accountList]) {
                        mapAccountId.put(soldTo.Customer_ID__c, soldTo.Id);
                    }
                }
                for (Order_Item__c thisOrderItem : orderLineItemToUpsert) {
                    if(!mapAccountId.isEmpty()){
                        if (mapAccountId.get(thisOrderItem.Soldtoparty_gid__c) != null) {
                            Id accountId = mapAccountId.get(thisOrderItem.Soldtoparty_gid__c);
                            thisOrderItem.Soldtoparty_gid__c = accountId;
                        }
                        if(mapAccountId.get(thisOrderItem.Shiptoparty_gid__c) != null){
                            Id accountId = mapAccountId.get(thisOrderItem.Shiptoparty_gid__c);
                            thisOrderItem.Shiptoparty_gid__c = accountId;
                        }
                        if(mapAccountId.get(thisOrderItem.Billtoparty_gid__c) != null){
                            Id accountId = mapAccountId.get(thisOrderItem.Billtoparty_gid__c);
                            thisOrderItem.Billtoparty_gid__c = accountId;
                        }
                    }
                    
                }

                 if(!orderList.isEmpty()){
                    Map<String, Id> mapOrderId = new Map<String, Id>();
                    for (Order thisOrder : [SELECT Id, SalesDocNumber__c FROM Order WHERE SalesDocNumber__c IN :orderList]) {
                        mapOrderId.put(thisOrder.SalesDocNumber__c, thisOrder.Id);
                    }
                    for (Order_Item__c thisItem : orderLineItemToUpsert) {
                        if (mapOrderId.get(thisItem.ReferenceDocument__c) != null) {
                            thisItem.ReferenceDocument__c = mapOrderId.get(thisItem.ReferenceDocument__c);
                        }else{
                            thisItem.ReferenceDocument__c = null;
                        }
                    }
                }
                
                Map<String, Id> mapOrderItemId = new Map<String, Id>();
                if(!orderItemList.isEmpty()){
                    
                    for (Order_Item__c thisOrderItem : [SELECT Id, Order_Line_Azure_Id__c FROM Order_Item__c WHERE Order_Line_Azure_Id__c IN :orderItemList]) {
                        mapOrderItemId.put(thisOrderItem.Order_Line_Azure_Id__c, thisOrderItem.Id);
                    }
                    for (Order_Item__c thisItem : orderLineItemToUpsert) {
                        if (mapOrderItemId.get(thisItem.ReferenceLineItem__c) != null) {
                            Id orderItemID = mapOrderItemId.get(thisItem.ReferenceLineItem__c);
                            thisItem.ReferenceLineItem__c = orderItemID;
                        }else{
                            thisItem.ReferenceLineItem__c = null;
                        }
                    }
                }

                //InvoiceLookup
                if(!invoiceList.isEmpty()){
                    Map<String, Id> mapinvoiceId = new Map<String, Id>();
                    for (Invoice__c thisInvoice : [SELECT Id, InvoiceNumber__c FROM Invoice__c WHERE InvoiceNumber__c IN :invoiceList]) {
                        mapinvoiceId.put(thisInvoice.InvoiceNumber__c, thisInvoice.Id);
                    }
                    for (Order_Item__c thisItem : orderLineItemToUpsert) {
                        if (mapinvoiceId.get(thisItem.ReferenceInvoice__c) != null) {
                            thisItem.ReferenceInvoice__c = mapinvoiceId.get(thisItem.ReferenceInvoice__c);
                        }else{
                            thisItem.ReferenceInvoice__c = null;
                        }
                    }
                }

                //InvoiceItemLookup
                Map<String, Id> mapinvoiceItemId = new Map<String, Id>();
                if(!invoiceItemList.isEmpty()){
                    for (Invoice_Item__c thisInvoiceItem : [SELECT Id, InnvoiceItem__c FROM Invoice_Item__c WHERE InnvoiceItem__c IN :invoiceItemList]) {
                        mapinvoiceItemId.put(thisInvoiceItem.InnvoiceItem__c, thisInvoiceItem.Id);
                    }
                    for (Order_Item__c thisItem : orderLineItemToUpsert) {
                        if (mapinvoiceItemId.get(thisItem.ReferenceInvoiceItem__c) != null) {
                            thisItem.ReferenceInvoiceItem__c = mapinvoiceItemId.get(thisItem.ReferenceInvoiceItem__c);
                        }else{
                            thisItem.ReferenceInvoiceItem__c = null;
                        }
                    }
                }

                //ProductLookup
                if(!productList.isEmpty()){
                    Map<String, Id> mapMaterialToProductId = new Map<String, Id>();
                    for (Product2 product : [SELECT Id, MaterialNum__c FROM Product2 WHERE MaterialNum__c IN :productList]) {
                        mapMaterialToProductId.put(product.MaterialNum__c, product.Id);
                    }
                    for (Order_Item__c thisItem : orderLineItemToUpsert) {
                        if (mapMaterialToProductId.get(thisItem.Amcormatnum__c) != null) {
                            thisItem.Amcormatnum__c = mapMaterialToProductId.get(thisItem.Amcormatnum__c);
                        }else{
                            thisItem.Amcormatnum__c = null;
                        }
                    }
                }
                System.debug('orderLineItemToUpsert:-' + orderLineItemToUpsert);
                for(Order itrInsertedOrder: ordersToUpsert){
                    System.debug('Order ref no:-'+ itrInsertedOrder.SalesDocNumber__c);
                    List<Order_Item__c> listOfOrderLines = orderWithLineMap.get(itrInsertedOrder.SalesDocNumber__c);
                    System.debug('listOfOrderLines::='+ listOfOrderLines);
                    for(Order_Item__c itrItem: listOfOrderLines){
                        if(String.valueOf(itrInsertedOrder.Salesdocnumber__c) == String.valueOf(itrItem.Salesdocnumber__c)){
                            itrItem.Salesdocnumber__c = itrInsertedOrder.id;
                            itrItem.RecordTypeId = SALES_ORDER_ITEM_RECORDTYPE_ID;
                            itrItem.Name = 'Order Item ' + itrItem.Order_Line_Azure_Id_layout__c;
                            itrItem.CurrencyIsoCode = itrInsertedOrder.CurrencyIsoCode;
                        }
                    }
                }
                Database.UpsertResult[] insertResults = Database.upsert(orderLineItemToUpsert,
                                                                          Order_Item__c.Order_Line_Azure_Id__c,
                                                                          false);
                integer iterate=0;
                for (Database.UpsertResult result : insertResults) {
                    if (result.isSuccess()) {
                        // Save the Id in the list for remove schedule lines
                        //orderLineItemInsertedIds.add(result.getId());
                        
                        response = new EndpointUtils.responseWrapper(true,'success',
                                                                     'Order Item successfully inserted/updated',
                                                                     orderLineItemToUpsert[iterate].Order_Line_Azure_Id__c,
                                                                     result.getId());
                    } else {
                        // Handle the errors if needed
                        string errorMessage;
                        for (Database.Error error : result.getErrors()) {
                            System.debug('Error Message: ' + error.getMessage());
                            errorMessage+=error.getMessage();
                        }
                        response = new EndpointUtils.responseWrapper(false,'Failure',
                                                                     errorMessage,
                                                                     orderLineItemToUpsert[iterate].Order_Line_Azure_Id__c	,
                                                                     '');
                    }
                    jsonResponse.add(response);
                    iterate++;
                }
                EndpointUtils.insertTransactionLog('Request Body', 
                                                   JSON.serialize(jsonResponse), 
                                                   '200', 
                                                   'Success', 
                                                   '');
            } catch (DmlException e) {
                String errorResponse;
                EndpointUtils.insertTransactionLog('Request Body', 
                                                   errorResponse, 
                                                   '501', 
                                                   'Error', 
                                                   e.getMessage());
            }
        }

        // Delete Schedule Lines
        if (!orderLineItemInsertedIds.isEmpty()) {
            System.debug('orderLineItemInsertedIds: ' + orderLineItemInsertedIds);
            List<SObject> recordsToDelete = new List<SObject>();
            recordsToDelete.addAll([SELECT Id, Order_Schedule_Azure_Id__c FROM Order_Schedule_Line__c WHERE Salesdocid__r.Order_Line_Azure_Id__c IN :orderLineItemInsertedIds]);
            try{
                Database.DeleteResult[] deleteResults = Database.delete(recordsToDelete, false);
            } catch (DmlException e) {
                String errorResponse;
                EndpointUtils.insertTransactionLog('Request Body',
                                                errorResponse,
                                                '501',
                                                'Error',
                                                e.getMessage());
            }
        }     
        if (!orderScheduleLineToUpsert.isEmpty()) {
            try {
                Map<String, Id> mapAccountId = new Map<String, Id>();
                if(!accountList.isEmpty()){
                    for (Account soldTo : [SELECT Id, Customer_ID__c FROM Account WHERE Customer_ID__c IN :accountList]) {
                        mapAccountId.put(soldTo.Customer_ID__c, soldTo.Id);
                    }
                }
                for (Order_Schedule_Line__c thisOrderSH : orderScheduleLineToUpsert) {
                    if(!mapAccountId.isEmpty()){
                        if (mapAccountId.get(thisOrderSH.Soldtoparty_gid__c) != null) {
                            Id accountId = mapAccountId.get(thisOrderSH.Soldtoparty_gid__c);
                            thisOrderSH.Soldtoparty_gid__c = accountId;
                        }
                        if(mapAccountId.get(thisOrderSH.Shiptoparty_gid__c) != null){
                            Id accountId = mapAccountId.get(thisOrderSH.Shiptoparty_gid__c);
                            thisOrderSH.Shiptoparty_gid__c = accountId;
                        }
                        if(mapAccountId.get(thisOrderSH.Billtoparty_gid__c) != null){
                            Id accountId = mapAccountId.get(thisOrderSH.Billtoparty_gid__c);
                            thisOrderSH.Billtoparty_gid__c = accountId;
                        }
                    }
                }
                // Order Lookup
                if(!orderList.isEmpty()) {
                    Map<String, Id> mapOrderId = new Map<String, Id>();
                    for (Order ord : [SELECT Id, SalesDocNumber__c FROM Order WHERE SalesDocNumber__c IN :orderList]) {
                        mapOrderId.put(ord.SalesDocNumber__c, ord.Id);
                    }
                    
                    for (Order_Schedule_Line__c schedule : orderScheduleLineToUpsert) {
                        if (mapOrderId.get(schedule.Salesdocnumber__c) != null) {
                            schedule.Salesdocnumber__c = mapOrderId.get(schedule.Salesdocnumber__c);
                        }
                    }
                }

                // Order Item Lookup
                Map<String, Id> mapOrderItemId = new Map<String, Id>();
                for (Order_Schedule_Line__c schedule : orderScheduleLineToUpsert) {
                    String cleanSalesdocid = String.valueOf(schedule.Salesdocid__c);
                    
                    if (cleanSalesdocid != null && cleanSalesdocid.endsWith('AAA')) {
                        cleanSalesdocid = cleanSalesdocid.removeEnd('AAA');
                    }
                    
                    if (mapOrderItemId.get(cleanSalesdocid) != null) {
                        schedule.Salesdocid__c = mapOrderItemId.get(cleanSalesdocid);
                    }
                }

                // Product Lookup
                if(!productList.isEmpty()) {
                    Map<String, Id> mapMaterialToProductId = new Map<String, Id>();
                    for (Product2 product : [SELECT Id, MaterialNum__c 
                                           FROM Product2 
                                           WHERE MaterialNum__c IN :productList]) {
                        mapMaterialToProductId.put(product.MaterialNum__c, product.Id);
                    }
                    
                    for (Order_Schedule_Line__c schedule : orderScheduleLineToUpsert) {
                        if (mapMaterialToProductId.get(schedule.Amcormatnum__c) != null) {
                            schedule.Amcormatnum__c = mapMaterialToProductId.get(schedule.Amcormatnum__c);
                        }else{
                            schedule.Amcormatnum__c = null;
                        }
                    }
                }
                for(Order itrInsertedOrder: ordersToUpsert){
                    System.debug('Order ref no:-'+ itrInsertedOrder.SalesDocNumber__c);
                    List<Order_Schedule_Line__c> listOfOrderLinesSH = orderWithLineSHMap.get(itrInsertedOrder.SalesDocNumber__c);
                    System.debug('listOfOrderLinesSH::='+ listOfOrderLinesSH);
                    for(Order_Schedule_Line__c itrItem: listOfOrderLinesSH){
                        if(String.valueOf(itrInsertedOrder.Salesdocnumber__c) == String.valueOf(itrItem.Salesdocnumber__c)){
                            itrItem.Salesdocnumber__c = itrInsertedOrder.id;
                        }
                    }
                }
                for(Order_Item__c itrInsertedOrder: orderLineItemToUpsert){
                    System.debug('Order ref no:-'+ itrInsertedOrder.Order_Line_Azure_Id__c);
                    if(orderWithScheduleMap.get(itrInsertedOrder.Order_Line_Azure_Id__c) != null){
                        List<Order_Schedule_Line__c> listOfOrderLinesSH = orderWithScheduleMap.get(itrInsertedOrder.Order_Line_Azure_Id__c);
                        System.debug('listOfOrderLinesSH::='+ listOfOrderLinesSH);
                        for(Order_Schedule_Line__c itrItem: listOfOrderLinesSH){

                            String cleanSalesdocid = String.valueOf(itrItem.Salesdocid__c);
                            if (cleanSalesdocid != null && cleanSalesdocid.endsWith('AAA')) {
                                cleanSalesdocid = cleanSalesdocid.removeEnd('AAA');
                            }

                            if(String.valueOf(itrInsertedOrder.Order_Line_Azure_Id__c) == cleanSalesdocid){
                                itrItem.Salesdocid__c = itrInsertedOrder.id;
                                itrItem.Name = 'Order Schedule Line ' + itrItem.Order_Schedule_Azure_Id_layout__c;
                            }
                        }
                    }
                }
                Database.upsertResult[] insertResults = Database.upsert(orderScheduleLineToUpsert, Order_Schedule_Line__c.Order_Schedule_Azure_Id__c, false);
                integer iterate = 0;
                for (Database.upsertResult result : insertResults) {
                    if (result.isSuccess()) {
                        response = new EndpointUtils.responseWrapper(true, 'success',
                                                     'Order Line Scheduling Agreement successfully inserted/updated',
                                                     orderScheduleLineToUpsert[iterate].Order_Schedule_Azure_Id__c,
                                                     result.getId());
                    } else {
                        // Handle the errors if needed
                        string errorMessage = '';
                        for (Database.Error error : result.getErrors()) {
                            System.debug('Error Message: ' + error.getMessage());
                            errorMessage += error.getMessage();
                        }
                        response = new EndpointUtils.responseWrapper(false, 'Failure',
                                                     errorMessage,
                                                     orderScheduleLineToUpsert[iterate].Order_Schedule_Azure_Id__c,
                                                     '');
                    }
                    jsonResponse.add(response);
                    iterate++;
                }
                EndpointUtils.insertTransactionLog('Request Body', 
                                                   JSON.serialize(jsonResponse), 
                                                   '200', 
                                                   'Success', 
                                                   '');
            } catch (DmlException e) {
                String errorResponse;
                EndpointUtils.insertTransactionLog('Request Body', 
                                                   errorResponse, 
                                                   '501', 
                                                   'Error', 
                                                   e.getMessage());
            }
        }
        if (!itemIdsToDelete.isEmpty() || !orderToDelete.isEmpty()) {
                List<SObject> recordsToDelete = new List<SObject>();
                
                recordsToDelete.addAll([SELECT Id, Order_Line_Azure_Id__c FROM Order_Item__c WHERE Order_Line_Azure_Id__c IN :itemIdsToDelete]);
                recordsToDelete.addAll([SELECT Id, SalesDocNumber__c FROM Order WHERE SalesDocNumber__c IN :orderToDelete]);
            try{
     
                Database.DeleteResult[] deleteResults = Database.delete(recordsToDelete, false);
                integer iterate=0;
                for (Database.DeleteResult result : deleteResults) {
                    if (result.isSuccess()) {
                        response = new EndpointUtils.responseWrapper(true,'success',
                                                                     'Order/Order Item successfully Deleted.',
                                                                     '',
                                                                     result.getId());
                    } else {
                        // Handle the errors if needed
                        string errorMessage;
                        for (Database.Error error : result.getErrors()) {
                            System.debug('Error Message: ' + error.getMessage());
                            errorMessage+=error.getMessage();
                        }
                        response = new EndpointUtils.responseWrapper(false,'Failure',
                                                                     errorMessage,
                                                                     '',
                                                                     '');
                    }
                    jsonResponse.add(response);
                    iterate++;
                }
                EndpointUtils.insertTransactionLog('Request Body',
                                                   JSON.serialize(jsonResponse),
                                                   '200',
                                                   'Success',
                                                   '');
            } catch (DmlException e) {
                String errorResponse;
                EndpointUtils.insertTransactionLog('Request Body',
                                                   errorResponse,
                                                   '501',
                                                   'Error',
                                                   e.getMessage());
            }
        }

        if(!caseIDs.isEmpty()){
            System.debug('###Case IDs : ' + caseIDs);
            Boolean doUpdate = false;
            List<Case> caseToUpdate = [SELECT Id, Order_Booked__c FROM Case WHERE Id IN:caseIDs];
            
            if(!caseToUpdate.isEmpty()){
                Database.DMLOptions dmo = new Database.DMLOptions();         
                dmo.assignmentRuleHeader.useDefaultRule = false;
                
                for(Case thisCase : caseToUpdate){
                    if(!thisCase.Order_Booked__c){
                        thisCase.Order_Booked__c = true;
                        thisCase.setOptions(dmo);
                        doUpdate = true;
                    }
                }
                if(doUpdate){
                    update caseToUpdate;
                }
            }
        }

        System.debug('retruned response:-' +jsonResponse);
        return jsonResponse;
    }
}