@RestResource(urlMapping='/products/*')
global class ProductRestController {

    @HttpGet
    global static void getProducts() {
        RestRequest req = RestContext.request;
        String path = req.requestURI.substringAfter('/products/');

        if (String.isNotBlank(path)) {
            // GET /products/{id}
            try {
                Product__c product = [
                    SELECT Id, Name, Description__c, MSRP__c, Category__c,
                           Material__c, Level__c, Picture_URL__c, Battery__c,
                           Charger__c, Motor__c, Fork__c, Front_Brakes__c,
                           Rear_Brakes__c, Product_Family__c
                    FROM Product__c
                    WHERE Id = :path
                    LIMIT 1
                ];
                RestContext.response.statusCode = 200;
                RestContext.response.responseBody = Blob.valueOf(JSON.serialize(product));
            } catch (QueryException e) {
                RestContext.response.statusCode = 404;
                RestContext.response.responseBody = Blob.valueOf('{"error":"Product not found"}');
            }
        } else {
            // GET /products/
            List<Product__c> products = [
                SELECT Id, Name, Description__c, MSRP__c, Category__c,
                       Material__c, Level__c, Picture_URL__c
                FROM Product__c
                LIMIT 100
            ];
            RestContext.response.statusCode = 200;
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(products));
        }
    }

    @HttpPost
    global static void createProduct() {
        RestRequest req = RestContext.request;
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());

        Product__c product = new Product__c();
        if (body.containsKey('Name')) product.Name = (String) body.get('Name');
        if (body.containsKey('Description__c')) product.Description__c = (String) body.get('Description__c');
        if (body.containsKey('MSRP__c')) product.MSRP__c = body.get('MSRP__c') instanceof Integer
            ? (Integer) body.get('MSRP__c')
            : (Decimal) body.get('MSRP__c');
        if (body.containsKey('Category__c')) product.Category__c = (String) body.get('Category__c');
        if (body.containsKey('Material__c')) product.Material__c = (String) body.get('Material__c');
        if (body.containsKey('Level__c')) product.Level__c = (String) body.get('Level__c');
        if (body.containsKey('Picture_URL__c')) product.Picture_URL__c = (String) body.get('Picture_URL__c');

        insert product;

        RestContext.response.statusCode = 201;
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(product));
    }

    @HttpPut
    global static void updateProduct() {
        RestRequest req = RestContext.request;
        String productId = req.requestURI.substringAfter('/products/');

        if (String.isBlank(productId)) {
            RestContext.response.statusCode = 400;
            RestContext.response.responseBody = Blob.valueOf('{"error":"Product ID is required"}');
            return;
        }

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());

        try {
            Product__c product = [SELECT Id FROM Product__c WHERE Id = :productId LIMIT 1];

            if (body.containsKey('Name')) product.Name = (String) body.get('Name');
            if (body.containsKey('Description__c')) product.Description__c = (String) body.get('Description__c');
            if (body.containsKey('MSRP__c')) product.MSRP__c = body.get('MSRP__c') instanceof Integer
                ? (Integer) body.get('MSRP__c')
                : (Decimal) body.get('MSRP__c');
            if (body.containsKey('Category__c')) product.Category__c = (String) body.get('Category__c');
            if (body.containsKey('Material__c')) product.Material__c = (String) body.get('Material__c');
            if (body.containsKey('Level__c')) product.Level__c = (String) body.get('Level__c');
            if (body.containsKey('Picture_URL__c')) product.Picture_URL__c = (String) body.get('Picture_URL__c');

            update product;

            Product__c updated = [
                SELECT Id, Name, Description__c, MSRP__c, Category__c,
                       Material__c, Level__c, Picture_URL__c
                FROM Product__c
                WHERE Id = :productId
                LIMIT 1
            ];
            RestContext.response.statusCode = 200;
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(updated));
        } catch (QueryException e) {
            RestContext.response.statusCode = 404;
            RestContext.response.responseBody = Blob.valueOf('{"error":"Product not found"}');
        }
    }

    @HttpDelete
    global static void deleteProduct() {
        RestRequest req = RestContext.request;
        String productId = req.requestURI.substringAfter('/products/');

        if (String.isBlank(productId)) {
            RestContext.response.statusCode = 400;
            RestContext.response.responseBody = Blob.valueOf('{"error":"Product ID is required"}');
            return;
        }

        try {
            Product__c product = [SELECT Id FROM Product__c WHERE Id = :productId LIMIT 1];
            delete product;
            RestContext.response.statusCode = 204;
        } catch (QueryException e) {
            RestContext.response.statusCode = 404;
            RestContext.response.responseBody = Blob.valueOf('{"error":"Product not found"}');
        }
    }
}
