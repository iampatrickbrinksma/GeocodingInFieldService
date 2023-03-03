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
                    sObj.put('Geocoding_Status__c', 'Success');
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