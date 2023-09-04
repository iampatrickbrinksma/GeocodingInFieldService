/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Purpose: Example class to use the Google Geocoding API and the Google Distance Matrix API
* to geocode address information and calculate travel times between multiple locations. This class
* contains methods to be used by custom components and Flow
* IMPORTANT: This code is not intended to be deployed to a Salesforce production environment.
* It is intended as an example of how to utilise the Google APIs for Salesforce Field Service scenarios.
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <patrick@brinksma.es>
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
public class GoogleAPIController {

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * If Google API Key is in the Custom Settings "Google API Key"
    * it can be retrieved here. Please consider the security implications of
    * providing the API Key via a Custom Setting, see: https://help.salesforce.com/articleView?id=sf.cs_schema_settings.htm&type=5
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    public static String googleAPIKey {
        get {
            if (googleAPIKey == null){
                GoogleAPIKey__c gAPIKey = GoogleAPIKey__c.getInstance();
                if (gAPIKey != null && gAPIKey.API_Key__c != null){
                    googleAPIKey = gAPIKey.API_Key__c;
                }
            }
            return googleAPIKey;
        }
        set;
    }

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Method to be used to gecode and address from a Ligtning Component (Aura or LWC)
    * For the purpose of this example, the Google API Key is provided by the Lightning Component
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @param    apiKey          Google API Key
    * @param    street          Street of the adres
    * @param    postalcode      Postalcode / Zip of the adres
    * @param    city            City of the adres
    * @param    state           State of the adres
    * @param    country         Country of the adres
    * @return   JSON representation of geocoding result (RESTGoogleMapAPI.GoogleGeoCodeResult)
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    @AuraEnabled(cacheable = true)
    public static String geoCodeAddress(String apiKey, String street, String postalcode, String city, String state, String country){
        try {
            // Create address request object
            RESTGoogleMapAPI.GoogleAddress address = new RESTGoogleMapAPI.GoogleAddress(
                street,
                postalcode,
                city,
                state,
                country
            );
            // Instantiate with API Key
            RESTGoogleMapAPI gMap = new RESTGoogleMapAPI(apiKey);
            // Geocode the address
            RESTGoogleMapAPI.GoogleGeoCodeResult result = gMap.geoCodeAddress(address);      
            // Return the results
            return JSON.serialize(result);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    } 

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Get Latitude and Longitude of a given address in a synchronous method
    * Method can called from another Apex Class, but not in Trigger context as DML is not allowed! 
    * Please refer to the future calls in this class for this purpose.
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @param    apiKey          Google API Key
    * @param    street          Street of the adres
    * @param    postalcode      Postalcode / Zip of the adres
    * @param    city            City of the adres
    * @param    state           State of the adres
    * @param    country         Country of the adres
    * @return   JSON representation of geocoding result (geoCodeResult)
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */        
    public static geoCodeResult getLatLngForAddress(String apiKey, String street, String postalcode, String city, String state, String country){
        try {
            // return location
            geoCodeResult geoCodeResult = new geoCodeResult();
            // Create address request object
            RESTGoogleMapAPI.GoogleAddress address = new RESTGoogleMapAPI.GoogleAddress(
                street,
                postalcode,
                city,
                state,
                country
            );
            // Instantiate Google API call
            RESTGoogleMapAPI gMap = new RESTGoogleMapAPI(apiKey);
            // Geocode the address
            RESTGoogleMapAPI.GoogleGeoCodeResult result = gMap.geoCodeAddress(address);      
            // Parse results
            geoCodeResult.status = result.status;
            geoCodeResult.errorMessage = gMap.validateResultStatusCode(result.status);
            // If successful, add geolocation
            if (result.status == 'OK'){
                geoCodeResult.loc = System.Location.newInstance(
                    result.results[0].geometry.location.lat, 
                    result.results[0].geometry.location.lng
                );
                geoCodeResult.accuracy = result.results[0].geometry.location_type;
            }
            // Return location data
            return geoCodeResult;

        } catch (Exception e) {
            throw new RESTGoogleMApAPI.RESTGoogleMapAPIException(e.getMessage() + ' - ' + e.getStackTraceString());
        }
    }   

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Structure to return the Geocoding results including the status and lat/lng
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */        
    public class geoCodeResult {
        public String status;
        public String errorMessage;
        public String accuracy;
        public System.Location loc;
    } 
     
    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Apex Action to be used in Flow to Geocode an address
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @param    requests          List<FlowRequest>
    * @return   List<FlowResult>
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */            
    @InvocableMethod(label='Geocode Address' description='Geocode address using Google Geocoding API. Google API Key required!' category='Google API')
    public static List<FlowResult> geocodeAddress(List<FlowRequest> requests) {
        // Initiate return result list
        List<FlowResult> results = new List<FlowResult>();
        // Loop through the requests
        // TODO - As a maximum of 100 callouts are allowed per transaction
        // if the Flow is used in BULK, this might lead to an exception!
        for (FlowRequest request : requests){
            // Instantiate result
            FlowResult result = new FlowResult();
            // Prepare input for API call
            RESTGoogleMapAPI.GoogleAddress address = new RESTGoogleMapAPI.GoogleAddress(
                request.Street,
                request.PostalCode,
                request.City,
                request.State,
                request.Country
            );
            // Instantiate Google API call
            RESTGoogleMapAPI gMap = new RESTGoogleMapAPI(request.apiKey);
            // Execute Google API call
            RESTGoogleMapAPI.GoogleGeoCodeResult geoCodeResult = gMap.geoCodeAddress(address);      
            // Validate if it was successful
            result.Status = geoCodeResult.status;
            result.errorMessage = gMap.validateResultStatusCode(result.status);
            if (geoCodeResult.status == 'OK'){
                // Result is OK, get coordinates
                result.Latitude = geoCodeResult.results[0].geometry.location.lat;
                result.Longitude = geoCodeResult.results[0].geometry.location.lng;
            }  
            result.accuracy = geoCodeResult.results[0].geometry.location_type;
            results.add(result);      
        }
        // Return result list
        return results;
    }

    /**
     * Request structure for invocable method "geocodeAddress"
     */
    public class FlowRequest{
        @InvocableVariable(label='Google API Key' required=true)
        public String apiKey;
        @InvocableVariable(label='Street')
        public String Street;
        @InvocableVariable(label='Postalcode or Zipcode')
        public String PostalCode;
        @InvocableVariable(label='City')
        public String City;
        @InvocableVariable(label='State or Province')
        public String State;
        @InvocableVariable(label='Country')
        public String Country;
    }

    /**
     * Response structure for invocable method "geocodeAddress"
     */    
    public class FlowResult{
        @InvocableVariable(label='Status' Description='Success: OK, otherwise the call has failed')
        public String status;
        @InvocableVariable(label='Error Message' Description='If Success is not OK, details of the error')
        public String errorMessage;
        @InvocableVariable(label='Latitude')
        public Decimal Latitude;
        @InvocableVariable(label='Longitude')
        public Decimal Longitude;
        @InvocableVariable(label='Accuracy')
        public String accuracy;        
    }

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Method to be used to retrieve travel distance and time between multiple locations using a Ligtning Component (Aura or LWC)
    * For the purpose of this example, the Google API Key is provided by the Lightning Component   
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @param    apiKey              Google API Key
    * @param    locationsJson       List<GoogleAPIController.travelTimeLocation>
    * @return   JSON format of RESTGoogleMapAPI.GoogleDistanceMatrixResult
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */     
    @AuraEnabled(cacheable = true)
    public static String getTravelTimes(String apiKey, String locationsJson){
        try {
            // locationsJson is expected as a JSON format of:
            // [{ Id : 0, lat : 52.34563, lng : 5.345323 }, { Id : 1, lat : 51.34563, lng : 5.445323 }]
            // Deserialize into object and put in a List of String of latitude, longitude
            List<GoogleAPIController.travelTimeLocation> listOfLocation = (List<GoogleAPIController.travelTimeLocation>)JSON.deserialize(locationsJson, List<GoogleAPIController.travelTimeLocation>.class);
            List<String> listOfLocString = new List<String>();
            for (GoogleAPIController.travelTimeLocation loc : listOfLocation){
                listOfLocString.add(loc.lat + ',' + loc.lng);
            }
            // Instantiate with API Key
            RESTGoogleMapAPI gMap = new RESTGoogleMapAPI(apiKey);
            // Get the travel distance and times
            RESTGoogleMapAPI.GoogleDistanceMatrixResult result = gMap.distanceMatrix(listOfLocString);  
            // return JSON as a string 
            return JSON.serialize(result);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }    

    /**
     * Structure for travel time calculations
     */    
    public class travelTimeLocation{
        public Integer id;
        public Decimal lat;
        public Decimal lng;
    }

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Method to be used to retrieve travel distance and time between multiple locations
    * Returns a list of a reference of the record Ids (from and to) and the distance / travel time  
    * ────────────────────────────────────────────────────────────────────────────────────────────────
    * @param    requests        List<distanceMatrixRequest>
    * @return   List<distanceMatrixResult>
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    public static List<distanceMatrixResult> getTravelTimesForMultipleLocations(List<distanceMatrixRequest> requests){
        List<distanceMatrixResult> results;
        if (!requests.isEmpty()){
            List<String> locations = new List<String>();
            for (distanceMatrixRequest request : requests){
                locations.add(request.location.getLatitude() + ',' + request.location.getLongitude());
            }
            // Instantiate with API Key
            RESTGoogleMapAPI gMap = new RESTGoogleMapAPI(googleAPIKey);
            // Get the travel distance and times
            RESTGoogleMapAPI.GoogleDistanceMatrixResult gMapResuls = gMap.distanceMatrix(locations);
            // When the result indicate the call was successful
            if (gMapResuls.status == 'OK'){
                // Process results
                results = new List<distanceMatrixResult>();
                Integer rowIndex = 0;
                for (distanceMatrixRequest requestFrom : requests){
                    List<RESTGoogleMapAPI.Element> elements = gMapResuls.rows[rowIndex].elements;
                    Integer elementIndex = 0;
                    for (RESTGoogleMapAPI.Element element : elements){
                        distanceMatrixResult result = new distanceMatrixResult();
                        result.status = element.status;
                        result.statusMsg = gMap.validateResultStatusCode(result.status);
                        if (result.status == 'OK'){
                            result.fromId = requestFrom.Id;
                            result.fromAddress = gMapResuls.origin_addresses[rowIndex];
                            result.toId = requests[elementIndex].Id;
                            result.toAddress = gMapResuls.destination_addresses[elementIndex];
                            result.distanceInMeters = element.distance.value;
                            result.travelTimeInSeconds = element.duration.value;
                        }
                        results.add(result);
                        elementIndex++;
                    }
                    rowIndex++;
                }
            } else {
                // raise exception
                throw new RESTGoogleMapAPI.RESTGoogleMapAPIException('Google API call to Distance Matrix API returned: ' + gMapResuls.status);
            }
        } 
        return results;
    }

    /**
     * Structure for request to call the Google Distance Matrix API
     */
    public class distanceMatrixRequest{
        public Id Id;
        public System.Location location;
    }

    /**
     * Structure for capturing results of the Google Distance Matrix API
     */
    public class distanceMatrixResult{
        public String status;
        public String statusMsg;
        public Id fromId;
        public String fromAddress;
        public Id toId;
        public String toAddress;
        public Integer distanceInMeters;
        public Integer travelTimeInSeconds {
            get;
            set {
                travelTimeInSeconds = value;
                if (travelTimeInSeconds != null){
                    Decimal min = travelTimeInSeconds / 60.0;
                    travelTimeInMinutes = (Integer)min.round(System.RoundingMode.UP);
                }
            }
        }
        public Integer travelTimeInMinutes;
    }

}