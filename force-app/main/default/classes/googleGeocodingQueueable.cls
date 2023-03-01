/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Queueable class to geocode address using Google Geocoding API. Queueable is used in order to
* be able to chain requests as the API allows only a single address per request and Salesforce
* allows 100 callouts per transaction
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
public class googleGeocodingQueueable implements Queueable, Database.AllowsCallouts{

    public Set<Id> recordIds;
    public String objAPIName;
    public Map<String, String> addressFields;

    public void execute(QueueableContext context) {

        googleGeocodingUtil.updateLatLngForAddresses(objAPIName, recordIds, addressFields);

    }

}