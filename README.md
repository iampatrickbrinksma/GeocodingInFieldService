# Geocoding in Salesforce Field Service

The Salesforce platform provide the ability to geocode addresses using the [Geocoding Data Integration Rules](https://help.salesforce.com/s/articleView?id=sf.data_dot_com_clean_admin_automatically_get_geocodes_for_addresses.htm&type=5) which are also [enabled for Salesforce Field Service objects](https://help.salesforce.com/s/articleView?id=sf.fs_location_tracking.htm&language=en_US&type=5) when Field Service is enabled in your Salesforce org. However, if you want to use a different geocoding service, like Google or Salesforce Maps, you have to build the integration with that service.

This project provides example integration with both [Google's Geocoding API](https://developers.google.com/maps/documentation/geocoding/overview) and [Salesforce Maps Geocoding](https://developer.salesforce.com/docs/atlas.en-us.maps_developer_guide.meta/maps_developer_guide/maps_apex_batchgeocode.htm). You can configure to use one service for all your geocoding needs, or configure to use a different service per country. For example, on the Service Appointment object you want all addresses geocoded using the standard Data Integration Rule except the ones in Thailand for which you want to use Salesforce Maps. 

Additionally, a Google API showcase application is included to test the Google Geocoding API and the [Google Distance Matrix API](https://developers.google.com/maps/documentation/distance-matrix/overview) with which you can determine the distance and travel time between multiple locations.

# Disclaimer

IMPORTANT: This code is not intended to be deployed to a Salesforce production environment. It is intended as an example of how to utilise the Google Geocoding API, the Google Distance Matrix API and the Salesforce Maps API for Salesforce Field Service scenarios. If you do decide to adopt this code into your project, please make it your own, make it production ready, write proper Apex Test classes and perform extensive testing.
> This is not a Salesforce product and is not officially supported by Salesforce. Furthermore, to use the Google APIs you need to acquire a Google API key and to use Salesforce Maps you need to obtain the necessary Salesforce Maps license (please contact your Account Executive).

# Prerequisites

- Salesforce Field Service licenses
- Salesforce Field Service enabled and configured, including the Field Serivce Managed Package
- Salesforce Maps licenses
- Salesforce Maps Managed Packaged installed
- Google API Key
    - You can [restrict access to your Google API Key](https://cloud.google.com/docs/authentication/api-keys?&_ga=2.32744121.-666786310.1677594976#http) by using the explicitly added HTTP Header 'referer' which contains the full My Domain url of your salesforce org

# Setup

- Deploy metadata to your org
    - *Note: If you don't want the custom fields (in the example on the ServiceAppointment object) to be deployed, remove them from the metadata, and from the permission set. The Apex code validates if the fields exist on the object, and only then populates them.*
- Assign the "Field Service Geocoding Permissions" permission set to your user
- Assign the right Salesforce Maps permission set(s) and/or permission set license to your user
- Create an org-wide value for the custom setting "Google API Key" and enter your Google API Key 
- Create an org-wide value for the custom setting "Geocoding Service", enable the geocoding service (checkbox) and provide the value "Google" or "Maps" depending on which geocoding service you want to use
- An Apex Trigger is included on the ServiceAppointment object as an example, and so:
- Inactivate the Data Integration Rule "Geocodes for Service Appointment Address" to prevent geocoding using this service, otherwise it will override the geocoding values
- Optionally add the 5 new fields on to the Service Appointment Page Layout as shown here (Geocoding Details section):

![image](https://user-images.githubusercontent.com/78381570/222396173-117198d7-ac83-4242-88c2-2801027088ac.png)

# Usage

## Asynchronous

The geocoding of addresses is done asynchronously because a callout is required and Salesforce does not allow callouts to be made from an Apex Trigger. Queueable classes are used to perform the geocoding asynchronously, which can be chained in case you perform a bulk update.

## Custom Settings and Custom Metadata

The behavior can be controlled with the custom setting: "Geocoding Service". Because this is a hierarchical custom setting, it can be controlled on Org, Profile and User level:
* To enable the geocoding logic, make sure the "Geocoding Enabled" checkbox field is checked
* If "Geocoding Service" is populated, all addresses, for the activated objects (Apex Trigger), will be geocoded using this service. Accepted values: "Google" for the Google Geocoding API or "Salesforce Maps" for the Salesforce Maps Geocoder API. If empty, Data Integration Rules will be used or country specific configurations as defined in the custom metadata: "Geocoding Country Config"

If you leave the "Geocoding Service" in the custom setting empty, you can control for what country which geocoding service is used creating records in the "Geocoding Country Config" custom metadata:
* Enter a reference value in the "Geocoding Country Config Name" and "Label" fields
* Enter the Country name as used in the address fields in the "Country" field
* Select either Google or Salesforce Maps as geocoding service

*If the Data Integration Rule for an object is active, but you've configured to use a different geocoding service, any update made by the Data.com clean user will be reverted!*

*If the country is not listed, and the "Geocoding Service" in the custom setting is empty, addresses for that country will be geocoded via the Data Integration Rules if the object is supported and the rule active.*

## Apex Trigger

This example comes with an Apex Trigger on the Service Appointment object which geocodes the address if any of the address fields have been changed. The following fields have been added to the Service Appointment object to capture geocoding specific information:

| Label                         | API Name                         | Type      | Description                                                    |
|-------------------------------|----------------------------------|-----------|----------------------------------------------------------------|
| Geocode                       | Geocode__c                       | Formula   | Latitude and Longitude comma-separated                         |
| Geocoding Last Update         | Geocoding_Last_Update__c         | Datetime  | Timestamp of when the address was last geocoded                |
| Geocoding Message             | Geocoding_Message__c             | Text Area | Message describing the result of geocoding including any error |
| Geocoding Status              | Geocoding_Status__c              | Picklist  | "Success" or "Error"                                           |
| Geocoding View in Google Maps | Geocoding_View_in_Google_Maps__c | Formula   | Hyperlink to open Google Maps using Latitude and Longitude     |

## Other Objects

If you want to implement this on any another object:
- Create the custom fields on the object, otherwise exceptions will be thrown due to missing fields (TODO: Conditionally set values if fields exist)
- Create an Apex Trigger for the object copying the code from the included Apex Trigger: ServiceAppointmentGeocoding
- If the object is supported by a Data Integration Rule, inactivate that rule

If the object has address fields which are named differently, like the Account Billing Address fields, pass a Map<String, String> with the field name mapping into the geocodingUtil.ProcessRecords method. The following example shows how to do this for the billing address on Account:

    trigger AccountGeocodingTrigger on Account (after insert, after update){
        Map<String, String> addressFields = new Map<String, String>{
            'Street' => 'BillingStreet',
            'PostalCode' => 'BillingPostalCode',
            'City' => 'BillingCity',
            'State' => 'BillingState',
            'Country' => 'BillingCountry',
            'Latitude' => 'BillingLatitude',
            'Longitude' => 'BillingLongitude',
            'GeocodeAccuracy' => 'BillingGeocodeAccuracy'
        };

        geocodingUtil.processRecords((Map<Id, SObject>) trigger.oldMap, (Map<Id, SObject>) trigger.newMap, addressFields, trigger.isInsert);
    }

This allows you to use geocoding for an object with customer address fields as well instead of using an address compound field.

## Bulk Operations

The Google Geocoding API allows you to request geocodes for only a single address per API call. Salesforce allows 100 callouts per transaction. The Salesforce Maps bulk API allows up to 50 addresses per API call. To allow for larger chunk sizes the queueable classes that perform the geocoding logic will be chained once the chunk size is larger than the 100 or 50 records (addresses)

> It is important to know that chaining queueables is limited to a depth of 5 in developer, scratch and demo orgs. Typically one Apex Trigger execution processes a maximum of 200 records per transaction so this should not cause a problem. However when data is being processed in bulk with a larger batch size it can result in an exception...

## Apex REST API

The logic to geocode an address has been exposed as a REST API endpoint (Apex Class: RESTGeocoding). To use this endpoint sent an HTTP GET request to

    /services/apexrest/geocoding

with the following GET parameters:
* street
* postalcode
* city
* state
* country
* servicetouse *(If you want to explicitly set the geocoding service to use. Accepted values are "Google" and "Saleforce Maps")*

# Google API Showcase

The Google API Showcase application can be used to test the Google Geocoding API to geocode an address. Additionally, the Google Distance Matrix API can be tested to calculate the distance and travel time between multiple addresses. Open the Google API Showcase application from the App Launcher and provide your Google API Key to test these APIs as shown here:

![image](https://user-images.githubusercontent.com/78381570/222376942-5c9785b9-78a9-4dfa-9a42-1fd2794dab13.png)

In the Google Geocoding API tab you can enter address details or search for an address.

![image](https://user-images.githubusercontent.com/78381570/222377217-7a0f49ac-4599-43d9-acb1-4e1a820afffe.png)

When you hit the Submit button, the address will be geocoded, and the result will be added as a new Location for the Distance Matrix API as shown here:

![image](https://user-images.githubusercontent.com/78381570/222377423-3371c8d6-3412-4684-b341-034b26799e68.png)

In the Google Geocoding API tab you van view the raw response from the API to validate the format as shown here:

![image](https://user-images.githubusercontent.com/78381570/222377548-2b3099a3-5dfd-43fb-bd8a-a27168a13108.png)

The Google Distance Matrix API tab allows you to calculate travel time between multiple locations. You can add locations using the Google Geocoding API tab as shown before, or you can add a new (or remove) location manually.

![image](https://user-images.githubusercontent.com/78381570/222377980-689b261d-371e-4fc8-a469-92c418fe69e8.png)

When you hit the Submit button the output will be shown in a formatted way.

![image](https://user-images.githubusercontent.com/78381570/222378078-867e67b4-fb02-4850-ab57-9a6300aaebed.png)

And the raw API Response can also be viewed.

![image](https://user-images.githubusercontent.com/78381570/222378139-c9f315fd-8107-434a-a13f-d5c6465cb20b.png)

The Google APIs accept a variety of parameters, which can be found in the documentation. In this example code the following parameters have been hardcoded:

## Google API Parameters

The API parameters can be found in Google's documentation. For this example the following parameters are hardcoded in the request URL.

* Geocoding API
    * Format = json
    * Language = en-US
* Distance Matrix API
    * Format = json
    * Language = en-US
    * Units = metric
    * Mode = driving
    * Avoid = tolls


