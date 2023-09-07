/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Util class with methods supporting the geocoding of address using Salesforce Maps API
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <patrick@brinksma.es>
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
public with sharing class mapsGeocodingUtil {
    
    // The GeoAccuracy values available in Salesforce
    private static Set<String> geoAccuracies = new Set<String>{
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

    // Custom exception for throwing a Salesforce Maps related exception
    public class MapsGeocodingException extends Exception {} 

    public static geocodingUtil.geoCodeResult geoCodeAddress(String street, String postalcode, String city, String state, String country){
        // Return object
        geocodingUtil.geoCodeResult geoCodeResult = new geocodingUtil.geoCodeResult();
        // Concatenate address
        String address = street + ' ' + city + ' ' + state + ' ' + postalcode + ' ' + country;

        Map<string,object> options = new Map<String,Object> {
                    'version' => '1', // Required. Version of the API endpoint. Must be '1'.
                    'address' => address
                };

        // Call the Geocode() method with the address.
        Map<String, Object> result = maps.API.Geocode(options);
        System.debug(result);
        geoCodeResult.status = (Boolean)result.get('success') == true ? 'OK' : 'NOK';
        geoCodeResult.errorMessage = (String)result.get('message');
        if (geoCodeResult.status == 'OK'){
            Map<String, Object> data = (Map<String, Object>)result.get('data');
            String geoAccuracy = (String)data.get('matchLevel');
            if (!geoAccuracies.contains(geoAccuracy)){
                geoAccuracy = 'Unknown';
            }
            geoCodeResult.accuracy = geoAccuracy;
            Map<String, Object> position = (Map<String, Object>)data.get('position');
            geoCodeResult.loc = System.Location.newInstance(
                (Decimal)position.get('lat'),
                (Decimal)position.get('lng')
            );
        }
        // Return the results
        return geoCodeResult;
    }

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Method to geocode addresses for a set of records of an object 
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @param    recordIds       Set of record Ids to process
    * @param    objApiName      API Name of the SObject
    * @param    addressFields   Map<String, String> - map of address field to API field name    
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */ 
    public static void updateLatLngForAddresses(Set<Id> recordIds, String sObjApiName, Map<String, String> addressFields){

        String query = 'select Id';
        for (String fieldName : addressFields.values()){
            query += ', ' + fieldName;
        }
        query += ' from ' + sObjApiName + ' where Id in :recordIds LIMIT 50';

        List<SObject> records = (List<SObject>) Database.query(query);

        if (!records.isEmpty()) {
            Map<String, Boolean> fieldApiNameExists = geocodingUtil.validateObjectFieldExistence(sObjAPIName, geocodingUtil.customGeocodingFields);
            Map<String,Map<String,String>> addressesToSend = new Map<String,Map<String,String>>(); //create map to hold SAs and their addresses to pass to geocoding API
            for (SObject record : records){

                String street = (String) record.get(addressFields.get('Street'));
                String city = (String) record.get(addressFields.get('City'));
                String postalCode = (String) record.get(addressFields.get('PostalCode'));
                String state = (String) record.get(addressFields.get('State'));
                String country = (String) record.get(addressFields.get('Country'));

                String salesforceAddress = '';
                salesforceAddress += street == null ? '' : street  + ', ';
                salesforceAddress += city == null ? '' : city  + ', ';
                salesforceAddress += state == null ? '' : state  + ' ';
                salesforceAddress += postalCode == null ? '' : postalCode  + ' ';
                salesforceAddress += country == null ? '' : country;

                Map<String,String> addressInfo = new Map<String,String>{'address' => salesforceAddress};
                String recordId = (String) record.get('Id');
                recordId = recordId.toLowerCase();
                addressesToSend.put(recordId, addressInfo); //set the key in the map to the SA Id
            }
            
            //serialize the SA and address map into JSON object format
            Map<String, Object> batchOptions = new Map<String, Object> {
                'version' => '2', // Required. Version of the API endpoint.
                'address_info' => JSON.serialize(addressesToSend)
            };
            
            // Geocode using Salesforce Maps Batch API
            Map<String, Object> matrix = maps.API.BatchGeocode(batchOptions); //call maps API to geocode appointments and return results as map of objects

            // System.debug('matrix: ' + matrix);
            // System.debug('matrix keySet: ' + matrix.keySet());

            // If return message contains error, an exception occured
            if (matrix.get('error') != null) {
                // Error occurred for the entire API call, maybe the service is down?
                String errMsg = '';
                errMsg += 'Error code: ' + (String) matrix.get('error_code');
                errMsg += ' Error: ' + JSON.serialize(matrix.get('error'));
                throw new MapsGeocodingException(errMsg);
            } else {
                if (matrix.get('success') == true){
                    // Results are stored in the results array of the response 
                    // which is a map with the Service Appointment Id in lowercase format
                    Map<String, Object> results = (Map<String, Object>)matrix.get('results');

                    for (SObject record : records) {
                        String recordId = (String) record.get('Id');
                        recordId = recordId.toLowerCase();        
                        Map<String, Object> result = (Map<String, Object>)results.get(recordId);

                        if (result != null) {
                            if (result.get('success') == true){
                                Map<String, Object> data = (Map<String, Object>)result.get('data');
                                Map<String, Object> position = (Map<String, Object>)data.get('position');
                                record.put('Latitude', (Decimal)position.get('lat'));
                                record.put('Longitude', (Decimal)position.get('lng'));
                                // This could result in an exception if the 
                                // Salesforce Maps matchLevel values do not match
                                // the geoAccuracy restricted picklist values
                                String matchLevel = (String)data.get('matchLevel');
                                if (!geoAccuracies.contains(matchLevel)){
                                    if (fieldApiNameExists.get('Geocoding_Message__c') == true)
                                        record.put('Geocoding_Message__c', 'Geocoded using Salesforce Maps. Unknown Geocode Accuracy: ' + matchLevel);
                                    matchLevel = 'Unknown';
                                } else {
                                    if (fieldApiNameExists.get('Geocoding_Message__c') == true)
                                        record.put('Geocoding_Message__c', 'Geocoded using Salesforce Maps');
                                }
                                record.put(addressFields.get('GeocodeAccuracy'), matchLevel);
                                if (fieldApiNameExists.get('Geocoding_Status__c') == true)
                                    record.put('Geocoding_Status__c', 'Success');
                                if (fieldApiNameExists.get('Geocoding_Last_Update__c') == true)
                                    record.put('Geocoding_Last_Update__c', System.now());
                            } else {
                                // Something went wrong with a specific address
                                if (result.get('message') != null) {
                                    record.put('Latitude', null);
                                    record.put('Longitude', null);
                                    record.put(addressFields.get('GeocodeAccuracy'), null);
                                    if (fieldApiNameExists.get('Geocoding_Status__c') == true)
                                        record.put('Geocoding_Status__c', 'Error');
                                    if (fieldApiNameExists.get('Geocoding_Last_Update__c') == true)
                                    record.put('Geocoding_Last_Update__c', System.now());
                                    if (fieldApiNameExists.get('Geocoding_Message__c') == true)
                                        record.put('Geocoding_Message__c', (String)result.get('message'));
                                }
                            }
                        }
                        recordIds.remove((Id)record.get('Id'));
                    }
                    update records;

                    // Enqueue if there are more records to be processed
                    if (!recordIds.isEmpty()) {
                        mapsGeocodingQueueable q = new mapsGeocodingQueueable();
                        q.sObjApiName = sObjApiName;
                        q.recordIds = recordIds;
                        q.addressFields = addressFields;
                        System.enqueueJob(q);
                    }                  
                } else {
                    // Something went wrong with the Salesforce Maps API call, but was not an exception
                    // Does this really occur!?
                }
            }
        }
    }
}