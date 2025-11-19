// Create/Update Product2 records for all Line Items
List<Product2> productsToUpsert = new List<Product2>();

// Helper to create product instance (we will upsert by ProductCode if possible, or query and update)
// Since we can't easily upsert on non-id fields in anonymous apex without external ID, 
// we'll use a simple check-then-create logic.

Map<String, String> skuToIdMap = new Map<String, String>{
    'PWR-CHAIR-UPG' => '1010000461',
    'STARRY-ROOF' => '85',
    'AMBIENT-LED' => '86',
    'LED-TV-UPG' => '68',
    'WHITE-GLOVE' => '1010000351',
    'ON-SITE-INSTALL' => '1010000051',
    'HBOT-TRAINING' => '1010000391',
    'OXYCARE-PLUS' => '1010000481'
};

Map<String, String> skuToNameMap = new Map<String, String>{
    'PWR-CHAIR-UPG' => 'Power Chair Upgrade for OxyPro Genesis',
    'STARRY-ROOF' => 'Starry Roof Liner',
    'AMBIENT-LED' => 'Ambient LED Lighting',
    'LED-TV-UPG' => 'TV upgrade for OxyPro Ultra/Genesis',
    'WHITE-GLOVE' => 'White Glove Delivery Service',
    'ON-SITE-INSTALL' => 'On Site Installation Service',
    'HBOT-TRAINING' => 'HBOT Home User Training Course',
    'OXYCARE-PLUS' => 'OxyCare+ HBOT onboarding support with doctor Q&A'
};

// 1. Get existing products to update
List<Product2> existingProducts = [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN :skuToIdMap.keySet()];
Set<String> existingSkus = new Set<String>();

for (Product2 p : existingProducts) {
    if (skuToIdMap.containsKey(p.ProductCode)) {
        p.QuickBooks_Item_Id__c = skuToIdMap.get(p.ProductCode);
        productsToUpsert.add(p);
        existingSkus.add(p.ProductCode);
    }
}

// 2. Create new products for missing ones
for (String sku : skuToIdMap.keySet()) {
    if (!existingSkus.contains(sku)) {
        Product2 newProd = new Product2(
            Name = skuToNameMap.get(sku),
            ProductCode = sku,
            QuickBooks_Item_Id__c = skuToIdMap.get(sku),
            IsActive = true,
            Description = skuToNameMap.get(sku)
        );
        productsToUpsert.add(newProd);
    }
}

if (!productsToUpsert.isEmpty()) {
    upsert productsToUpsert;
    System.debug('Upserted ' + productsToUpsert.size() + ' products.');
}

