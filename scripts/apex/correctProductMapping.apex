// Correct the QuickBooks Item ID for the Product
String sku = 'O2PU6520';
String correctQbId = '1010000412'; // Found via Query

List<Product2> products = [SELECT Id, Name, QuickBooks_Item_Id__c FROM Product2 WHERE ProductCode = :sku];

if (!products.isEmpty()) {
    Product2 p = products[0];
    p.QuickBooks_Item_Id__c = correctQbId;
    update p;
    System.debug('Corrected Product: ' + p.Name + ' to QB ID: ' + correctQbId);
} else {
    System.debug('Product not found: ' + sku);
}

