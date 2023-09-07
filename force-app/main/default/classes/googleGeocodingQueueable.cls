/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Queueable class to geocode address using Google Geocoding API. Queueable is used in order to
* be able to chain requests as the Google Geocoding API allows only a single address per request 
* and allows 100 callouts per transaction
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <patrick@brinksma.es>
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
public class googleGeocodingQueueable implements Queueable, Database.AllowsCallouts{

    public Set<Id> recordIds;
    public String sObjApiName;
    public Map<String, String> addressFields;

    public void execute(QueueableContext context) {
        googleGeocodingUtil.updateLatLngForAddresses(sObjApiName, recordIds, addressFields);
    }

}