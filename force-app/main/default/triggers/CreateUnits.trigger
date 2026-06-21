trigger CreateUnits on Property__c (after insert) {

  List<Unit__c> unitsToInsert = new List<Unit__c>();

  for (Property__c p : Trigger.new) {

      if (p.Unit__c == null || p.Unit__c <= 0) continue;

      Integer unitCount = Integer.valueOf(p.Unit__c);

      // 🔥 Determine prefix based on Property Type
      String prefix;

      if (p.Property_Type__c == 'Flat / Apartment') {
          prefix = 'Flat';
      } else if (p.Property_Type__c == 'Shop / Commercial') {
          prefix = 'Shop';
      } else if (p.Property_Type__c == 'Land / Plot') {
          prefix = 'Plot';
      } else {
          prefix = 'Unit'; // fallback (important)
      }

      // 🔁 Create units
      for (Integer i = 1; i <= unitCount; i++) {
          unitsToInsert.add(new Unit__c(
              Property_Lookup__c = p.Id,
              Occupancy_Status__c = false,
              Name = prefix + ' ' + i
          ));
      }
  }

  if (!unitsToInsert.isEmpty()) {
      insert unitsToInsert;
  }
}