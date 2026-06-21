trigger CreateTenancyOnInvoicePaid on Invoice__c (after update) {

  List<Tenancy__c> tenancies = new List<Tenancy__c>();

  // Collect IDs of invoices transitioning to Paid
  Set<Id> paidInvoiceIds = new Set<Id>();
  for (Invoice__c inv : Trigger.new) {
      Invoice__c oldInv = Trigger.oldMap.get(inv.Id);
      if (inv.Status__c == 'Paid'
          && oldInv.Status__c != 'Paid'
          && inv.Payer__c != null
          && inv.Unit__c != null) {
          paidInvoiceIds.add(inv.Id);
      }
  }

  if (paidInvoiceIds.isEmpty()) return;

  // Query to get Unit's Property lookup
  Map<Id, Invoice__c> invoiceMap = new Map<Id, Invoice__c>([
      SELECT Id, Payer__c, Unit__c, Years__c, Status__c,
             Unit__r.Property_Lookup__c
      FROM Invoice__c
      WHERE Id IN :paidInvoiceIds
  ]);

  for (Invoice__c inv : invoiceMap.values()) {
      Integer years = (inv.Years__c != null) ? Integer.valueOf(inv.Years__c) : 1;

      tenancies.add(new Tenancy__c(
          Tenant__c   = inv.Payer__c,
          Unit__c     = inv.Unit__c,
          Property__c = inv.Unit__r.Property_Lookup__c,
          Start__c    = Date.today(),
          End__c      = Date.today().addYears(years)
      ));
  }

  if (!tenancies.isEmpty()) {
      insert tenancies;
  }
}