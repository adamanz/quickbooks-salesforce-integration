/**
 * Test class for QuickBooksAuthStartController
 */
@isTest
public class QuickBooksAuthStartControllerTest {

    @isTest
    static void testRedirectToQuickBooks() {
        // Create test controller
        QuickBooksAuthStartController controller = new QuickBooksAuthStartController();

        // Mock the PageReference
        Test.startTest();
        PageReference result = controller.redirectToQuickBooks();
        Test.stopTest();

        // Basic assertions - the actual redirect URL would be configured
        // In production via custom metadata
        System.assertNotEquals(null, result, 'Should return a PageReference');
    }
}