/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Apex Trigger for Service Appointment for geocoding the address
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
trigger ServiceAppointmentGeocodingTrigger on ServiceAppointment (after insert, after update) {
    geocodingUtil.processRecords((Map<Id, SObject>) trigger.oldMap, (Map<Id, SObject>) trigger.newMap, trigger.isInsert);
}