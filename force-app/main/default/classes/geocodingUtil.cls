/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Util class with methods supporting geocoding from a trigger context
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <patrick@brinksma.es>
* @version        1.0
* @created        2023-03-01
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @changes
* v1.0            Patrick Brinksma   <patrick@brinksma.es>
* 2023-02-01      Initial version
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
public with sharing class geocodingUtil {

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Retrieves the geocoding service to use from the custom setting Geocoding_Service__c
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    private static String geocodingServiceToUse {
        get {
            if (geocodingServiceToUse == null){
                Geocoding_Service__c geocodingService = Geocoding_Service__c.getInstance();
                if (geocodingService != null && geocodingService.Service_To_Use_Google_or_Maps__c != null){
                    geocodingServiceToUse = geocodingService.Service_To_Use_Google_or_Maps__c;
                }
            }
            return geocodingServiceToUse;
        }
        private set;
    }    

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Method to process changed records from an object that has standard address field names
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @param    oldRecords      Trigger.old
    * @param    newRecords      Trigger.new
    * @param    isInsert        Trigger.isInsert
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */
    public static void processRecords(Map<Id, SObject> oldRecords, Map<Id, SObject> newRecords, Boolean isInsert){
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
        processRecords(oldRecords, newRecords, addressFields, isInsert);
    }

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Method to process changed records from an object and enqueue logic to geocode the address
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @param    oldRecords      Trigger.old
    * @param    newRecords      Trigger.new
    * @param    addressFields   Map<String, String> - map of address field to API field name
    * @param    isInsert        Trigger.isInsert
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    public static void processRecords(Map<Id, SObject> oldRecords, Map<Id, SObject> newRecords, Map<String, String> addressFields, Boolean isInsert){
        Set<Id> recordIdsToBeUpdated = new Set<Id>();
        string objApiName;
        for (SObject newRecord : newRecords.values()){
            if (objApiName == null){
                objApiName= String.valueOf(newRecord.getSObjectType());
            }
            if (isInsert==false){ //if not new insert (E.g. update/record already existed)
                SObject oldRecord = oldRecords.get((Id)newRecord.get('Id'));
                if ( 
                    //if address fields weren't changed, skip this record (don't add to list of SAs to geocode)
                    newRecord.get(addressFields.get('Street')) == oldRecord.get(addressFields.get('Street')) &&
                    newRecord.get(addressFields.get('City')) == oldRecord.get(addressFields.get('City')) &&
                    newRecord.get(addressFields.get('PostalCode')) == oldRecord.get(addressFields.get('PostalCode')) &&
                    newRecord.get(addressFields.get('State')) == oldRecord.get(addressFields.get('State')) &&
                    newRecord.get(addressFields.get('Country')) == oldRecord.get(addressFields.get('Country'))
                  )
                {
                    continue; //skip this record and proceed to next record in the loop/trigger
                }
            } else { //if this is a new insert, don't geocode if address is null - the user might be data loading/defining geolocation manually
                if( //if some/all address fields aren't null, user meant to have this geocoded
                    newRecord.get(addressFields.get('Street')) == null &&
                    newRecord.get(addressFields.get('City')) == null &&
                    newRecord.get(addressFields.get('PostalCode')) == null &&
                    newRecord.get(addressFields.get('State')) == null &&
                    newRecord.get(addressFields.get('Country')) == null
                  )
                {
                    continue; //skip this record and proceed to next record in the loop/trigger
                }
            }
            recordIdsToBeUpdated.add((Id)newRecord.get('Id'));
        }
        
        if (!recordIdsToBeUpdated.isEmpty()){
            if (geocodingServiceToUse == 'Maps') {
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