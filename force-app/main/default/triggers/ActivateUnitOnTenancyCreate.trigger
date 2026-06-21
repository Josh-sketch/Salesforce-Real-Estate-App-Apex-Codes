trigger ActivateUnitOnTenancyCreate on Tenancy__c (before insert) {
  Set<Id> unitIds = new Set<Id>();

  for (Tenancy__c t : Trigger.new) {
      if (t.Unit__c != null) {
          unitIds.add(t.Unit__c);
      }
  }

  if (unitIds.isEmpty()) return;

  List<Unit__c> unitsToUpdate = [
      SELECT Id, Tenancy_Status__c, Occupancy_Status__c
      FROM Unit__c
      WHERE Id IN :unitIds
  ];

  for (Unit__c unit : unitsToUpdate) {
      unit.Tenancy_Status__c = 'Active';
      unit.Occupancy_Status__c = true;
  }

  update unitsToUpdate;
}
