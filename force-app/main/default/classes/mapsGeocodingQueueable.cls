/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Queueable class to geocode address using Salesforce Maps API. Queueable is used in order to
* be able to chain requests as the API allows a maximum of 50 addresses to be geocoded per callout
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
public class mapsGeocodingQueueable implements Queueable, Database.AllowsCallouts {

    public Set<Id> recordIds;
    public String objAPIName;
    public Map<String, String> addressFields;

    public void execute(QueueableContext context) {

        mapsGeocodingUtil.updateLatLngForAddresses(recordIds, objAPIName, addressFields);

    }    

}