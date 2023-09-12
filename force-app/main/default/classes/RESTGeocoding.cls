/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Geocoding exposed via a custom Apex REST API
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <patrick@brinksma.es>
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
@RestResource(urlMapping='/geocoding/*')
global with sharing class RESTGeocoding {

    @HttpGet
    global static void geoCodeAddress(){
        // Start performance measure of the geocoding performance
        Long start = System.now().getTime();
        
        // REST Context
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        // Get the GET parameters
        String servicetouse = req.params.get('servicetouse');
        String street = req.params.get('street');
        String postalcode = req.params.get('postalcode');
        String city = req.params.get('city');
        String state = req.params.get('state');
        String country = req.params.get('country');

        geocodingUtil.geoCodeResult geoCodeResult;

        // If the request explicitely includes the geocoding service to use
        if (servicetouse.toLowerCase() == 'google' || servicetouse.toLowerCase() == 'salesforce maps'){
            geoCodeResult = geocodingUtil.geoCodeAddress(servicetouse, street, postalcode, city, state, country);
        } else {
            geoCodeResult = geocodingUtil.geoCodeAddress(street, postalcode, city, state, country);
        }

        // Capture performance of the geocoding process
        geoCodeResult.durationInMs = System.now().getTime() - start;

        // Set response body
        res.responseBody = Blob.valueOf(JSON.serialize(geoCodeResult));        
        
        // Return void
        return;
    }

}