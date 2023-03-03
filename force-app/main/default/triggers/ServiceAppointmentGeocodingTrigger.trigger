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
trigger ServiceAppointmentGeocodingTrigger on ServiceAppointment (before insert, before update, after insert, after update) {
    geocodingUtil.processRecords((Map<Id, SObject>) Trigger.oldMap, (Map<Id, SObject>) Trigger.newMap, Trigger.isBefore, Trigger.isInsert);
}