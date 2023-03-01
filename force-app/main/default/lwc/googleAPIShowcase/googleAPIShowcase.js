/**
 * Purpose: Example Lightning Web Component to use the Google Geocoding API and the Google Distance Matrix API
 * to geocode address information and calculate travel times between multiple locations.
 * IMPORTANT: This code is not intended to be deployed to a Salesforce production environment.
 * It is intended as an example of how to utilise the Google APIs for Salesforce Field Service scenarios.
 * 
 * Author: Patrick Brinksma (Salesforce)
 * 
 */
import { LightningElement, api, wire, track } from 'lwc';
import geoCodeAddress from '@salesforce/apex/GoogleAPIController.geoCodeAddress';
import getTravelTimes from '@salesforce/apex/GoogleAPIController.getTravelTimes';

// import standard toast event
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class GoogleAPIShowcase extends LightningElement {
    // Google API Key (see: https://cloud.google.com/docs/authentication/api-keys)
    @api googleAPIKey = '';
    @api rememberAPIKey = false;
    
    // Address structure with a default example
    @api address = {
        street : 'Leidseplein 2',
        postalcode : '1017 PT',
        city : 'Amsterdam',
        state : 'Noord-Holland',
        country : 'Netherlands'
    };

    // Google API call results
    @api geoResults;  
    @api dispatchMatrixResults;
    @api distanceMatrix; 

    // Active tab in tabset
    @api activeTab = 'apiKey';

    // Connected Callback
    connectedCallback(){
        this.googleAPIKey = this.getCookie('GoogleAPIKey');
        if (this.googleAPIKey){
            this.rememberAPIKey = true;
        }
    }    

    // Keep track of active tab
    handle_setActiveTab(event){
        this.activeTab = event.target.value;
    }

    // Handle Inputfield changes for Input fields
    handle_InputFieldChange(event){
        const field = event.target.name;
        if (field === 'street'){
            this.address.street = event.target.value;
        } else if (field === 'postalcode'){
            this.address.postalcode = event.target.value;
        } else if (field === 'city'){
            this.address.city = event.target.value;
        } else if (field === 'state'){
            this.address.state = event.target.value;
        } else if (field === 'country'){
            this.address.country = event.target.value;
        } else if (field === 'googleapikey'){
            this.googleAPIKey = event.target.value;
            if (this.rememberAPIKey == true){
                this.createCookie('GoogleAPIKey', this.googleAPIKey, 365);
            }            
        } else if (field === 'rememberAPIKey'){
            this.rememberAPIKey = event.target.checked;
            if (this.rememberAPIKey == true){
                this.createCookie('GoogleAPIKey', this.googleAPIKey, 365);
            } else {
                this.clearCookie('GoogleAPIKey');
            }
        }
    }

    // Handle record form address changes
    handle_addressInputChange(event){
        this.address = {
            street : event.target.street,
            postalcode : event.target.postalCode,
            city : event.target.city,
            state : event.target.state,
            country : event.target.country
        };
    }

    // Clear Geocode address fields
    handle_ClearGeoCodeForm(event){
        this.address = {
            street : '',
            postalcode : '',
            city : '',
            state : '',
            country : ''
        };
    }

    // Geocode the address and show the results
    handle_GeoCodeSubmit(event){

        if (!this.validateGoogleAPIKey()){
            return;
        }

        geoCodeAddress({ 
            apiKey : this.googleAPIKey,
            street : this.address.street, 
            postalcode : this.address.postalcode, 
            city : this.address.city,
            state : this.address.state,
            country : this.address.country
        })
        .then(result => {
            this.geoResults = result;
            result = JSON.parse(result);
            if (result.status !== 'OK'){
                const event = new ShowToastEvent({
                    title : 'Geocoding Results',
                    message : 'Google API status is not OK: ' + result.status,
                    variant : 'error'
                });
                this.dispatchEvent(event);
            } else {
                const event = new ShowToastEvent({
                    title: 'Geocoding Results',
                    message: 'Address successfully geocoded and added as location for travel time calculation.',
                    variant: 'success'
                });
                this.dispatchEvent(event);
                // Add location to distance matrix array
                this.locations.push(
                    {
                        id : ++this.locIndex,
                        lat: result.results[0].geometry.location.lat,
                        lng: result.results[0].geometry.location.lng
                    }
                );  
                this.activeTab = 'travelTimes';              
            }
        })
        .catch(error => {
            console.error(error);
            const event = new ShowToastEvent({
                title : 'Error',
                message : 'Error:' + error.message,
                variant : 'error'
            });
            this.dispatchEvent(event);
        });

    }

    // Locations for the Google Distance Matrix API
    // Keep track of the index for locations
    locIndex = 0;
    @track locations = [];

    get locations(){
        return locations;
    }

    // When a new Location instance is added
    handle_AddLocation(event){        
        this.locations.push({
            id: this.locIndex,
            lat: 0,
            lng: 0
        });
        ++this.locIndex;
    }

    // When a specific Location is removed
    handle_RemoveLocation(event){
        let newLoc = [...this.locations];
        newLoc.forEach((loc, index) => {
            if (loc.id == event.target.dataset.index){
                newLoc.splice(index, 1);
            }
        });
        this.locations = newLoc;
    }

    // Handle updates to the lat/lng of Locations
    handle_LocationInputChange(event){
        let newLoc = [...this.locations];
        newLoc.forEach((loc, index) => {
            if (loc.id == event.target.dataset.index){
                let updatedLoc = {
                    id : loc.id,
                    lat : event.target.latitude,
                    lng : event.target.longitude
                };
                newLoc[index] = updatedLoc;
            }
        });
        this.locations = newLoc;
    }

    // Clear Locations
    handle_ClearLocations(event){
        let newLoc = [...this.locations];
        newLoc.splice(0, newLoc.length);
        this.locations = newLoc;
    }

    // Google Distance Matrix API
    handle_TravelTimesSubmit(event){

        if (!this.validateGoogleAPIKey()){
            return;
        }

        getTravelTimes({ 
            apiKey : this.googleAPIKey,
            locationsJson : JSON.stringify(this.locations)
        })
        .then(result => {
            this.dispatchMatrixResults = result;
            const event = new ShowToastEvent({
                title: 'Travel Times Results',
                message: 'See the results for the details...',
                variant: 'success'
            });
            this.distanceMatrix = this.calcDistanceMatrix(JSON.parse(result));
            this.dispatchEvent(event);
        })
        .catch(error => {
            console.error(error);
            const event = new ShowToastEvent({
                title : 'Error',
                message : 'Error:' + error.message,
                variant : 'error'
            });
            this.dispatchEvent(event);
        });

    }

    validateGoogleAPIKey(){
        if (!this.googleAPIKey){
            const event = new ShowToastEvent({
                title : 'Error',
                message : 'Please provide a valid Google API Key',
                variant : 'error'
            });
            this.dispatchEvent(event);   
            this.activeTab = 'apiKey';
            return false;         
        }
        return true;
    }

    // Convert Distance Matrix results in custom structure
    calcDistanceMatrix(distanceResults){
        const distances = [];
        let i = 0;
        distanceResults["rows"].forEach(row => {
            let j = 0;
            row["elements"].forEach(element => {
                let duration;
                let distance;
                if (element.status === 'OK'){
                    duration = element["duration"]["value"] + ' seconds';
                    distance = element["distance"]["value"] + ' meters';
                } else {
                    duration = 'N/A';
                    distance = 'N/A';
                }
                distances.push({ 
                    id          : i,  
                    status      : element.status,
                    from        : this.locations[i]["lat"] + ',' + this.locations[i]["lng"],
                    fromAddress : distanceResults["origin_addresses"][i],
                    to          : this.locations[j]["lat"] + ',' + this.locations[j]["lng"],
                    toAddress   : distanceResults["destination_addresses"][j],
                    duration    : duration,
                    distance    : distance 
                });
                ++j;
            });
            ++i;
        });
        return distances;
    }

    // Helper functions
    createCookie(name, value, days) {
        var expires;
        if (days) {
            const date = new Date();
            date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
            expires = "; expires=" + date.toGMTString();
        }
        else {
            expires = "";
        }
        document.cookie = name + "=" + escape(value) + expires + "; path=/";
    }
    
    setCookie(name, value) {
        this.createCookie(name, value, null);
    }

    clearCookie(name) {
        this.createCookie(name, '', null);
    }

    getCookie(name) {
        var cookieString = "; " + document.cookie;
        var parts = cookieString.split("; " + name + "=");
        if (parts.length === 2) {
            return parts.pop().split(";").shift();
        }
        return null;
    }

}