/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Queueable class to geocode address using Salesforce Maps API. Queueable is used in order to
* be able to chain requests as the API allows a maximum of 50 addresses to be geocoded per callout
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <patrick@brinksma.es>
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
public class mapsGeocodingQueueable implements Queueable, Database.AllowsCallouts {

    public Set<Id> recordIds;
    public String sObjApiName;
    public Map<String, String> addressFields;

    public void execute(QueueableContext context) {
        mapsGeocodingUtil.updateLatLngForAddresses(recordIds, sObjApiName, addressFields);
    }    

}