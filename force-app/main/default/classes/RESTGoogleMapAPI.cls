/**
 * Purpose: Example class to call the Google Geocoding API and the Google Distance Matrix API
 * to geocode address information and calculate travel times between multiple locations.
 * IMPORTANT: This code is not intended to be deployed to a Salesforce production environment.
 * It is intended as an example of how to utilise the Google APIs for Salesforce Field Service scenarios.
 * 
 * Author: Patrick Brinksma (Salesforce)
 * 
 */
public class RESTGoogleMapAPI {

    // Custom Exception
    public class RESTGoogleMapAPIException extends Exception {}

    // Google API KEY: https://developers.google.com/maps/documentation/javascript/get-api-key
    // Throw an exception if the API Key is not provided
    public String GoogleAPIKey {
        get{
            if (GoogleAPIKey == null){
                throw new RESTGoogleMapAPIException('Please provide a valid Google API KEY!');
            } else {
                return GoogleAPIKey;
            }
        }
        set;
    }

    // Class Constructor
    public RESTGoogleMapAPI(String GoogleAPIKey){
        // Set Google API Key
        this.GoogleAPIKey = GoogleAPIKey;
    }

    // Google Geocoding API
    public GoogleGeoCodeResult geoCodeAddress(GoogleAddress address){
        // Build base endpoint
        final String GEOCODEENDPOINT = 'callout:Google_Maps_API/geocode/json?key=' + EncodingUtil.urlEncode(GoogleAPIKey, 'UTF-8') + '&language=en-US&address=';
        // Concatenate address values
        String addresRequest = address.concatenateDetails();
        // Build final endpoint
        String endPoint = GEOCODEENDPOINT + EncodingUtil.urlEncode(addresRequest, 'UTF-8');
        // Return object
        GoogleGeoCodeResult result = new GoogleGeoCodeResult();
        // Prepare HTTP request
        Http http = new Http();
        HttpResponse response = new HTTPResponse();
        HttpRequest request = new HttpRequest(); 
        request.setHeader('referer', Url.getOrgDomainUrl().toExternalForm());   
        // GET method
        request.setMethod('GET');
        request.setEndpoint(endPoint);
        // HTTP Request
        response = http.send(request); 
        // Parse results into object
        result = (GoogleGeoCodeResult)JSON.deserialize(response.getBody(), GoogleGeoCodeResult.class);
        // Return results of the call
        return result;
    }

    // Google Distance Matrix API
    public GoogleDistanceMatrixResult distanceMatrix(List<String> locations){
        // Build base endpoint
        final String DISTANCEENDPOINT = 'callout:Google_Maps_API/distancematrix/json?key=' + EncodingUtil.urlEncode(GoogleAPIKey, 'UTF-8') + '&language=en-US&units=metric&mode=driving&avoid=tolls&';
        // Latitude and Longitude concatenated with the | character
        String origins = EncodingUtil.urlEncode(String.join(locations, '|'), 'UTF-8');
        // Build final endpoint
        String endPoint = DISTANCEENDPOINT + 'origins=' + origins + '&destinations=' + origins;
        // return object
        GoogleDistanceMatrixResult result = new GoogleDistanceMatrixResult();
        // Prepare HTTP request
        Http http = new Http();
        HttpResponse response = new HTTPResponse();
        HttpRequest request = new HttpRequest();    
        // GET method
        request.setMethod('GET');
        request.setEndpoint(endPoint);
        // HTTP Request
        response = http.send(request); 
        // Parse results into object
        result = (GoogleDistanceMatrixResult)JSON.deserialize(response.getBody(), GoogleDistanceMatrixResult.class);     
        // return results of the call
        return result;
    }

    // Input structure for Geocoding request
    public class GoogleAddress {
        public String street;
        public String postalcode;
        public String city;
        public String state;
        public String country;

        public GoogleAddress(String street, String postalcode, String city, String state, String country){
            this.street = street;
            this.postalcode = postalcode;
            this.city = city;
            this.state = state;
            this.country = country;
        }

        public String concatenateDetails(){
            return this.street + ',' + this.postalcode + ',' + this.city + ',' + this.state + ',' + this.country;
        }
    }

    // Validates the Status code which is part of the response of the Google APIs
    // The status codes are defined https://developers.google.com/maps/documentation/distance-matrix/overview and 
    // https://developers.google.com/maps/documentation/geocoding/overview
    public String validateResultStatusCode(String status){
        String returnMsg;
        switch on status {
            when 'OK' {
                returnMsg = 'Success';
            }
            when 'ZERO_RESULTS' {
                returnMsg = 'API call successful, but the address could not be found';
            }
            when 'OVER_DAILY_LIMIT' {
                returnMsg = 'The API Key is missing or invalid, billing is not activated or the payment method is invalid or a cap has been exceeded';
            }
            when 'OVER_QUERY_LIMIT' {
                returnMsg = 'The API quota has been exceeded';
            }
            when 'REQUEST_DENIED' {
                returnMsg = 'The API request was denied';
            }                    
            when 'INVALID_REQUEST' {
                returnMsg = 'The API request was invalid, please validate the parameters';
            }  
            when 'UNKNOWN_ERROR' {
                returnMsg = 'An unknown error occurred, please try again';
            }                  
            when else {
                returnMsg = 'An unknown error occurred, please contact the System Administrator';
            }
        }
        return returnMsg;    
    }

    // Response structure from Google for Geocoding
    // Created by using the JSON to Object converter https://json2csharp.com/json-to-pojo
    // and adjusted to work with Apex (data types)    
    public class AddressComponent{
        public String long_name;
        public String short_name;
        public List<String> types;
    }
    
    public class Location{
        public double lat;
        public double lng;
    }
    
    public class Northeast{
        public double lat;
        public double lng;
    }
    
    public class Southwest{
        public double lat;
        public double lng;
    }
    
    public class Viewport{
        public Northeast northeast;
        public Southwest southwest;
    }
    
    public class Geometry{
        public Location location;
        public String location_type;
        public Viewport viewport;
    }
    
    public class PlusCode{
        public String compound_code;
        public String global_code;
    }
    
    public class Result{
        public List<AddressComponent> address_components;
        public String formatted_address;
        public Geometry geometry;
        public String place_id;
        public PlusCode plus_code;
        public List<String> types;
    }
    
    public class GoogleGeoCodeResult{
        public List<Result> results;
        public String status;
    }

    // Response structure for Google Distance Matrix API
    // Created by using the JSON to Object converter https://json2csharp.com/json-to-pojo
    // and adjusted to work with Apex (data types)    
    public class Duration{
        public Integer value;
        public String text;
    }
    
    public class Distance{
        public Integer value;
        public String text;
    }
    
    public class Element{
        public String status;
        public Duration duration;
        public Distance distance;
    }
    
    public class Row{
        public List<Element> elements;
    }
    
    public class GoogleDistanceMatrixResult{
        public String status;
        public List<String> origin_addresses;
        public List<String> destination_addresses;
        public List<Row> rows;
    }    

}