# Geocoding in Salesforce Field Service

The Salesforce platform provide the ability to geocode addresses using the [Geocoding Data Integration Rules](https://help.salesforce.com/s/articleView?id=sf.data_dot_com_clean_admin_automatically_get_geocodes_for_addresses.htm&type=5) which are also [enabled for Salesforce Field Service objects](https://help.salesforce.com/s/articleView?id=sf.fs_location_tracking.htm&language=en_US&type=5) when Field Service is enabled in your Salesforce org. However, if you want to use a different geocoding service, like Google or Salesforce Maps, you have to build the integration with that service.

This project provides example integration with both [Google's Geocoding API](https://developers.google.com/maps/documentation/geocoding/overview) and [Salesforce Maps Geocoding](https://developer.salesforce.com/docs/atlas.en-us.maps_developer_guide.meta/maps_developer_guide/maps_apex_batchgeocode.htm). Additionally, a Google API showcase application is included to test the Google Geocoding API and the [Google Distance Matrix API](https://developers.google.com/maps/documentation/distance-matrix/overview).

# Prerequisites

- Salesforce Field Service licenses
- Salesforce Field Service enabled and configured, including the Field Serivce Managed Package
- Salesforce Maps licenses
- Salesforce Maps Managed Packaged installed
- Google API Key

# Setup

- Deploy metadata to your org
- Assign the "Field Service Geocoding Permissions" permission set to your user
- Assign the right Salesforce Maps permission set(s) and/or permission set license to your user
- Create an org-wide custom setting for "Google API Key" and enter your Google API Key 
- Create an org-wide custom setting for "Geocoding Service" and provide the value "Google" or "Maps" depending on which geocoding service to use

# Usage

This example comes with an Apex Trigger on the Service Appointment object which geocodes the address if any of the address fields have been changed. The following fields have been added to the Service Appointment object to capture geocoding specific information:

| Label                         | API Name                         | Type      | Description                                                    |
|-------------------------------|----------------------------------|-----------|----------------------------------------------------------------|
| Geocode                       | Geocode__c                       | Formula   | Latitude and Longitude comma-separated                         |
| Geocoding Last Update         | Geocoding_Last_Update__c         | Datetime  | Timestamp of when the address was last geocoded                |
| Geocoding Message             | Geocoding_Message__c             | Text Area | Message describing the result of geocoding including any error |
| Geocoding Status              | Geocoding_Status__c              | Picklist  | "Success" or "Error"                                           |
| Geocoding View in Google Maps | Geocoding_View_in_Google_Maps__c | Formula   | Hyperlink to open Google Maps using Latitude and Longitude     |

If you want to implement this on another object, create these fields on that object, otherwise exceptions will be thrown due to missing fields.

# Google API Showcase

The Google API Showcase application can be used to test the Google Geocoding API to geocode an address. Additionally, the Google Distance Matrix API can be tested to calculate the distance and travel time between multiple addresses. Open the Google API Showcase application from the App Launcher and provide your Google API Key to test these APIs.
