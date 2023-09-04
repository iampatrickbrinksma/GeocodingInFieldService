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
    * Retrieves the geocoding service details from the custom setting Geocoding_Service__c
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    private static Geocoding_Service__c geocodingService {
        get {
            if (geocodingService == null){
                geocodingService = Geocoding_Service__c.getInstance();
            }
            return geocodingService;
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

        // Set of record Ids to update
        Set<Id> recordIdsToBeUpdated = new Set<Id>();

        // API Name of the object for which the update is requested
        string objApiName;

        // Validate if there are records provided in the request
        if (newRecords != null && !newRecords.isEmpty()){
            
            // Loop through the records
            for (SObject newRecord : newRecords.values()){
                if (isBefore) {
                    if (emptyAddressFields(newRecord, addressFields)) {
                        clearGeocodingFields(newRecord, addressFields);
                    } 
                } else {
                    // Get SObject API Name from the record
                    if (objApiName == null){
                        objApiName = String.valueOf(newRecord.getSObjectType());
                    }       
                    if (isInsert){
                        if (emptyAddressFields(newRecord, addressFields)) {
                            continue;
                        } else {
                            recordIdsToBeUpdated.add((Id)newRecord.get('Id'));
                        }
                    } else {
                        SObject oldRecord = oldRecords.get((Id)newRecord.get('Id'));
                        if ( 
                            !emptyAddressFields(newRecord, addressFields) && (
                            newRecord.get(addressFields.get('Street')) != oldRecord.get(addressFields.get('Street')) ||
                            newRecord.get(addressFields.get('City')) != oldRecord.get(addressFields.get('City')) ||
                            newRecord.get(addressFields.get('PostalCode')) != oldRecord.get(addressFields.get('PostalCode')) ||
                            newRecord.get(addressFields.get('State')) != oldRecord.get(addressFields.get('State')) ||
                            newRecord.get(addressFields.get('Country')) != oldRecord.get(addressFields.get('Country')))
                        ) {
                            recordIdsToBeUpdated.add((Id)newRecord.get('Id'));
                        }
                    }
                }
            }
            
            if (!recordIdsToBeUpdated.isEmpty()){
                if (geocodingService.Service_To_Use_Google_or_Maps__c == 'Maps') {
                    mapsGeocodingQueueable q = new mapsGeocodingQueueable();
                    q.objAPIName = objApiName;
                    q.recordIds = recordIdsToBeUpdated;
                    q.addressFields = addressFields;
                    System.enqueueJob(q);
                } else {
                    googleGeocodingQueueable q = new googleGeocodingQueueable();
                    q.objAPIName = objApiName;
                    q.recordIds = recordIdsToBeUpdated;
                    q.addressFields = addressFields;
                    System.enqueueJob(q);                
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
        return geoCodeAddress(geocodingService.Service_To_Use_Google_or_Maps__c, street, postalcode, city, state, country);
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
            if (serviceToUse == 'Maps') {
                result = mapsGeocodingUtil.geoCodeAddress(street, postalcode, city, state, country);
                result.serviceUsed = 'Salesforce Maps';
            } else {
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
    * Validate if geocoding service is enabled (Custom Settings)
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @return   Boolean         True if geocoding service is enabled, otherwise false
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */            
    public static Boolean geocodingServiceEnabled(){
        // Validate if geocoding service is enabled (custom setting)
        if (geocodingService != null && geocodingService.Enable_Geocoding__c == true) return true;
        return false;
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
    * Method to emtpy custom geocoding fields
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @param    newRecord       SObject
    * @param    addressFields   Map<String, String> - map of address field to API field name
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */            
    private static void clearGeocodingFields(SObject newRecord, Map<String, String> addressFields){
        newRecord.put('Geocoding_Last_Update__c', null);
        newRecord.put('Geocoding_Status__c', null);
        newRecord.put('Geocoding_Message__c', null);
        newRecord.put(addressFields.get('Latitude'), null);
        newRecord.put(addressFields.get('Longitude'), null);
        newRecord.put(addressFields.get('GeocodeAccuracy'), null);
        newRecord.put('FSL__InternalSLRGeolocation__Latitude__s', null);
        newRecord.put('FSL__InternalSLRGeolocation__Longitude__s', null);
    }

}