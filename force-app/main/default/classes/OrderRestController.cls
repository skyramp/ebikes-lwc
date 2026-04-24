@RestResource(urlMapping='/orders/*')
global class OrderRestController {

    private static Order__c buildOrder(Map<String, Object> body) {
        Order__c ord = new Order__c();
        if (body.containsKey('Account__c')) ord.Account__c = (String) body.get('Account__c');
        if (body.containsKey('Status__c')) {
            ord.Status__c = (String) body.get('Status__c');
        } else {
            ord.Status__c = 'Draft';
        }
        return ord;
    }

    @HttpGet
    global static void getOrders() {
        RestRequest req = RestContext.request;
        String path = req.requestURI.substringAfter('/orders/');

        if (String.isNotBlank(path)) {
            // GET /orders/{id}
            try {
                Order__c ord = [
                    SELECT Id, Name, Status__c, Account__c, CreatedDate, LastModifiedDate
                    FROM Order__c
                    WHERE Id = :path
                    LIMIT 1
                ];
                RestContext.response.statusCode = 200;
                RestContext.response.responseBody = Blob.valueOf(JSON.serialize(ord));
            } catch (QueryException e) {
                RestContext.response.statusCode = 404;
                RestContext.response.responseBody = Blob.valueOf('{"error":"Order not found"}');
            }
        } else {
            // GET /orders/
            List<Order__c> orders = [
                SELECT Id, Name, Status__c, Account__c, CreatedDate, LastModifiedDate
                FROM Order__c
                LIMIT 100
            ];
            RestContext.response.statusCode = 200;
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(orders));
        }
    }

    @HttpPost
    global static void createOrder() {
        RestRequest req = RestContext.request;
        String bodyStr = req.requestBody.toString();

        // Detect batch vs single: if body starts with '[' it's a batch
        if (bodyStr.trim().startsWith('[')) {
            // Batch creation
            List<Object> items = (List<Object>) JSON.deserializeUntyped(bodyStr);
            List<Order__c> ordersToInsert = new List<Order__c>();
            for (Object item : items) {
                ordersToInsert.add(buildOrder((Map<String, Object>) item));
            }

            // BUG: no partial failure handling — if one record fails, all fail
            // but we return 201 with empty results instead of an error
            try {
                insert ordersToInsert;
            } catch (DmlException e) {
                RestContext.response.statusCode = 201;
                RestContext.response.responseBody = Blob.valueOf('[]');
                return;
            }

            Set<Id> ids = new Set<Id>();
            for (Order__c o : ordersToInsert) ids.add(o.Id);
            List<Order__c> created = [
                SELECT Id, Name, Status__c, Account__c, CreatedDate, LastModifiedDate
                FROM Order__c
                WHERE Id IN :ids
            ];
            RestContext.response.statusCode = 201;
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(created));
        } else {
            // Single creation (original behavior)
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(bodyStr);
            Order__c ord = buildOrder(body);

            insert ord;

            Order__c created = [
                SELECT Id, Name, Status__c, Account__c, CreatedDate, LastModifiedDate
                FROM Order__c
                WHERE Id = :ord.Id
                LIMIT 1
            ];
            RestContext.response.statusCode = 201;
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(created));
        }
    }

    @HttpPut
    global static void updateOrder() {
        RestRequest req = RestContext.request;
        String orderId = req.requestURI.substringAfter('/orders/');

        if (String.isBlank(orderId)) {
            RestContext.response.statusCode = 400;
            RestContext.response.responseBody = Blob.valueOf('{"error":"Order ID is required"}');
            return;
        }

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());

        try {
            Order__c ord = [SELECT Id FROM Order__c WHERE Id = :orderId LIMIT 1];

            if (body.containsKey('Status__c')) ord.Status__c = (String) body.get('Status__c');
            if (body.containsKey('Account__c')) ord.Account__c = (String) body.get('Account__c');

            update ord;

            Order__c updated = [
                SELECT Id, Name, Status__c, Account__c, CreatedDate, LastModifiedDate
                FROM Order__c
                WHERE Id = :orderId
                LIMIT 1
            ];
            RestContext.response.statusCode = 200;
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(updated));
        } catch (QueryException e) {
            RestContext.response.statusCode = 404;
            RestContext.response.responseBody = Blob.valueOf('{"error":"Order not found"}');
        }
    }

    @HttpDelete
    global static void deleteOrder() {
        RestRequest req = RestContext.request;
        String orderId = req.requestURI.substringAfter('/orders/');

        if (String.isBlank(orderId)) {
            RestContext.response.statusCode = 400;
            RestContext.response.responseBody = Blob.valueOf('{"error":"Order ID is required"}');
            return;
        }

        try {
            Order__c ord = [SELECT Id FROM Order__c WHERE Id = :orderId LIMIT 1];
            delete ord;
            RestContext.response.statusCode = 204;
        } catch (QueryException e) {
            RestContext.response.statusCode = 404;
            RestContext.response.responseBody = Blob.valueOf('{"error":"Order not found"}');
        }
    }
}
