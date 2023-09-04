/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Apex Trigger for Service Appointment for geocoding the address
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <patrick@brinksma.es>
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
trigger ServiceAppointmentGeocodingTrigger on ServiceAppointment (before insert, before update, after insert, after update) {
    geocodingUtil.processRecords((Map<Id, SObject>) Trigger.oldMap, (Map<Id, SObject>) Trigger.newMap, Trigger.isBefore, Trigger.isInsert);
}