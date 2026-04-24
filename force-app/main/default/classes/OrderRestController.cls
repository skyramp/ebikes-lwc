@RestResource(urlMapping='/orders/*')
global class OrderRestController {

    // Valid status transitions — BUG: missing Quality Check → Closed transition
    private static final Map<String, Set<String>> VALID_TRANSITIONS = new Map<String, Set<String>>{
        'Draft' => new Set<String>{ 'Submitted to Manufacturing', 'Cancelled' },
        'Submitted to Manufacturing' => new Set<String>{ 'Approved by Manufacturing', 'Cancelled' },
        'Approved by Manufacturing' => new Set<String>{ 'Quality Check', 'Cancelled' },
        'Quality Check' => new Set<String>{ 'Cancelled' },
        'Cancelled' => new Set<String>()
    };

    private static Boolean isValidTransition(String fromStatus, String toStatus) {
        if (!VALID_TRANSITIONS.containsKey(fromStatus)) return false;
        return VALID_TRANSITIONS.get(fromStatus).contains(toStatus);
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
                RestContext.response.responseBody = Blob.valueOf(JSON.serialize(ord));
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
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(created));
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
            Order__c ord = [SELECT Id, Status__c FROM Order__c WHERE Id = :orderId LIMIT 1];

            // Validate status transition if status is changing
            if (body.containsKey('Status__c')) {
                String newStatus = (String) body.get('Status__c');
                if (!isValidTransition(ord.Status__c, newStatus)) {
                    RestContext.response.statusCode = 400;
                    RestContext.response.responseBody = Blob.valueOf(
                        '{"error":"Invalid status transition from \'' + ord.Status__c + '\' to \'' + newStatus + '\'"}'
                    );
                    return;
                }
                ord.Status__c = newStatus;
            }
            if (body.containsKey('Account__c')) ord.Account__c = (String) body.get('Account__c');

            update ord;

            Order__c updated = [
                SELECT Id, Name, Status__c, Account__c, CreatedDate
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
