// Create or Update the Product for testing mapping
String sku = 'O2PU6520';
String qbId = '200006002';
String name = 'Oxycell OxyPro Ultra 6500 2.0 ATA 200005406 Power Chair Upgrade';

List<Product2> existing = [SELECT Id FROM Product2 WHERE ProductCode = :sku OR Name = :name];

if (!existing.isEmpty()) {
    // Update existing
    Product2 p = existing[0];
    p.QuickBooks_Item_Id__c = qbId;
    p.ProductCode = sku; // Ensure SKU matches
    update p;
    System.debug('Updated Product: ' + p.Id);
} else {
    // Create new
    Product2 p = new Product2(
        Name = name,
        ProductCode = sku,
        QuickBooks_Item_Id__c = qbId,
        IsActive = true
    );
    insert p;
    System.debug('Created Product: ' + p.Id);
}

