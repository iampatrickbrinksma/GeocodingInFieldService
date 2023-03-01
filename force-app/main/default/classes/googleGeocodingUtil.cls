/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Util class with methods supporting the geocoding of address using Google Geocoding API
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
public with sharing class googleGeocodingUtil {

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

            if (!recordIdsToBeUpdated.isEmpty()) {
                googleGeocodingQueueable q = new googleGeocodingQueueable();
                q.objAPIName = objApiName;
                q.recordIds = recordIdsToBeUpdated;
                q.addressFields = addressFields;
                System.enqueueJob(q);
            }            
        }
    }      

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Method to geocode addresses for a set of records of an object with standard address field names
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @param    sObjApiName     API Name of the SObject
    * @param    recordIds       Set of record Ids to process
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */ 
    public static void updateLatLngForAddresses(String sObjAPIName, Set<Id> recordIds){
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
        updateLatLngForAddresses(sObjAPIName, recordIds, addressFields);
    }

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Method to geocode addresses for a set of records of an object 
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @param    sObjApiName     API Name of the SObject
    * @param    recordIds       Set of record Ids to process
    * @param    addressFields   Map<String, String> - map of address field to API field name    
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */ 
    public static void updateLatLngForAddresses(String sObjAPIName, Set<Id> recordIds, Map<String, String> addressFields){
        // Existing GeocodeAccuracy values in Salesforce
        Set<String> geoAccuracies = new Set<String>{
            'Address',
            'NearAddress',
            'Block',
            'Street',
            'ExtendedZip',
            'Zip',
            'Neighborhood',
            'City',
            'County',
            'State',
            'Unknown'
        };

        // Query for the records including the address fields, Location fields to update 
        // and limit by 100 records, as one API call will be done per record which 
        // is a restriction of the Google Geocoding API. Salesforce allows a maximum of 100 callouts per transaction
        // See: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_callouts_timeouts.htm         
        String query = 'select Id';
        for (String fieldName : addressFields.values()){
            query += ', ' + fieldName;
        }
        query += ' from ' + sObjAPIName + ' where Id in :recordIds LIMIT 100';

        List<SObject> listOfObj = (List<SObject>) Database.query(query);

        // Loop through the records and Geocode the address
        if (!listOfObj.isEmpty()){
            for (SObject sObj : listOfObj){
                GoogleAPIController.geoCodeResult result = GoogleAPIController.getLatLngForAddress(
                    GoogleAPIController.googleAPIKey,
                    (String)sObj.get(addressFields.get('Street')),
                    (String)sObj.get(addressFields.get('City')),
                    (String)sObj.get(addressFields.get('PostalCode')),
                    (String)sObj.get(addressFields.get('State')),
                    (String)sObj.get(addressFields.get('Country'))
                );
                if (result.status == 'OK'){
                    sObj.put(addressFields.get('Latitude'), result.loc.Latitude);
                    sObj.put(addressFields.get('Longitude'), result.loc.Longitude);
                    sObj.put('Geocoding_Last_Update__c', System.now());
                    if (geoAccuracies.contains(result.accuracy)){
                        sObj.put(addressFields.get('GeocodeAccuracy'), result.accuracy);
                        sObj.put('Geocoding_Message__c', 'Geocoded using Google Geocoding API');
                    } else {
                        sObj.put(addressFields.get('GeocodeAccuracy'), 'Unknown');
                        sObj.put('Geocoding_Message__c', 'Geocoded using Google Geocoding API. Unknown Geocode Accuracy: ' + result.accuracy);
                    }
                }
                recordIds.remove((Id)sObj.get('Id'));
            }
            // Update the records
            update listOfObj;

            // Enqueue if there are more records to be processed
            if (!recordIds.isEmpty()) {
                googleGeocodingQueueable q = new googleGeocodingQueueable();
                q.objAPIName = sObjAPIName;
                q.recordIds = recordIds;
                q.addressFields = addressFields;
                System.enqueueJob(q);
            }                  
        }
    }    
}