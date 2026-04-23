@RestResource(urlMapping='/order-items/*')
global class OrderItemRestController {

    @HttpGet
    global static void getOrderItems() {
        RestRequest req = RestContext.request;
        String path = req.requestURI.substringAfter('/order-items/');

        if (String.isNotBlank(path)) {
            // GET /order-items/{id}
            try {
                Order_Item__c item = [
                    SELECT Id, Name, Order__c, Product__c, Price__c,
                           Qty_S__c, Qty_M__c, Qty_L__c
                    FROM Order_Item__c
                    WHERE Id = :path
                    LIMIT 1
                ];
                RestContext.response.statusCode = 200;
                RestContext.response.responseBody = Blob.valueOf(JSON.serialize(item));
            } catch (QueryException e) {
                RestContext.response.statusCode = 404;
                RestContext.response.responseBody = Blob.valueOf('{"error":"Order item not found"}');
            }
        } else {
            // GET /order-items/?orderId={orderId}
            String orderId = req.params.get('orderId');
            List<Order_Item__c> items;

            if (String.isNotBlank(orderId)) {
                items = [
                    SELECT Id, Name, Order__c, Product__c, Price__c,
                           Qty_S__c, Qty_M__c, Qty_L__c
                    FROM Order_Item__c
                    WHERE Order__c = :orderId
                    LIMIT 100
                ];
            } else {
                items = [
                    SELECT Id, Name, Order__c, Product__c, Price__c,
                           Qty_S__c, Qty_M__c, Qty_L__c
                    FROM Order_Item__c
                    LIMIT 100
                ];
            }
            RestContext.response.statusCode = 200;
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(items));
        }
    }

    @HttpPost
    global static void createOrderItem() {
        RestRequest req = RestContext.request;
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());

        Order_Item__c item = new Order_Item__c();
        if (body.containsKey('Order__c')) item.Order__c = (String) body.get('Order__c');
        if (body.containsKey('Product__c')) item.Product__c = (String) body.get('Product__c');
        if (body.containsKey('Price__c')) item.Price__c = body.get('Price__c') instanceof Integer
            ? (Integer) body.get('Price__c')
            : (Decimal) body.get('Price__c');
        if (body.containsKey('Qty_S__c')) item.Qty_S__c = (Integer) body.get('Qty_S__c');
        if (body.containsKey('Qty_M__c')) item.Qty_M__c = (Integer) body.get('Qty_M__c');
        if (body.containsKey('Qty_L__c')) item.Qty_L__c = (Integer) body.get('Qty_L__c');

        insert item;

        Order_Item__c created = [
            SELECT Id, Name, Order__c, Product__c, Price__c,
                   Qty_S__c, Qty_M__c, Qty_L__c
            FROM Order_Item__c
            WHERE Id = :item.Id
            LIMIT 1
        ];
        RestContext.response.statusCode = 201;
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(created));
    }

    @HttpPut
    global static void updateOrderItem() {
        RestRequest req = RestContext.request;
        String itemId = req.requestURI.substringAfter('/order-items/');

        if (String.isBlank(itemId)) {
            RestContext.response.statusCode = 400;
            RestContext.response.responseBody = Blob.valueOf('{"error":"Order item ID is required"}');
            return;
        }

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());

        try {
            Order_Item__c item = [SELECT Id FROM Order_Item__c WHERE Id = :itemId LIMIT 1];

            if (body.containsKey('Price__c')) item.Price__c = body.get('Price__c') instanceof Integer
                ? (Integer) body.get('Price__c')
                : (Decimal) body.get('Price__c');
            if (body.containsKey('Qty_S__c')) item.Qty_S__c = (Integer) body.get('Qty_S__c');
            if (body.containsKey('Qty_M__c')) item.Qty_M__c = (Integer) body.get('Qty_M__c');
            if (body.containsKey('Qty_L__c')) item.Qty_L__c = (Integer) body.get('Qty_L__c');
            if (body.containsKey('Product__c')) item.Product__c = (String) body.get('Product__c');

            update item;

            Order_Item__c updated = [
                SELECT Id, Name, Order__c, Product__c, Price__c,
                       Qty_S__c, Qty_M__c, Qty_L__c
                FROM Order_Item__c
                WHERE Id = :itemId
                LIMIT 1
            ];
            RestContext.response.statusCode = 200;
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(updated));
        } catch (QueryException e) {
            RestContext.response.statusCode = 404;
            RestContext.response.responseBody = Blob.valueOf('{"error":"Order item not found"}');
        }
    }

    @HttpDelete
    global static void deleteOrderItem() {
        RestRequest req = RestContext.request;
        String itemId = req.requestURI.substringAfter('/order-items/');

        if (String.isBlank(itemId)) {
            RestContext.response.statusCode = 400;
            RestContext.response.responseBody = Blob.valueOf('{"error":"Order item ID is required"}');
            return;
        }

        try {
            Order_Item__c item = [SELECT Id FROM Order_Item__c WHERE Id = :itemId LIMIT 1];
            delete item;
            RestContext.response.statusCode = 204;
        } catch (QueryException e) {
            RestContext.response.statusCode = 404;
            RestContext.response.responseBody = Blob.valueOf('{"error":"Order item not found"}');
        }
    }
}
