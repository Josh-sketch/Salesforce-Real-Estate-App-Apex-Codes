trigger UpdateUnitManagerOnProperty on Property__c (after update) {
  Set<Id> propertyIds = new Set<Id>();

  for (Property__c prop : Trigger.new) {
      Property__c oldProp = Trigger.oldMap.get(prop.Id);

      // Only fire when Manager__c actually changes
      if (prop.Manager__c != oldProp.Manager__c) {
          propertyIds.add(prop.Id);
      }
  }

  if (propertyIds.isEmpty()) return;

  // Get all units belonging to the updated properties
  List<Unit__c> unitsToUpdate = [
      SELECT Id, Manager__c, Property_Lookup__c
      FROM Unit__c
      WHERE Property_Lookup__c IN :propertyIds
  ];

  if (unitsToUpdate.isEmpty()) return;

  // Map property ID to new manager ID
  Map<Id, Id> propertyToManager = new Map<Id, Id>();
  for (Property__c prop : Trigger.new) {
      propertyToManager.put(prop.Id, prop.Manager__c);
  }

  // Update each unit's Manager__c to match its property's Manager__c
  for (Unit__c unit : unitsToUpdate) {
      unit.Manager__c = propertyToManager.get(unit.Property_Lookup__c);
  }

  update unitsToUpdate;
}