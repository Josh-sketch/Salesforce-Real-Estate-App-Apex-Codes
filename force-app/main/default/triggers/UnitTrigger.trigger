trigger UnitTrigger on Unit__c (after update) {

  List<Invoice__c> invoicesToCreate = new List<Invoice__c>();

  for (Unit__c newUnit : Trigger.new) {
      Unit__c oldUnit = Trigger.oldMap.get(newUnit.Id);

      // Only fire when Tenancy_Status__c changes TO "Accepted"
      if (
          oldUnit.Tenancy_Status__c != 'Accepted' &&
          newUnit.Tenancy_Status__c == 'Accepted'
      ) {
        Decimal annualFee      = newUnit.Annual_Fee__c == null ? 0 : newUnit.Annual_Fee__c;
        Decimal agentFee       = newUnit.Agent_Fee__c == null ? 0 : newUnit.Agent_Fee__c;
        Decimal agreementFee   = newUnit.Agreement_Fee__c == null ? 0 : newUnit.Agreement_Fee__c;
        Decimal cautionFee     = newUnit.Caution_Fee__c == null ? 0 : newUnit.Caution_Fee__c;
        Decimal maintenanceFee = newUnit.Maintenance_Fee__c == null ? 0 : newUnit.Maintenance_Fee__c;
        Decimal securityFee    = newUnit.Security_Fee__c == null ? 0 : newUnit.Security_Fee__c;
        Decimal sanitationFee  = newUnit.Sanitation_Fee__c == null ? 0 : newUnit.Sanitation_Fee__c;
        Decimal processingFee  = 10000;
        invoicesToCreate.add(new Invoice__c(
    Payer__c  = newUnit.Tenant__c,
    Payee__c  = newUnit.Owner__c,
    Unit__c   = newUnit.Id,

    Annual_Fee__c      = annualFee,
    Agent_Fee__c       = agentFee,
    Agreement_Fee__c   = agreementFee,
    Caution_Fee__c     = cautionFee,
    Maintenance_Fee__c = maintenanceFee,
    Security_Fee__c    = securityFee,
    Sanitation_Fee__c  = sanitationFee,
    Processing_Fee__c  = processingFee,

    Status__c = 'Not Paid',
    Type__c   = 'First Timer',
    Years__c  = 1,

    Total_Amount__c =
        annualFee +
        agentFee +
        agreementFee +
        cautionFee +
        maintenanceFee +
        securityFee +
        sanitationFee +
        processingFee
));
      }
  }

  if (!invoicesToCreate.isEmpty()) {
      insert invoicesToCreate;
  }
}