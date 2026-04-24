@RestResource(urlMapping='/orders/*')
global class OrderRestController {

    /**
     * Builds an order response map with computed totals from line items.
     * BUG: multiplies Price__c * quantity instead of using Price__c directly
     * (Price__c already includes quantity in the original client-side logic)
     */
    private static Map<String, Object> buildOrderResponse(Order__c ord) {
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(ord));

        // Compute totals from child Order_Item__c records
        List<Order_Item__c> items = [
            SELECT Price__c, Qty_S__c, Qty_M__c, Qty_L__c
            FROM Order_Item__c
            WHERE Order__c = :ord.Id
        ];

        Decimal orderTotal = 0;
        Integer itemCount = 0;
        for (Order_Item__c item : items) {
            Integer qty = 0;
            if (item.Qty_S__c != null) qty += (Integer) item.Qty_S__c;
            if (item.Qty_M__c != null) qty += (Integer) item.Qty_M__c;
            if (item.Qty_L__c != null) qty += (Integer) item.Qty_L__c;
            // BUG: Price__c is already the per-item total, but we multiply by qty again
            orderTotal += (item.Price__c != null ? item.Price__c : 0) * qty;
            itemCount += qty;
        }

        result.put('Order_Total', orderTotal);
        result.put('Item_Count', itemCount);
        return result;
    }

    @HttpGet
    global static void getOrders() {
        RestRequest req = RestContext.request;
        String path = req.requestURI.substringAfter('/orders/');

        if (String.isNotBlank(path)) {
            // GET /orders/{id}
            try {
                Order__c ord = [
                    SELECT Id, Name, Status__c, Account__c, CreatedDate
                    FROM Order__c
                    WHERE Id = :path
                    LIMIT 1
                ];
                RestContext.response.statusCode = 200;
                RestContext.response.responseBody = Blob.valueOf(JSON.serialize(buildOrderResponse(ord)));
            } catch (QueryException e) {
                RestContext.response.statusCode = 404;
                RestContext.response.responseBody = Blob.valueOf('{"error":"Order not found"}');
            }
        } else {
            // GET /orders/
            List<Order__c> orders = [
                SELECT Id, Name, Status__c, Account__c, CreatedDate
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
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());

        Order__c ord = new Order__c();
        if (body.containsKey('Account__c')) ord.Account__c = (String) body.get('Account__c');
        if (body.containsKey('Status__c')) {
            ord.Status__c = (String) body.get('Status__c');
        } else {
            ord.Status__c = 'Draft';
        }

        insert ord;

        Order__c created = [
            SELECT Id, Name, Status__c, Account__c, CreatedDate
            FROM Order__c
            WHERE Id = :ord.Id
            LIMIT 1
        ];
        RestContext.response.statusCode = 201;
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(buildOrderResponse(created)));
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
                SELECT Id, Name, Status__c, Account__c, CreatedDate
                FROM Order__c
                WHERE Id = :orderId
                LIMIT 1
            ];
            RestContext.response.statusCode = 200;
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(buildOrderResponse(updated)));
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
