/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Util class with methods supporting geocoding from a trigger context
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <patrick@brinksma.es>
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
public with sharing class geocodingUtil {

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Set of custom geocoding fields. As they are optional, we want to set them conditionally
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */        
    public static Set<String> customGeocodingFields = new Set<String>{
        'Geocoding_Status__c',
        'Geocoding_Message__c',
        'Geocoding_Last_Update__c'
    };

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Retrieves the geocoding service details from the custom setting Geocoding_Service__c
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    private static Geocoding_Service__c geocodingServiceConfig {
        get {
            if (geocodingServiceConfig == null){
                geocodingServiceConfig = Geocoding_Service__c.getInstance();
            }
            return geocodingServiceConfig;
        }
        private set;
    }

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Map of country name to specific Geocoding Service to use
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    private static Map<String, String> countrySpecificGeocoding {
        get {
            if (countrySpecificGeocoding == null){
                countrySpecificGeocoding = new Map<String, String>();
                List<Geocoding_Country_Config__mdt> geoConfigs = [
                    select 
                        Country__c,
                        Geocoding_Service__c
                    from 
                        Geocoding_Country_Config__mdt
                ];
                for (Geocoding_Country_Config__mdt geoConfig : geoConfigs){
                    countrySpecificGeocoding.put(geoConfig.Country__c.toLowerCase(), geoConfig.Geocoding_Service__c);
                }
            }
            return countrySpecificGeocoding;
        }
        private set;
    }

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * SObjects supported by Data Integration Rules
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */        
    private static Set<String> sObjectsSupportedByDataIntegrationRules {
        get {
            if (sObjectsSupportedByDataIntegrationRules == null){
                sObjectsSupportedByDataIntegrationRules = new Set<String>{
                    'Account',
                    'Contact',
                    'Lead',
                    'ResourceAbsence',
                    'ServiceAppointment',
                    'ServiceTerritory',
                    'ServiceTerritoryMember',
                    'Address',
                    'WorkOrder',
                    'WorkOrderLineItem'
                };   
            }
            return sObjectsSupportedByDataIntegrationRules;
        }
        private set;
    } 

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Method to process changed records from an object that has standard address field names
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @param    oldRecords      Trigger.old
    * @param    newRecords      Trigger.new
    * @param    isBefore        Trigger.isBefore
    * @param    isInsert        Trigger.isInsert
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */
    public static void processRecords(Map<Id, SObject> oldRecords, Map<Id, SObject> newRecords, Boolean isBefore, Boolean isInsert){
        Map<String, String> addressFields = new Map<String, String>{
            'Street' => 'Street',
            'City' => 'City',
            'PostalCode' => 'PostalCode',
            'State' => 'State',
            'Country' => 'Country',
            'Latitude' => 'Latitude',
            'Longitude' => 'Longitude',
            'GeocodeAccuracy' => 'GeocodeAccuracy'
        };
        processRecords(oldRecords, newRecords, addressFields, isBefore, isInsert);
    }

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Method to process changed records from an object and enqueue logic to geocode the address
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @param    oldRecords      Trigger.old
    * @param    newRecords      Trigger.new
    * @param    addressFields   Map<String, String> - map of address field to API field name
    * @param    isBefore        Trigger.isBefore
    * @param    isInsert        Trigger.isInsert
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    public static void processRecords(Map<Id, SObject> oldRecords, Map<Id, SObject> newRecords, Map<String, String> addressFields, Boolean isBefore, Boolean isInsert){
        // Only continue if geocoding service is enabled (custom setting)
        if (!geocodingServiceEnabled()) return;

        // Map of service to record Ids to update
        Map<String, Set<Id>> recordsToGeocodeByService = new Map<String, Set<Id>>();

        // API Name of the object for which the update is requested
        string sObjApiName;

        // Validate if there are records provided in the request
        if (newRecords != null && !newRecords.isEmpty()){
            // Get SObject API Name from the record
            sObjApiName = String.valueOf(newRecords.values()[0].getSObjectType());

            // Use single geocoding service for all records, or country specific configuration            
            String geocodingServiceForAllRecords = geocodingServiceConfig.Geocoding_Service__c;
            if (geocodingServiceForAllRecords != null) geocodingServiceForAllRecords = geocodingServiceForAllRecords.toLowerCase();
            // It has to be either Google or Salesforce Maps, if not it's considered null
            if (geocodingServiceForAllRecords != null && geocodingServiceForAllRecords != 'salesforce maps' && geocodingServiceForAllRecords != 'google'){
                geocodingServiceForAllRecords = null;
            }

            // Loop through the records
            for (SObject newRecord : newRecords.values()){
                // Determine which service to use for geocoding, generic one, Google or Salesforce Maps, or none (null)
                String geocodingService;
                if (geocodingServiceForAllRecords != null) {
                    geocodingService = geocodingServiceForAllRecords;
                } else {
                    String country = (String)newRecord.get(addressFields.get('Country'));
                    geocodingService = countrySpecificGeocoding.get(country.toLowerCase());
                }

                // Get Old record state
                SObject oldRecord;
                if (!isInsert) oldRecord = oldRecords.get((Id)newRecord.get('Id'));

                // Clear custom geocoding fields if needed in isBefore event as that's more efficient
                if (isBefore) {
                    // If it's an insert or when address is updated
                    if (isInsert || (!isInsert && addressUpdated(oldRecord, newRecord, addressFields))){
                        clearGeocodingFields(sObjApiName, newRecord, addressFields);
                    }

                    // If it's an update, validate if update by data integration rules need to be reverted
                    if (!isInsert && geocodingService != null) {
                        preventDataIntegrationRulesUpdate(sObjApiName, addressFields, oldRecord, newRecord);                        
                    }

                // On an after event, validate if address needs to be geocoded
                } else {
                    Id recordIdToGeocode;
                    if (isInsert){
                        // If address fields are empty on an after insert event, go to next record
                        // as the isbefore event already cleared the geocoding fields
                        if (emptyAddressFields(newRecord, addressFields)) {
                            continue;
                        } else {
                            // if the address fields are not emtpy on an after insert event, 
                            // add record to collection to be geocoded
                            recordIdToGeocode = (Id)newRecord.get('Id');
                        }
                    // On after update validate if one of the address fields has changed
                    // and if the new address is not an empty address
                    } else {
                        if (!emptyAddressFields(newRecord, addressFields) && addressUpdated(oldRecord, newRecord, addressFields)){
                            recordIdToGeocode = (Id)newRecord.get('Id');
                        }
                    }

                    // If country doesn't require special treatment, go to next record
                    // record will be either geocoded by data integration rules, or not at all
                    // We couldn't do this earlier, as maybe the address was updated so the 
                    // geocoding fields needed to be cleared
                    if (geocodingService == null) {
                        continue;
                    } else {
                        // Add record Id to map
                        if (recordIdToGeocode != null){
                            Set<Id> recordIdsToGeocode = recordsToGeocodeByService.get(geocodingService);
                            if (recordIdsToGeocode == null) {
                                recordIdsToGeocode = new Set<Id>{recordIdToGeocode};
                            } else {
                                recordIdsToGeocode.add(recordIdToGeocode);
                            }
                            recordsToGeocodeByService.put(geocodingService, recordIdsToGeocode);
                        }
                    }
                }
            }
            
            // Check if there is anything left to geocode
            if (!recordsToGeocodeByService.isEmpty()){
                for (String geocodingService : recordsToGeocodeByService.keySet()){
                    Set<Id> recordIdsToGeocode = recordsToGeocodeByService.get(geocodingService);
                    if (recordIdsToGeocode != null){
                        switch on geocodingService.toLowerCase() {
                            when 'google' {
                                googleGeocodingQueueable q = new googleGeocodingQueueable();
                                q.sObjApiName = sObjApiName;
                                q.recordIds = recordIdsToGeocode;
                                q.addressFields = addressFields;
                                System.enqueueJob(q);
                            }
                            when 'salesforce maps' {
                                mapsGeocodingQueueable q = new mapsGeocodingQueueable();
                                q.sObjApiName = sObjApiName;
                                q.recordIds = recordIdsToGeocode;
                                q.addressFields = addressFields;
                                System.enqueueJob(q);
                            }
                            when else {
                                // not supported!
                            }
                        }
                    }
                }
            }
        }
    }

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Method to geocode a single address
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @param    street          Street of the address
    * @param    postalcode      Postal code / Zip code of the address
    * @param    city            City of the address
    * @param    state           State of the address
    * @param    country         Country of the address
    * @return   geoCodeResult   Result of the geocoding, like latitude and longitude
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    public static geoCodeResult geoCodeAddress(String street, String postalcode, String city, String state, String country){
        return geoCodeAddress(geocodingServiceConfig.Geocoding_Service__c, street, postalcode, city, state, country);
    } 

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Method to geocode a single address with the service of choice
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @param    serviceToUse    Which service to use for Geocoding, Google or Maps
    * @param    street          Street of the address
    * @param    postalcode      Postal code / Zip code of the address
    * @param    city            City of the address
    * @param    state           State of the address
    * @param    country         Country of the address
    * @return   geoCodeResult   Result of the geocoding, like latitude and longitude
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    public static geoCodeResult geoCodeAddress(String serviceToUse, String street, String postalcode, String city, String state, String country){
        Long start = System.now().getTime();
        geoCodeResult result;

        if (!geocodingServiceEnabled()){
            result.status = 'NOK';
            result.errorMessage = 'Geocoding Service is not enabled!';
        } else {
            if (serviceToUse.toLowerCase() == 'salesforce maps') {
                result = mapsGeocodingUtil.geoCodeAddress(street, postalcode, city, state, country);
                result.serviceUsed = 'Salesforce Maps';
            } else if (serviceToUse.toLowerCase() == 'google') {
                result = googleGeocodingUtil.geoCodeAddress(street, postalcode, city, state, country);
                result.serviceUsed = 'Google';
            }
        }

        result.durationInMs = System.now().getTime() - start;

        return result;
    }

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Inner class to wrap the geocoding results in to return to the caller for a single address
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */      
    public class geoCodeResult{
        public String status;
        public String errorMessage;
        public System.Location loc;
        public String accuracy;
        public String serviceUsed;
        public Long durationInMs;
    }

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Validate if certain fields exist on an sobject
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @param    sobjApiName                 Api name of the SObject
    * @param    fieldApiNames               Set of Field API Names to validate  
    * @return   Map<String, Boolean>        For each field indicator if it exists or not
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */     
    public static Map<String, Boolean> validateObjectFieldExistence(String sobjApiName, Set<String> fieldApiNames){
        Map<String, Boolean> fieldApiNameExists = new Map<String, Boolean>();
        Set<String> objectFieldApiNames = Schema.getGlobalDescribe().get(sobjApiName).getDescribe().fields.getMap().keySet();
        for(String fieldApiName : fieldApiNames){
            if(objectFieldApiNames.contains(fieldApiName.toLowerCase())){
                fieldApiNameExists.put(fieldApiName, true);
            } else {
                fieldApiNameExists.put(fieldApiName, false);
            }
        }
        return fieldApiNameExists;
    }    

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Validate if geocoding service is enabled (Custom Settings)
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @return   Boolean         True if geocoding service is enabled, otherwise false
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */            
    private static Boolean geocodingServiceEnabled(){
        // Validate if geocoding service is enabled (custom setting)
        return (geocodingServiceConfig != null && geocodingServiceConfig.Enable_Geocoding__c == true);
    }

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Validate if geocoding is updated by Data.com clean and if so revert the change
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @return   Boolean         True if successfull
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    private static Boolean preventDataIntegrationRulesGeocodingUpdate(String sObjApiName, Map<String, String> addressFields, Map<Id, SObject> oldRecords, Map<Id, SObject> newRecords, Boolean isBefore, Boolean isInsert){
        // SObjects supported by Data Integration Rules
        Set<String> supportedObjects = new Set<String>{
            'Account',
            'Contact',
            'Lead',
            'ResourceAbsence',
            'ServiceAppointment',
            'ServiceTerritory',
            'ServiceTerritoryMember',
            'Address',
            'WorkOrder',
            'WorkOrderLineItem'
        };
        // Only prevent this when the SObject is supported, it's the Data.com Clean user and 
        // the context is isBefore
        if (supportedObjects.contains(sObjApiName) && UserInfo.getName() == 'Data.com Clean' && isBefore){    
            for (SObject newRecord : newRecords.values()){
                // Validate for each record if for the country addresses are geocoded
                // using a different service, so updates from Data.com Clean need to be prevented
                String country = (String)newRecord.get(addressFields.get('Country'));
                if (countrySpecificGeocoding.get(country) != null){
                    if (!isInsert && oldRecords != null && !oldRecords.isEmpty()){    
                        if (newRecord.get('Latitude') != null){
                            SObject oldRecord = oldRecords.get((Id)newRecord.get('Id'));
                            newRecord.put('Latitude', oldRecord.get('Latitude'));
                            newRecord.put('Longitude', oldRecord.get('Longitude'));
                            newRecord.put('GeocodeAccuracy', oldRecord.get('GeocodeAccuracy'));

                            // Special Field Service Managed Package fields
                            if (sObjApiName == 'ServiceAppointment'){
                                newRecord.put('FSL__InternalSLRGeolocation__Latitude__s', oldRecord.get('FSL__InternalSLRGeolocation__Latitude__s'));
                                newRecord.put('FSL__InternalSLRGeolocation__Longitude__s', oldRecord.get('FSL__InternalSLRGeolocation__Longitude__s'));
                            }                    
                        }
                    } else if (isInsert){
                        newRecord.put('Latitude', null);
                        newRecord.put('Longitude', null);
                        newRecord.put('GeocodeAccuracy', null);

                        // Special Field Service Managed Package fields
                        if (sObjApiName == 'ServiceAppointment'){
                            newRecord.put('FSL__InternalSLRGeolocation__Latitude__s', null);
                            newRecord.put('FSL__InternalSLRGeolocation__Longitude__s', null);
                        }                    
                    }
                }
            }
        }
        return true;
    }

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Validate if geocoding is updated by Data.com clean and if so revert the change if needed
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @return   Boolean         True if successfull
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    private static void preventDataIntegrationRulesUpdate(String sObjApiName, Map<String, String> addressFields, SObject oldRecord, SObject newRecord){
        // Only prevent this when the SObject is supported, it's the Data.com Clean user
        // this can only be done in the isBefore context of an Apex Trigger
        // If the fields are part of the object's Field History Tracking, the update will still be visible,
        // but that update is never committed.
        if (sObjectsSupportedByDataIntegrationRules.contains(sObjApiName) && UserInfo.getName() == 'Data.com Clean'){   
            if (newRecord.get('Latitude') != null){
                newRecord.put('Latitude', oldRecord.get('Latitude'));
                newRecord.put('Longitude', oldRecord.get('Longitude'));
                newRecord.put('GeocodeAccuracy', oldRecord.get('GeocodeAccuracy'));

                // Special Field Service Managed Package fields
                if (sObjApiName == 'ServiceAppointment'){
                    newRecord.put('FSL__InternalSLRGeolocation__Latitude__s', oldRecord.get('FSL__InternalSLRGeolocation__Latitude__s'));
                    newRecord.put('FSL__InternalSLRGeolocation__Longitude__s', oldRecord.get('FSL__InternalSLRGeolocation__Longitude__s'));
                }                    
            }
        }
    }    

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Method to validate if all address fields are empty (except geocoding fields)
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @param    newRecord       SObject
    * @param    addressFields   Map<String, String> - map of address field to API field name
    * @return   Boolean         True if all address fields are empty (except geocoding fields)
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */        
    private static Boolean emptyAddressFields(SObject newRecord, Map<String, String> addressFields){
        if (
            newRecord.get(addressFields.get('Street')) == null &&
            newRecord.get(addressFields.get('City')) == null &&
            newRecord.get(addressFields.get('PostalCode')) == null &&
            newRecord.get(addressFields.get('State')) == null &&
            newRecord.get(addressFields.get('Country')) == null
        ) {
            return true;
        }
        return false;
    }

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Method to validate if all any address field was updated
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @param    oldRecord       SObject
    * @param    newRecord       SObject
    * @param    addressFields   Map<String, String> - map of address field to API field name
    * @return   Boolean         True if any address field was updated or emptied
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */        
    private static Boolean addressUpdated(SObject oldRecord, SObject newRecord, Map<String, String> addressFields){
        if (
            newRecord.get(addressFields.get('Street')) != oldRecord.get(addressFields.get('Street')) ||
            newRecord.get(addressFields.get('City')) != oldRecord.get(addressFields.get('City')) ||
            newRecord.get(addressFields.get('PostalCode')) != oldRecord.get(addressFields.get('PostalCode')) ||
            newRecord.get(addressFields.get('State')) != oldRecord.get(addressFields.get('State')) ||
            newRecord.get(addressFields.get('Country')) != oldRecord.get(addressFields.get('Country'))
        ) {
            return true;
        }
        return false;
    }    

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Method to emtpy custom geocoding fields
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @param    newRecord       SObject
    * @param    addressFields   Map<String, String> - map of address field to API field name
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */            
    private static void clearGeocodingFields(String sObjApiName, SObject newRecord, Map<String, String> addressFields){
        // Empty the geolocation fields
        newRecord.put(addressFields.get('Latitude'), null);
        newRecord.put(addressFields.get('Longitude'), null);

        // Not all custom address fields on objects have geocodeaccuracy field
        if (addressFields.get('GeocodeAccuracy') != null)
            newRecord.put(addressFields.get('GeocodeAccuracy'), null);

        // Special Field Service Managed Package fields
        if (sObjApiName == 'ServiceAppointment'){
            newRecord.put('FSL__InternalSLRGeolocation__Latitude__s', null);
            newRecord.put('FSL__InternalSLRGeolocation__Longitude__s', null);
        }

        // Validate existing of custom geocoding fields on the sobject
        Map<String, Boolean> fieldApiNameExists = geocodingUtil.validateObjectFieldExistence(sObjAPIName, geocodingUtil.customGeocodingFields);        
        for (String fieldApiName : fieldApiNameExists.keySet()){
            if (fieldApiNameExists.get(fieldApiName) == true){
                newRecord.put(fieldApiName, null);
            }
        }
    }

}