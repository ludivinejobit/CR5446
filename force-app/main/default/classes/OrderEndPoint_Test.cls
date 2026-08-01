@isTest
private class OrderEndPoint_Test {

    @testSetup
    static void initData() {
        Account acc = new Account(Name = 'Test Account', Customer_ID__c = 'CUST001');
        insert acc;

        Product2 prod = new Product2(Name = 'Test Product', MaterialNum__c = 'MAT001');
        insert prod;

        Case cs = new Case(Subject = 'Test Case', Status = 'New', Order_Booked__c = false);
        insert cs;
    }

    private static void setupRequest(String body) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/api/Order/';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = res;
    }  

    @isTest
    static void testInsertThenUpdateOrder_InsertPart() {
        String insertJson = '{"Order": [{'
            + '"SalesDocNumber__c": "SO?UPDATE001",'
            + '"DocCurrency__c": "EUR",'
            + '"Shiptoparty_gid__c": "CUST001",'
            + '"Soldtoparty_gid__c": "CUST001",'
            + '"Billtoparty_gid__c": "CUST001",'
            + '"CreatedOn__c": "2023-11-06",'
            + '"Operation_Type": "insert",'
            + '"SOHEADTOITEM": []'
        + '}]}';

        setupRequest(insertJson);
        Test.startTest();
        List<EndpointUtils.responseWrapper> response = OrderEndPoint.processSalesOrder();
        Test.stopTest();

        System.debug('❌ testEdgeFieldsAndMissingLookups failure: ' + System.JSON.serialize(response));
        System.debug('❌ FAIL MESSAGE: ' + response[0].message);
        System.debug('❌ FULL RESPONSE: ' + System.JSON.serialize(response));
        System.assertEquals(true, response[0].success);
    }

    @isTest
    static void testInsertThenUpdateOrder_UpdatePart() {
        String updateJson = '{"Order": [{'
            + '"SalesDocNumber__c": "SO?UPDATE001",'
            + '"DocCurrency__c": "USD",'
            + '"Shiptoparty_gid__c": "CUST001",'
            + '"Soldtoparty_gid__c": "CUST001",'
            + '"Billtoparty_gid__c": "CUST001",'
            + '"CreatedOn__c": "2023-12-01",'
            + '"Operation_Type": "update",'
            + '"SOHEADTOITEM": []'
        + '}]}';

        setupRequest(updateJson);
        Test.startTest();
        List<EndpointUtils.responseWrapper> response = OrderEndPoint.processSalesOrder();
        Test.stopTest();

        System.assertEquals(true, response[0].success);
    }

    @isTest
    static void testInsertOrderWithNA_CaseID() {
        String json = '{"Order": [{'
            + '"SalesDocNumber__c": "SO?NA_CASE001",'
            + '"DocCurrency__c": "EUR",'
            + '"CaseID__c": "N/A",'
            + '"Shiptoparty_gid__c": "CUST001",'
            + '"Soldtoparty_gid__c": "CUST001",'
            + '"Billtoparty_gid__c": "CUST001",'
            + '"CreatedOn__c": "2023-11-06",'
            + '"Operation_Type": "insert",'
            + '"SOHEADTOITEM": []'
        + '}]}';

        setupRequest(json);
        Test.startTest();
        List<EndpointUtils.responseWrapper> response = OrderEndPoint.processSalesOrder();
        Test.stopTest();

        System.debug(System.JSON.serialize(response));
        System.assertEquals(true, response[0].success);
    }

    @isTest
    static void testDeleteOrderAndItem() {
        String insertJson = '{"Order": [{'
            + '"SalesDocNumber__c": "SO?DELTEST001",'
            + '"DocCurrency__c": "EUR",'
            + '"Shiptoparty_gid__c": "CUST001",'
            + '"Soldtoparty_gid__c": "CUST001",'
            + '"Billtoparty_gid__c": "CUST001",'
            + '"CreatedOn__c": "2023-11-06",'
            + '"Operation_Type": "insert",'
            + '"SOHEADTOITEM": [{'
                + '"Order_Line_Azure_Id__c": "SO_?LINEDELTEST001",'
                + '"ORDERSCHEDULE": []'
            + '}]'
        + '}]}';

        String deleteJson = '{"Order": [{'
            + '"SalesDocNumber__c": "SO?DELTEST001",'
            + '"Delindicator__c": "D",'
            + '"CreatedOn__c": "2023-11-06",'
            + '"Operation_Type": "delete",'
            + '"SOHEADTOITEM": [{'
                + '"Order_Line_Azure_Id__c": "SO_?LINEDELTEST001",'
                + '"Delindicator__c": "D"'
            + '}]'
        + '}]}';

        Test.startTest();
        setupRequest(insertJson);
        OrderEndPoint.processSalesOrder();

        setupRequest(deleteJson);
        List<EndpointUtils.responseWrapper> deleteResponse = OrderEndPoint.processSalesOrder();
        Test.stopTest();

        System.assertEquals(true, deleteResponse[0].success);
        }

    @isTest
    static void testInsertFullConfirmedOrder() {
        String json = '{"Order": [{'
            + '"SalesDocNumber__c": "SO?CONF_001",'
            + '"DocCurrency__c": "EUR",'
            + '"Shiptoparty_gid__c": "CUST001",'
            + '"Soldtoparty_gid__c": "CUST001",'
            + '"Billtoparty_gid__c": "CUST001",'
            + '"CreatedOn__c": "2023-11-06",'
            + '"Operation_Type": "insert",'
            + '"SOHEADTOITEM": [{'
                + '"Order_Line_Azure_Id__c": "SO_?LINE_CONF_001",'
                + '"Amcormatnum__c": "MAT001",'
                + '"ORDERSCHEDULE": [{'
                    + '"Order_Schedule_Azure_Id__c": "SO?SCHED_CONF_001",'
                    + '"Quantity__c": 10,'
                    + '"Confqty__c": 10'
                + '}]'
            + '}]'
        + '}]}';

        setupRequest(json);
        Test.startTest();
        List<EndpointUtils.responseWrapper> response = OrderEndPoint.processSalesOrder();
        Test.stopTest();

        System.debug(System.JSON.serialize(response));
        System.assertEquals(true, response[0].success);
    }

    @isTest
    static void testInsertWithCaseID_MarkBooked() {
        Case testCase = [SELECT Id, Order_Booked__c FROM Case WHERE Subject = 'Test Case' LIMIT 1];
        testCase.Order_Booked__c = false;
        update testCase;

        String json = '{"Order": [{'
            + '"SalesDocNumber__c": "SO?CASEBOOK001",'
            + '"DocCurrency__c": "EUR",'
            + '"Shiptoparty_gid__c": "CUST001",'
            + '"Soldtoparty_gid__c": "CUST001",'
            + '"Billtoparty_gid__c": "CUST001",'
            + '"CaseID__c": "' + testCase.Id + '",'
            + '"CreatedOn__c": "2023-11-06",'
            + '"Operation_Type": "insert",'
            + '"SOHEADTOITEM": []'
        + '}]}';

        setupRequest(json);
        Test.startTest();
        List<EndpointUtils.responseWrapper> response = OrderEndPoint.processSalesOrder();
        Test.stopTest();

        Case updated = [SELECT Order_Booked__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(true, updated.Order_Booked__c);
    }
    @isTest
    static void testInsertOrder_WithInvoiceLookups() {
        String json = '{"Order": [{'
            + '"SalesDocNumber__c": "SO?LOOKUP_FULL001",'
            + '"DocCurrency__c": "EUR",'
            + '"Shiptoparty_gid__c": "CUST001",'
            + '"Soldtoparty_gid__c": "CUST001",'
            + '"Billtoparty_gid__c": "CUST001",'
            + '"CreatedOn__c": "2023-11-06",'
            + '"Operation_Type": "insert",'
            + '"SOHEADTOITEM": [{'
                + '"Order_Line_Azure_Id__c": "SO?LINE_REF_001",'
                + '"Amcormatnum__c": "MAT001",'
                + '"ReferenceDocument__c": "SO456",'
                + '"ReferenceLineItem__c": "LINE456",'
                + '"ReferenceInvoice__c": "INV123",'
                + '"ReferenceInvoiceItem__c": "INVITEM123",'
                + '"ORDERSCHEDULE": [{'
                    + '"Order_Schedule_Azure_Id__c": "SO_?SCHED_REF_001",'
                    + '"Quantity__c": 5,'
                    + '"Confqty__c": 5'
                + '}]'
            + '}]'
        + '}]}';

        setupRequest(json);
        Test.startTest();
        List<EndpointUtils.responseWrapper> response = OrderEndPoint.processSalesOrder();
        Test.stopTest();

        System.assertEquals(true, response[0].success);
    }
    @isTest
    static void testSchedulePartialConfirmationAndDelete() {
        String json = '{"Order": [{'
            + '"SalesDocNumber__c": "SO?SCHED_DEL_001",'
            + '"DocCurrency__c": "EUR",'
            + '"Shiptoparty_gid__c": "CUST001",'
            + '"Soldtoparty_gid__c": "CUST001",'
            + '"Billtoparty_gid__c": "CUST001",'
            + '"CreatedOn__c": "2023-11-06",'
            + '"Operation_Type": "insert",'
            + '"SOHEADTOITEM": [{'
                + '"Order_Line_Azure_Id__c": "SO?LINE_SCHED_001",'
                + '"Amcormatnum__c": "MAT001",'
                + '"ORDERSCHEDULE": [{'
                    + '"Order_Schedule_Azure_Id__c": "SO?SCHED_DEL_001",'
                    + '"Quantity__c": 10,'
                    + '"Confqty__c": 5,'
                    + '"Delindicator__c": "D",'
                    + '"Requesteddate__c": "2023-12-01",'
                    + '"Materialavadate__c": "2023-12-05"'
                + '}]'
            + '}]'
        + '}]}';

        setupRequest(json);
        Test.startTest();
        List<EndpointUtils.responseWrapper> response = OrderEndPoint.processSalesOrder();
        Test.stopTest();

        System.assertEquals(true, response[0].success);
    } 

    @isTest
    static void testEdgeFieldsAndMissingLookups() {
        String fakeCaseId = null; // fake but valid format
        String json = '{"Order": [{'
            + '"SalesDocNumber__c": "SO?EDGE_001",'
            + '"DocCurrency__c": "EUR",'
            + '"Shiptoparty_gid__c": "CUST001",'
            + '"Soldtoparty_gid__c": "CUST001",'
            + '"Billtoparty_gid__c": "CUST001",'
            + '"CreatedOn__c": "2023-11-01",'
            + '"EffectiveDate": "2023-11-02",'
            + '"EndDate": "2023-12-01",'
            + '"Operation_Type": "insert",'
            + '"SOHEADTOITEM": [{'
                + '"Order_Line_Azure_Id__c": "SO?LINE_EDGE_001",'
                + '"SalesDocNumber__c": "SO?EDGE_001",'
                + '"Amcormatnum__c": "MAT001",'
                + '"ORDERSCHEDULE": [{'
                    + '"Order_Schedule_Azure_Id__c": "SO?SCHED_EDGE_001",'
            	    + '"SalesDocNumber__c": "SO?EDGE_001",'
                    + '"Salesdocid__c": "SO?LINE_EDGE_001",'
                    + '"Quantity__c": 8,'
                    + '"Confqty__c": 8,'
                    + '"Confdeldt__c": "2023-12-05"'
                + '}]'
            + '}]'
        + '}]}';

        setupRequest(json);
        Test.startTest();
        List<EndpointUtils.responseWrapper> response = OrderEndPoint.processSalesOrder();
        Test.stopTest();

        System.assertEquals(true, response[0].success);
    }
}