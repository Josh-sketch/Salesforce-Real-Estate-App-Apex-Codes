global without sharing class AuthController {

    @RemoteAction
    global static Map<String, Object> createLandlord(String name, String email, String phone, String password) {

        Map<String, Object> res = new Map<String, Object>();

        try {
            // Example: create record (adjust to your object)
            Landlord__c l = new Landlord__c(
                Name = name,
                Email__c = email,
                Phone__c = phone,
                Password__c = password
            );
            insert l;

            res.put('success', true);
            res.put('message', 'Landlord created successfully');

        } catch (Exception e) {
            res.put('success', false);
            res.put('message', e.getMessage());
        }

        return res;
    }

    @RemoteAction
    global static Map<String, Object> createProperty(String name, String type, ID landlordId, String address, Decimal unit) {

        Map<String, Object> res = new Map<String, Object>();

        try {
            // Example: create record (adjust to your object)
            Property__c p = new Property__c(
                Name = name,
                Property_Type__c = type,
                Landlord__c = landlordId,
                Address__c = address,
                Unit__c = unit
            );
            insert p;

            res.put('success', true);
            res.put('message', 'Property created successfully');

        } catch (Exception e) {
            res.put('success', false);
            res.put('message', e.getMessage());
        }

        return res;
    }

    @RemoteAction
    global static Map<String, Object> createTenant(String name, String email, String phone, String password) {

        Map<String, Object> res = new Map<String, Object>();

        try {
            // Example: create record (adjust to your object)
            Tenant__c t = new Tenant__c(
                Name = name,
                Email__c = email,
                Phone__c = phone,
                Password__c = password,
                Status__c = 'Active'
            );
            insert t;

            res.put('success', true);
            res.put('message', 'Tenant created successfully');

        } catch (Exception e) {
            res.put('success', false);
            res.put('message', e.getMessage());
        }

        return res;
    }

    @RemoteAction
    public static List<Landlord__c> getLandlords() {
        return [
            SELECT Id, Name, Email__c, Phone__c
            FROM Landlord__c
            ORDER BY Name
        ];
    }

    @RemoteAction
    public static List<Tenant__c> getTenants() {
        return [
            SELECT Id, Name, Email__c, Phone__c, Status__c
            FROM Tenant__c
            ORDER BY Name
        ];
    }


    @RemoteAction
public static List<PropertyWrapper> getProperties() {
    List<Property__c> properties = [
        SELECT Id, Name, landlord__c, Property_Type__c, Address__c 
        FROM Property__c
        ORDER BY Name
    ];
    
    // Get all property IDs
    Set<Id> propertyIds = new Map<Id, Property__c>(properties).keySet();
    
    // Query all units related to these properties
    List<Unit__c> units = [
        SELECT Id, Name, Occupancy_Status__c, Property__c
        FROM Unit__c
        WHERE Property__c IN :propertyIds
        ORDER BY Name
    ];
    
    // Group units by property ID
    Map<Id, List<UnitWrapper>> unitsByProperty = new Map<Id, List<UnitWrapper>>();
    for (Unit__c unit : units) {
        if (!unitsByProperty.containsKey(unit.Property__c)) {
            unitsByProperty.put(unit.Property__c, new List<UnitWrapper>());
        }
        unitsByProperty.get(unit.Property__c).add(new UnitWrapper(unit));
    }
    
    // Build the response
    List<PropertyWrapper> result = new List<PropertyWrapper>();
    for (Property__c prop : properties) {
        PropertyWrapper wrapper = new PropertyWrapper(prop);
        wrapper.units = unitsByProperty.containsKey(prop.Id) 
            ? unitsByProperty.get(prop.Id) 
            : new List<UnitWrapper>();
        result.add(wrapper);
    }
    
    return result;
}

    @RemoteAction
    public static Landlord__c loginLandlord(String email, String password) {
    System.debug('Login attempt: ' + email + ' / ' + password);

    List<Landlord__c> results = [
        SELECT Id, Name, Email__c, Phone__c
        FROM Landlord__c
        WHERE Email__c = :email
        AND Password__c = :password
        LIMIT 1
    ];

    System.debug('Query size: ' + results.size());

    return results.isEmpty() ? null : results[0];
}

@RemoteAction
public static List<Map<String, String>> getPropertyTypePicklist() {
    List<Map<String, String>> options = new List<Map<String, String>>();
    
    Schema.DescribeFieldResult fieldResult = Property__c.Property_Type__c.getDescribe();
    List<Schema.PicklistEntry> entries = fieldResult.getPicklistValues();
    
    for (Schema.PicklistEntry entry : entries) {
        if (entry.isActive()) {
            Map<String, String> option = new Map<String, String>();
            option.put('value', entry.getValue());
            option.put('label', entry.getLabel());
            options.add(option);
        }
    }
    
    return options;
}

@RemoteAction
public static List<PropertyWrapper> getPropertiesByLandlord(Id landlordId) {
    List<Property__c> properties = [
        SELECT Id, Name, Landlord__c, Property_Type__c, Address__c
        FROM Property__c
        WHERE Landlord__c = :landlordId
        ORDER BY Name
    ];

    Set<Id> propertyIds = new Map<Id, Property__c>(properties).keySet();

    List<Unit__c> units = [
        SELECT Id, Name, Occupancy_Status__c, Property__c
        FROM Unit__c
        WHERE Property__c IN :propertyIds
        ORDER BY Name
    ];

    Map<Id, List<UnitWrapper>> unitsByProperty = new Map<Id, List<UnitWrapper>>();
    for (Unit__c unit : units) {
        if (!unitsByProperty.containsKey(unit.Property__c)) {
            unitsByProperty.put(unit.Property__c, new List<UnitWrapper>());
        }
        unitsByProperty.get(unit.Property__c).add(new UnitWrapper(unit));
    }

    List<PropertyWrapper> result = new List<PropertyWrapper>();
    for (Property__c prop : properties) {
        PropertyWrapper wrapper = new PropertyWrapper(prop);
        wrapper.units = unitsByProperty.containsKey(prop.Id)
            ? unitsByProperty.get(prop.Id)
            : new List<UnitWrapper>();
        result.add(wrapper);
    }

    return result;
}

// Wrapper class for Property
public class PropertyWrapper {
    public String id { get; set; }
    public String name { get; set; }
    public String landlordId { get; set; }
    public String type { get; set; }
    public String address { get; set; }
    public List<UnitWrapper> units { get; set; }
    
    public PropertyWrapper(Property__c prop) {
        this.id = prop.Id;
        this.name = prop.Name;
        this.landlordId = prop.landlord__c;
        this.type = prop.Property_Type__c;
        this.address = prop.Address__c;
        this.units = new List<UnitWrapper>();
    }
}

// Wrapper class for Unit
public class UnitWrapper {
    public String id { get; set; }
    public String label { get; set; }
    public String status { get; set; }
    // public String subtype { get; set; }
    // public String measurement { get; set; }
    
    public UnitWrapper(Unit__c unit) {
        this.id = unit.Id;
        this.label = unit.Name;
        this.status = unit.Occupancy_Status__c == false ? 'vacant' : 'occupied';
        // this.subtype = unit.Type__c;
        // this.measurement = unit.Measurement__c;
    }
}

}