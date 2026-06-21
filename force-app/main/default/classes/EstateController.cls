global without sharing class EstateController {
        @RemoteAction
        public static Map<String, Object> createLandlord(
            String name,
            String email,
            String phone,
            String password
        ) {
            Map<String, Object> res = new Map<String, Object>();
    
            try {
                // 🔎 Check if email exists
                List<Estate__c> existing = [
                    SELECT Id FROM Estate__c WHERE Email__c = :email LIMIT 1
                ];
                if (!existing.isEmpty()) {
                    res.put('success', false);
                    res.put('message', 'Email already exists');
                    return res;
                }
    
                // 🔐 Hash password (DO NOT store raw password)
                String salted = password + email;
    
                Blob hash = Crypto.generateDigest(
                    'SHA-256',
                    Blob.valueOf(salted)
                );
    
                String hashedPassword = EncodingUtil.convertToHex(hash);
    
                // 🏗 Create Estate record
                Estate__c est = new Estate__c();
                est.Name = name;
                est.Email__c = email;
                est.Phone__c = phone;
                est.Password__c = hashedPassword;
                est.Type__c = 'Main';
                est.Role__c = 'Landlord';
                est.Status__c = 'Active';
                est.OTP_Used__c = true;
    
                insert est;
    
                res.put('success', true);
                res.put('id', est.Id);
                return res;
    
            } catch (Exception e) {
                res.put('success', false);
                res.put('message', e.getMessage());
                return res;
            }
        }

    @RemoteAction
    public static Map<String, Object> login(String email, String password) {

    Map<String, Object> res = new Map<String, Object>();

    try {

        // 🔎 Get user
        List<Estate__c> users = [
            SELECT Id, Name, Email__c, Phone__c, Password__c,
                   Role__c, Bank_Name__c, Account_Name__c,
                   Account_Number__c, Otp_Used__c
            FROM Estate__c
            WHERE Email__c = :email
            LIMIT 1
        ];

        if (users.isEmpty()) {
            res.put('success', false);
            res.put('message', 'No account found');
            return res;
        }

        Estate__c user = users[0];

        // 🔐 Hash input password
        String salted = password + email;
        Blob hash = Crypto.generateDigest('SHA-256', Blob.valueOf(salted));
        String hashedInput = EncodingUtil.convertToHex(hash);

        // ❌ Wrong password
        if (user.Password__c != hashedInput) {
            res.put('success', false);
            res.put('message', 'Incorrect password');
            return res;
        }

        // ✅ Check OTP usage
        if (user.Otp_Used__c == false) {
            user.Otp_Used__c = true;
            update user;
        }

        // ✅ Success base response
        res.put('success', true);
        res.put('user', user);
        res.put('role', user.Role__c);

        // 🧠 If landlord → fetch subaccounts
        if (user.Role__c != null && user.Role__c.toLowerCase() == 'landlord') {

            List<Estate__c> subs = [
                SELECT Id, Name, Email__c, Phone__c, Role__c, Owner__c
                FROM Estate__c
                WHERE Owner__c = :user.Id
            ];

            res.put('subaccounts', subs);
        }

        // 🧠 If manager → fetch subaccounts
        if (user.Role__c != null && user.Role__c.toLowerCase() == 'manager') {

            List<Estate__c> subs = [
                SELECT Id, Name, Email__c, Phone__c, Role__c, Owner__c
                FROM Estate__c
                WHERE Manager__c = :user.Id
            ];

            res.put('subaccounts', subs);
        }

        return res;

    } catch (Exception e) {
        res.put('success', false);
        res.put('message', e.getMessage());
        return res;
    }
}

        @RemoteAction
        public static Map<String, Object> changePassword(Id userId, String oldPassword, String newPassword) {
        
            Map<String, Object> res = new Map<String, Object>();
        
            try {
                // 🔎 Get user
                List<Estate__c> users = [
                    SELECT Id, Email__c, Password__c
                    FROM Estate__c
                    WHERE Id = :userId
                    LIMIT 1
                ];
        
                if (users.isEmpty()) {
                    res.put('success', false);
                    res.put('message', 'User not found');
                    return res;
                }
        
                Estate__c user = users[0];
        
                // 🔐 Hash old password (same logic as login)
                String saltedOld = oldPassword + user.Email__c;
                Blob oldHash = Crypto.generateDigest('SHA-256', Blob.valueOf(saltedOld));
                String hashedOldInput = EncodingUtil.convertToHex(oldHash);
        
                // ❌ Old password mismatch
                if (user.Password__c != hashedOldInput) {
                    res.put('success', false);
                    res.put('message', 'Old password is incorrect');
                    return res;
                }
        
                // 🔐 Hash new password
                String saltedNew = newPassword + user.Email__c;
                Blob newHash = Crypto.generateDigest('SHA-256', Blob.valueOf(saltedNew));
                String hashedNewPassword = EncodingUtil.convertToHex(newHash);
        
                // 💾 Update password
                user.Password__c = hashedNewPassword;
                update user;
        
                // ✅ Success response
                res.put('success', true);
                res.put('message', 'Password changed successfully');
        
                return res;
        
            } catch (Exception e) {
                res.put('success', false);
                res.put('message', e.getMessage());
                return res;
            }
        }

        @RemoteAction
        public static Map<String, Object> resetUserOTP(String userId, String rawOTP, String email) {
            Map<String, Object> res = new Map<String, Object>();
            
            try {
                List<Estate__c> users = [
                    SELECT Id, OTP_Used__c
                    FROM Estate__c
                    WHERE Id = :userId
                    LIMIT 1
                ];
                
                if (users.isEmpty()) {
                    res.put('success', false);
                    res.put('message', 'User not found');
                    return res;
                }
                
                Estate__c user = users[0];
                
                if (user.OTP_Used__c == true) {
                    res.put('success', false);
                    res.put('otpUsed', true);
                    res.put('message', 'Password can only be changed by the selected user');
                    return res;
                }
                
                // ✅ Hash OTP the same way as createSubaccount
                String salted = rawOTP + email;
                Blob hash = Crypto.generateDigest('SHA-256', Blob.valueOf(salted));
                String hashedOTP = EncodingUtil.convertToHex(hash);
                
                user.Password__c = hashedOTP;
                user.OTP_Used__c = false;
                update user;
                
                res.put('success', true);
                res.put('message', 'OTP reset successfully');
                return res;
                
            } catch (Exception e) {
                res.put('success', false);
                res.put('message', e.getMessage());
                return res;
            }
        }

@RemoteAction
global static Map<String, Object> createSubaccount(
    String name,
    String email,
    String phone,
    String role,
    Id landlordId,
    String otp
) {
    Map<String, Object> res = new Map<String, Object>();

    try {
        // 🔐 Hash the OTP the same way passwords are hashed
        // Salt with email so the same OTP gives different hashes per user
        String salted = otp + email;
        Blob hash = Crypto.generateDigest('SHA-256', Blob.valueOf(salted));
        String hashedOtp = EncodingUtil.convertToHex(hash);

        Estate__c subaccount = new Estate__c(
            Name = name,
            Email__c = email,
            Phone__c = phone,
            Role__c = role,
            Type__c = 'Sub',
            Owner__c = landlordId,
            Password__c = hashedOtp,  // ← hashed, not raw
            OTP_Used__c = false,
            OTP_Code__c = otp,
            Status__c = 'Active'
        );

        insert subaccount;

        res.put('success', true);
        res.put('recordId', subaccount.Id);
        res.put('message', 'Subaccount created successfully');

    } catch (Exception e) {
        res.put('success', false);
        res.put('message', e.getMessage());
    }

    return res;
}

@RemoteAction
global static Map<String, Object> createTenant(
    String name,
    String email,
    String phone,
    String role,
    Id managerId,
    Id landlordId,
    String otp
) {
    Map<String, Object> res = new Map<String, Object>();

    try {
        // 🔐 Hash the OTP the same way passwords are hashed
        // Salt with email so the same OTP gives different hashes per user
        String salted = otp + email;
        Blob hash = Crypto.generateDigest('SHA-256', Blob.valueOf(salted));
        String hashedOtp = EncodingUtil.convertToHex(hash);

        Estate__c subaccount = new Estate__c(
            Name = name,
            Email__c = email,
            Phone__c = phone,
            Role__c = role,
            Type__c = 'Sub',
            Manager__c = managerId, 
            Owner__c = landlordId,
            Password__c = hashedOtp,  // ← hashed, not raw
            OTP_Used__c = false,
            OTP_Code__c = otp,
            Status__c = 'Active'
        );

        insert subaccount;

        res.put('success', true);
        res.put('recordId', subaccount.Id);
        res.put('message', 'Subaccount created successfully');

    } catch (Exception e) {
        res.put('success', false);
        res.put('message', e.getMessage());
    }

    return res;
}


   
    @RemoteAction
    global static Map<String, Object> createProperty(String name, String type, ID landlordId, String address, Decimal unit, String imageUrls) {

        Map<String, Object> res = new Map<String, Object>();

        try {
            // Example: create record (adjust to your object)
            Property__c p = new Property__c(
                Name = name,
                Property_Type__c = type,
                Owner__c = landlordId,
                Address__c = address,
                Unit__c = unit,
                Image_Urls__c = imageUrls
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
    public static List<Estate__c> getTenants(String id) {
        return [
            SELECT Id, Name, Email__c, Phone__c, Status__c
            FROM Estate__c
            WHERE Owner__c = :id
            AND Role__c = 'Tenant'
            ORDER BY Name
        ];
    }

    @RemoteAction
    public static List<Estate__c> getManagerTenants(String id) {
        return [
            SELECT Id, Name, Email__c, Phone__c, Status__c
            FROM Estate__c
            WHERE Manager__c = :id
            AND Role__c = 'Tenant'
            ORDER BY Name
        ];
    }


    @RemoteAction
    public static String assignUnit(String propertyId, String unitId, String tenantId, String landlordId) {
        try {
            // Validate inputs
            if (String.isBlank(propertyId)) {
                return JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'message' => 'Property ID is required'
                });
            }
            
            if (String.isBlank(unitId)) {
                return JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'message' => 'Unit ID is required'
                });
            }
            
            if (String.isBlank(tenantId)) {
                return JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'message' => 'Tenant ID is required'
                });
            }
            
            // Verify the landlord owns this property
            // Assuming Property__c has a lookup to Landlord__c
            List<Property__c> properties = [
                SELECT Id, Owner__c 
                FROM Property__c 
                WHERE Id = :propertyId AND Owner__c = :landlordId
                LIMIT 1
            ];
            
            if (properties.isEmpty()) {
                return JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'message' => 'Property not found or you do not have permission to modify it'
                });
            }
            
            // Find the unit by ID
            // Assuming Unit__c has lookup to Property__c
            List<Unit__c> units = [
                SELECT Id, Name, Tenancy_Status__c, Tenant__c, Property__c
                FROM Unit__c 
                WHERE Id = :unitId 
                AND Property__c = :propertyId
                LIMIT 1
            ];
            
            if (units.isEmpty()) {
                return JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'message' => 'Unit not found in the specified property'
                });
            }
            
            Unit__c targetUnit = units[0];
            
            // Update the unit
            targetUnit.Tenancy_Status__c = 'Assigned';
            targetUnit.Tenant__c = tenantId;
            
            update targetUnit;
            
            return JSON.serialize(new Map<String, Object>{
                'success' => true,
                'message' => 'Unit assigned successfully',
                'unitId' => targetUnit.Id,
                'tenantId' => tenantId
            });
            
        } catch (DmlException e) {
            System.debug('DML Error: ' + e.getMessage());
            return JSON.serialize(new Map<String, Object>{
                'success' => false,
                'message' => 'Database error: ' + e.getDmlMessage(0)
            });
        } catch (Exception e) {
            System.debug('Error in assignUnit: ' + e.getMessage());
            return JSON.serialize(new Map<String, Object>{
                'success' => false,
                'message' => 'Error: ' + e.getMessage()
            });
        }
    }

    @RemoteAction
    public static List<Unit__c> getUnits(String landlordid) {
        return [
            SELECT Id, Name, Tenancy_Status__c, Occupancy_Status__c, Tenant__c, 
            Tenant__r.Name, Tenant__r.Email__c, Property_Lookup__c, Property_Lookup__r.Name, Owner__c, Owner__r.Name
            FROM Unit__c
            WHERE Owner__c = :landlordid
            AND Tenancy_Status__c != 'None'
            AND Tenancy_Status__c != 'Rejected'
            ORDER BY Name
        ];
    }

    @RemoteAction
    public static List<Unit__c> getManagerUnits(String managerid) {
        return [
            SELECT Id, Name, Tenancy_Status__c, Occupancy_Status__c, Tenant__c, 
            Tenant__r.Name, Tenant__r.Email__c, Property_Lookup__c, Property_Lookup__r.Name, Owner__c, Owner__r.Name
            FROM Unit__c
            WHERE Manager__c = :managerid
            AND Tenancy_Status__c != 'None'
            AND Tenancy_Status__c != 'Rejected'
            ORDER BY Name
        ];
    }

    @RemoteAction
public static Estate__c getLandlordByManagerId(String managerId) {
    Estate__c manager = [
        SELECT Id, Name, Email__c, Owner__c
        FROM Estate__c
        WHERE Id = :managerId
        LIMIT 1
    ];
    
    return [
        SELECT Id, Name, Email__c, Phone__c, Role__c
        FROM Estate__c
        WHERE Id = :manager.Owner__c
        LIMIT 1
    ];
}

@RemoteAction
public static List<Unit__c> getTenantUnits(String tenantId) {
    return [
        SELECT Id, Name, Tenancy_Status__c, Occupancy_Status__c, Annual_Fee__c,
        Property_Lookup__c, Property_Lookup__r.Name, Owner__c, Owner__r.Name, Agent_Fee__c, Agreement_Fee__c
        FROM Unit__c
        WHERE Tenant__c = :tenantId
        AND Tenancy_Status__c = 'Assigned'
        ORDER BY Name
    ];
}

@RemoteAction
public static Map<String, Object> createCase(
    String subject,
    String unitId,
    String propertyId,
    String category,
    String priority,
    String description,
    String landlordId,
    String managerId,
    String tenantId,
    String ImageUrl
) {
    Map<String, Object> response = new Map<String, Object>();
    try {
        Case newCase = new Case(
            Subject      = subject,
            Unit__c         = unitId,
            Property__c     = propertyId,
            Type         = category,
            Priority     = priority,
            Description  = description,
            Landlord__c     = landlordId,
            Manager__c     = managerId,
            Tenant__c       = tenantId,
            Image_URL__c =  ImageUrl,
            Status       = 'Open'
        );
        insert newCase;
        response.put('success', true);
        response.put('recordId', newCase.Id);
    } catch (Exception e) {
        response.put('success', false);
        response.put('message', e.getMessage());
    }
    return response;
}

@RemoteAction
public static Unit__c getUnitById(String unitId) {
    return [
        SELECT Id, Name, Type__c, Annual_Fee__c, Agreement_Fee__c, Agent_Fee__c, Caution_Fee__c,
        Maintenance_Fee__c, Security_Fee__c, Sanitation_Fee__c
        FROM Unit__c
        WHERE Id = :unitId
        LIMIT 1
    ];
}

@RemoteAction
public static List<Case> getTenantCases(String tenantId) {
    return [
        SELECT Id, Subject, Type, Priority,
               Description, Status, Comments,
               CreatedDate, LastModifiedDate,
               Unit__c, Unit__r.Name,
               Property__c, Property__r.Name,
               Landlord__c, Tenant__c, Image_URL__c
        FROM Case
        WHERE Tenant__c = :tenantId
        ORDER BY CreatedDate DESC
    ];
}

@RemoteAction
public static List<Case> getManagerCases(String managerId) {
    return [
        SELECT Id, Subject, Type, Priority,
               Description, Status, Comments,
               CreatedDate, LastModifiedDate,
               Unit__c, Unit__r.Name,
               Property__c, Property__r.Name,
               Landlord__c, Tenant__c, Image_URL__c
        FROM Case
        WHERE Manager__c = :managerId
        ORDER BY CreatedDate DESC
    ];
}

@RemoteAction
public static List<Case> getLandlordCases(String landlordId) {
    return [
        SELECT Id, Subject, Type, Priority,
               Description, Status, Comments,
               CreatedDate, LastModifiedDate,
               Unit__c, Unit__r.Name,
               Property__c, Property__r.Name,
               Landlord__c, Tenant__c, Image_URL__c
        FROM Case
        WHERE Landlord__c = :landlordId
        ORDER BY CreatedDate DESC
    ];
}

// @RemoteAction
// public static String acceptOffer(String unitId) {
//     try {
//         List<Unit__c> units = [
//             SELECT Id, Name, Tenancy_Status__c
//             FROM Unit__c
//             WHERE Id = :unitId
//             LIMIT 1
//         ];

//         // 🔒 Safety check
//         if (units.isEmpty()) {
//             return JSON.serialize(new Map<String, Object>{
//                 'success' => false,
//                 'message' => 'Unit not found'
//             });
//         }

//         Unit__c targetUnit = units[0];

//         // ✅ Update the unit
//         targetUnit.Tenancy_Status__c = 'Accepted';
//         update targetUnit;

//         return JSON.serialize(new Map<String, Object>{
//             'success' => true,
//             'message' => 'Unit accepted successfully',
//             'unitId' => targetUnit.Id
//         });

//     } catch (Exception e) {
//         return JSON.serialize(new Map<String, Object>{
//             'success' => false,
//             'message' => e.getMessage()
//         });
//     }
// }

@RemoteAction
public static String acceptOffer(String unitId) {
    try {

        if (String.isBlank(unitId)) {
            return JSON.serialize(new Map<String, Object>{
                'success' => false,
                'message' => 'Invalid Unit Id'
            });
        }

        Unit__c targetUnit = [
            SELECT 
                Id,
                Name,
                Tenancy_Status__c,
                Tenant__c,
                Owner__c
            FROM Unit__c
            WHERE Id = :unitId
            LIMIT 1
        ];

        // Prevent duplicate acceptance
        if (targetUnit.Tenancy_Status__c == 'Accepted') {
            return JSON.serialize(new Map<String, Object>{
                'success' => false,
                'message' => 'Offer already accepted'
            });
        }

        // Update unit
        targetUnit.Tenancy_Status__c = 'Accepted';

        update targetUnit;

        return JSON.serialize(new Map<String, Object>{
            'success' => true,
            'message' => 'Unit accepted successfully',
            'unitId' => targetUnit.Id,
            'unitName' => targetUnit.Name
        });

    } catch (QueryException e) {

        return JSON.serialize(new Map<String, Object>{
            'success' => false,
            'message' => 'Unit not found'
        });

    } catch (Exception e) {

        return JSON.serialize(new Map<String, Object>{
            'success' => false,
            'message' => e.getMessage()
        });
    }
}

@RemoteAction
public static String upUnit(
    String unitId,
    String type,
    Decimal annualFee,
    Decimal agreementFee,
    Decimal agentFee,
    Decimal cautionFee,
    Decimal maintenanceFee,
    Decimal sanitationFee,
    Decimal securityFee,
    String description,
    String featuresJson,
    String imageUrls,
    String recurringFeesJson
) {
    try {
        List<Unit__c> units = [
            SELECT Id, Name, Type__c, Annual_Fee__c, Agreement_Fee__c, Agent_Fee__c,
                   Caution_Fee__c, Maintenance_Fee__c, Sanitation_Fee__c, Security_Fee__c,
                   Description__c, Features__c, Image__c, Recurring_Fees__c
            FROM Unit__c
            WHERE Id = :unitId
            LIMIT 1
        ];

        if (units.isEmpty()) {
            return JSON.serialize(new Map<String, Object>{
                'success' => false,
                'message' => 'Unit not found'
            });
        }

        Unit__c u = units[0];

        // Update basic fields
        u.Type__c = type;
        u.Annual_Fee__c = annualFee;
        u.Agreement_Fee__c = agreementFee;
        u.Agent_Fee__c = agentFee;
        u.Caution_Fee__c = cautionFee;
        u.Maintenance_Fee__c = maintenanceFee;
        u.Security_Fee__c = securityFee;
        u.Sanitation_Fee__c = sanitationFee;

        // Update new fields
        u.Description__c = description;
        u.Features__c = featuresJson;
        u.Image__c = imageUrls;
        u.Recurring_Fees__c = recurringFeesJson;

        update u;

        return JSON.serialize(new Map<String, Object>{
            'success' => true,
            'message' => 'Unit updated successfully',
            'unitId' => u.Id
        });

    } catch (Exception e) {
        return JSON.serialize(new Map<String, Object>{
            'success' => false,
            'message' => e.getMessage()
        });
    }
}

@RemoteAction
public static String saveBankDetails(
    String userId,
    String bankName,
    String accountName,
    String accountNumber
) {
    try {
        List<Estate__c> accounts = [
            SELECT Id, Name, Bank_Name__c, Account_Name__c, Account_Number__c
            FROM Estate__c
            WHERE Id = :userId
            LIMIT 1
        ];

        if (accounts.isEmpty()) {
            return JSON.serialize(new Map<String, Object>{
                'success' => false,
                'message' => 'Account not found'
            });
        }

        Estate__c a = accounts[0];

        // ✅ Update fields
        a.Bank_Name__c = bankName;
        a.Account_Name__c = accountName;
        a.Account_Number__c = accountNumber;

        update a;

        return JSON.serialize(new Map<String, Object>{
            'success' => true,
            'message' => 'Account updated successfully',
            'estateId' => a.Id
        });

    } catch (Exception e) {
        return JSON.serialize(new Map<String, Object>{
            'success' => false,
            'message' => e.getMessage()
        });
    }
}

@RemoteAction
public static List<Invoice__c> getTenantInvoices(String tenantId) {
    return [
        SELECT Id, Annual_Fee__c, Agent_Fee__c, Agreement_Fee__c, CreatedDate,
               Maintenance_Fee__c, Caution_Fee__c, Security_Fee__c, Sanitation_Fee__c,
               Processing_Fee__c, Years__c, Total_Amount__c, Invoice_Number__c, Unit__c, Type__c,
               Unit__r.Name, Unit__r.Type__c, Unit__r.Property_Lookup__r.Name, Payee__c, Payee__r.Name, Payee__r.Email__c, Status__c,
               Payer__c, Payer__r.Name, Payer__r.Email__c,
               Payee__r.Bank_Name__c, Payee__r.Account_Name__c, Payee__r.Account_Number__c
        FROM Invoice__c
        WHERE Payer__c = :tenantId
        AND Status__c = 'Not Paid'
        ORDER BY CreatedDate DESC
    ];
}

@RemoteAction
public static Map<String, Object> saveTenancyAgreement(
    String landlordId,
    String rentPol,
    String landlordRes,
    String maintenancePol,
    String tenancyRules
) {
    Map<String, Object> response = new Map<String, Object>();

    try {
        // Check if agreement already exists for this landlord
        List<Tenancy_Agreement__c> existing = [
            SELECT Id FROM Tenancy_Agreement__c
            WHERE Landlord__c = :landlordId
            LIMIT 1
        ];

        Tenancy_Agreement__c agreement;

        if (!existing.isEmpty()) {
            // Update existing record
            agreement = existing[0];
        } else {
            // Create new record
            agreement = new Tenancy_Agreement__c();
            agreement.Landlord__c = landlordId;
        }

        agreement.Rent__c                      = rentPol;
        agreement.Landlord_Responsibility__c = landlordRes;
        agreement.Maintenance_Policies__c      = maintenancePol;
        agreement.Tenancy_Rules__c             = tenancyRules;

        upsert agreement;

        response.put('success', true);
        response.put('recordId', agreement.Id);

    } catch (Exception e) {
        response.put('success', false);
        response.put('message', e.getMessage());
    }

    return response;
}

@RemoteAction
public static String updateInvoiceYears(String invoiceId, Integer years) {
    Invoice__c inv = [
        SELECT Annual_Fee__c, Agent_Fee__c, Agreement_Fee__c, Sanitation_Fee__c, 
               Security_Fee__c, Maintenance_Fee__c, Caution_Fee__c, Processing_Fee__c, Total_Amount__c
        FROM Invoice__c
        WHERE Id = :invoiceId
        LIMIT 1
    ];

    inv.Years__c = years;
    inv.Total_Amount__c =
        ((inv.Annual_Fee__c   ?? 0) * years) +
        (inv.Agent_Fee__c     ?? 0) +
        (inv.Agreement_Fee__c ?? 0) +
        (inv.Caution_Fee__c   ?? 0) +
        (inv.Maintenance_Fee__c ?? 0) +
        (inv.Processing_Fee__c  ?? 0) +
        (inv.Sanitation_Fee__c  ?? 0) +
        (inv.Security_Fee__c    ?? 0);

    update inv;

    return 'success';
}

@RemoteAction
public static Boolean markInvoicePaid(String invoiceNum, String paymentReference) {
    Invoice__c inv = [
        SELECT Id FROM Invoice__c 
        WHERE Invoice_Number__c = :invoiceNum 
        LIMIT 1
    ];
    inv.Paystack_Reference__c = paymentReference;
    inv.Status__c = 'Paid';
    update inv;
    return true;
}

// Load paid invoices belonging to this landlord
@RemoteAction
public static List<Invoice__c> getLandlordPaidInvoices(String landlordId) {
    return [
        SELECT Id, Invoice_Number__c, Total_Amount__c, Annual_Fee__c,
               Agent_Fee__c, Agreement_Fee__c, Caution_Fee__C, Maintenance_Fee__c, Sanitation_Fee__c, Security_Fee__c, Status__c, Type__c, Years__c,
               Receipt_URL__c, CreatedDate,
               Unit__r.Name, Unit__r.Type__c,
               Payer__r.Name, Payer__r.Id
        FROM Invoice__c
        WHERE Payee__c = :landlordId
        AND Status__c = 'Paid'
    ];
}

// Confirm a payment
@RemoteAction
public static Boolean confirmInvoicePayment(String invoiceId) {
    Invoice__c inv = [SELECT Id FROM Invoice__c WHERE Id = :invoiceId LIMIT 1];
    inv.Status__c = 'Confirmed';
    update inv;
    return true;
}

@RemoteAction
public static Boolean saveContract(
    String invoiceNum,
    String landlordId,
    String tenantId,
    String tenantSignedName,
    String clausesJson,
    String unitId
) {

    try {

        // Validate required fields
        if (
            String.isBlank(invoiceNum) ||
            String.isBlank(tenantSignedName)
        ) {
            return false;
        }

        // Find invoice
        List<Invoice__c> invoices = [
            SELECT Id
            FROM Invoice__c
            WHERE Invoice_Number__c = :invoiceNum
            LIMIT 1
        ];

        if (invoices.isEmpty()) {
            return false;
        }

        Invoice__c inv = invoices[0];

        // 🔒 Check if contract already exists
        Integer existingContracts = [
            SELECT COUNT()
            FROM Contract__c
            WHERE Invoice__c = :inv.Id
        ];

        // If already exists, stop
        if (existingContracts > 0) {
            return false;
        }

        // Create contract
        Contract__c contract = new Contract__c(
            Invoice__c        = inv.Id,
            Tenant_Name__c    = tenantSignedName,
            Landlord__c       = landlordId,
            Tenant__c         = tenantId,
            Agreed_Clauses__c = clausesJson,
            Signed_Date__c    = Date.today(),
            Unit__c = unitId
        );

        insert contract;

        return true;

    } catch (Exception e) {

        System.debug('SAVE CONTRACT ERROR: ' + e.getMessage());

        return false;
    }
}

@RemoteAction
public static List<Tenancy__c> getTenancyByTenant(String tenantId) {
    List<Tenancy__c> results = [
        SELECT Id, Start__c, End__c, Remaining_Days__c,Unit__c,
               Unit__r.Name, Unit__r.Type__c, Unit__r.Manager__c, Duration__c,
               Unit__r.Property_Lookup__r.Name, Unit__r.Property_Lookup__c,
               Unit__r.Owner__r.Name, Unit__r.Owner__c, Status__c
        FROM Tenancy__c
        WHERE Tenant__c = :tenantId
        ORDER BY CreatedDate DESC
    ];
    return results.isEmpty() ? null : results; 
}

@RemoteAction
public static String getTenancyAgreement(String landlordId) {
    try {

        List<Tenancy_Agreement__c> agreements = [
            SELECT
                Id,
                Rent__c,
                Maintenance_Policies__c,
                Landlord_Responsibility__c,
                Tenancy_Rules__c
            FROM Tenancy_Agreement__c
            WHERE Landlord__c = :landlordId
            LIMIT 1
        ];

        if (agreements.isEmpty()) {
            return JSON.serialize(new Map<String, Object>{
                'success' => false,
                'message' => 'No tenancy agreement found'
            });
        }

        Tenancy_Agreement__c ta = agreements[0];

        return JSON.serialize(new Map<String, Object>{
            'success' => true,
            'data' => new Map<String, Object>{
                'id' => ta.Id,
                'rentPolicy' => ta.Rent__c,
                'maintenancePolicy' => ta.Maintenance_Policies__c,
                'landlordResponsibility' => ta.Landlord_Responsibility__c,
                'tenancyPolicy' => ta.Tenancy_Rules__c
            }
        });

    } catch (Exception e) {

        return JSON.serialize(new Map<String, Object>{
            'success' => false,
            'message' => e.getMessage()
        });

    }
}

// Load managers where Owner__c = landlordId AND Role__c = Manager
// @RemoteAction
// public static List<Estate__c> getManagersByLandlord(String landlordId) {
//     return [
//         SELECT Id, Name, Email__c, Phone__c, Role__c
//         FROM Estate__c
//         WHERE Owner__c = :landlordId
//         AND Role__c = 'Manager'
//         ORDER BY Name ASC
//     ];
// }

@RemoteAction
public static List<ManagerWrapper> getManagersByLandlord(String landlordId) {

    List<Estate__c> managers = [
        SELECT Id, Name, Email__c, Phone__c, Role__c
        FROM Estate__c
        WHERE Owner__c = :landlordId
        AND Role__c = 'Manager'
        ORDER BY Name ASC
    ];

    Set<Id> managerIds = new Map<Id, Estate__c>(managers).keySet();

    List<Property__c> props = [
        SELECT Id, Name, Address__c, Property_Type__c, Manager__c
        FROM Property__c
        WHERE Manager__c IN :managerIds
    ];

    Map<Id, List<Property__c>> grouped = new Map<Id, List<Property__c>>();

    for (Property__c p : props) {
        if (!grouped.containsKey(p.Manager__c)) {
            grouped.put(p.Manager__c, new List<Property__c>());
        }
        grouped.get(p.Manager__c).add(p);
    }

    List<ManagerWrapper> outList = new List<ManagerWrapper>();

    for (Estate__c m : managers) {
        ManagerWrapper w = new ManagerWrapper();
        w.id = m.Id;
        w.name = m.Name;
        w.email = m.Email__c;
        w.phone = m.Phone__c;
        w.role = m.Role__c;
        w.properties = grouped.containsKey(m.Id)
            ? grouped.get(m.Id)
            : new List<Property__c>();

        outList.add(w);
    }

    return outList;
}

@RemoteAction
public static List<Property__c> getLandlordProps(String landlordId) {
    return [
        SELECT Id, Name, Owner__c, Property_Type__c, Address__c 
        FROM Property__c
        WHERE Owner__c = :landlordId
        ORDER BY Name
    ];
}

// Assign a property to a manager
//@RemoteAction
// public static Map<String, Object> assignPropertyToManager(
//     String propertyId,
//     String managerId
// ) {
//     Map<String, Object> response = new Map<String, Object>();
//     try {
//         Property__c prop = [SELECT Id, Manager__c FROM Property__c WHERE Id = :propertyId LIMIT 1];
//         prop.Manager__c = managerId;
//         update prop;
//         response.put('success', true);
//     } catch (Exception e) {
//         response.put('success', false);
//         response.put('message', e.getMessage());
//     }
//     return response;
// }

@RemoteAction
public static Map<String, Object> assignPropertyToManager(String propertyId, String managerId) {
    Map<String, Object> res = new Map<String, Object>();
    try {
        Property__c prop = [SELECT Id, Manager__c FROM Property__c WHERE Id = :propertyId LIMIT 1];
        
        // If managerId is blank/empty, treat it as an unassign
        if (String.isBlank(managerId)) {
            prop.Manager__c = null;  // ← clear the lookup field
        } else {
            prop.Manager__c = managerId;
        }
        
        update prop;
        
        res.put('success', true);
        res.put('message', String.isBlank(managerId) ? 'Property unassigned' : 'Property assigned');
    } catch (Exception e) {
        res.put('success', false);
        res.put('message', e.getMessage());
    }
    return res;
}

@RemoteAction
public static Map<String, Object> updateProperty(
    String propertyId,
    String name,
    String type,
    String address,
    Decimal unitCount,
    String description,
    String imageUrls,
    String amenities
) {
    Map<String, Object> res = new Map<String, Object>();
    try {
        Property__c prop = [SELECT Id FROM Property__c WHERE Id = :propertyId LIMIT 1];
        prop.Name = name;
        prop.Property_Type__c = type;
        prop.Address__c = address;
        prop.Unit__c = unitCount;
        prop.Description__c = description;
        prop.Image_URLs__c = imageUrls;
        prop.Amenities__c = amenities;
        update prop;
        res.put('success', true);
    } catch (Exception e) {
        res.put('success', false);
        res.put('message', e.getMessage());
    }
    return res;
}

@RemoteAction
public static List<PropertyWrapper> getProperties(String id) {
    List<Property__c> properties = [
        SELECT Id, Name, Owner__c, Property_Type__c, Address__c, Image_Urls__c, Description__c, Amenities__c
        FROM Property__c
        WHERE Owner__c = :id
        ORDER BY Name
    ];
    
    // Get all property IDs
    Set<Id> propertyIds = new Map<Id, Property__c>(properties).keySet();
    
    // Query all units related to these properties
    List<Unit__c> units = [
        SELECT Id, Name, Occupancy_Status__c, Property_Lookup__c
        FROM Unit__c
        WHERE Property_Lookup__c IN :propertyIds
        ORDER BY Name
    ];
    
    // Group units by property ID
    Map<Id, List<UnitWrapper>> unitsByProperty = new Map<Id, List<UnitWrapper>>();
    for (Unit__c unit : units) {
        if (!unitsByProperty.containsKey(unit.Property_Lookup__c)) {
            unitsByProperty.put(unit.Property_Lookup__c, new List<UnitWrapper>());
        }
        unitsByProperty.get(unit.Property_Lookup__c).add(new UnitWrapper(unit));
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
public static List<PropertyWrapper> getManagerProperties(String id) {
    List<Property__c> properties = [
        SELECT Id, Name, Owner__c, Property_Type__c, Address__c 
        FROM Property__c
        WHERE Manager__c = :id
        ORDER BY Name
    ];
    
    // Get all property IDs
    Set<Id> propertyIds = new Map<Id, Property__c>(properties).keySet();
    
    // Query all units related to these properties
    List<Unit__c> units = [
        SELECT Id, Name, Occupancy_Status__c, Property_Lookup__c
        FROM Unit__c
        WHERE Property_Lookup__c IN :propertyIds
        ORDER BY Name
    ];
    
    // Group units by property ID
    Map<Id, List<UnitWrapper>> unitsByProperty = new Map<Id, List<UnitWrapper>>();
    for (Unit__c unit : units) {
        if (!unitsByProperty.containsKey(unit.Property_Lookup__c)) {
            unitsByProperty.put(unit.Property_Lookup__c, new List<UnitWrapper>());
        }
        unitsByProperty.get(unit.Property_Lookup__c).add(new UnitWrapper(unit));
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
    public String owner { get; set; }
    public String type { get; set; }
    public String address { get; set; }
    public String description { get; set; }
    public String imageUrls {get; set;}
    public String amenities {get; set;}
    public List<UnitWrapper> units { get; set; }
    
    public PropertyWrapper(Property__c prop) {
        this.id = prop.Id;
        this.name = prop.Name;
        this.owner = prop.Owner__c;
        this.type = prop.Property_Type__c;
        this.address = prop.Address__c;
        this.imageUrls = prop.Image_Urls__c;
        this.description = prop.Description__c;
        this.amenities = prop.Amenities__c;
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
public class ManagerWrapper {
    public Id id;
    public String name;
    public String email;
    public String phone;
    public String role;
    public List<Property__c> properties;
}

}