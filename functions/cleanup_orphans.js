/**
 * Temporary Cloud Function to clean orphaned attendees.
 * Deploy this, trigger via HTTP, then remove it.
 */
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

exports.cleanupOrphanedAttendees = onRequest(async (req, res) => {
  const db = admin.firestore();
  
  const attendeesSnap = await db.collection('attendees').get();
  console.log(`Found ${attendeesSnap.size} total attendees`);

  // Collect unique eventIds
  const eventIds = new Set();
  attendeesSnap.docs.forEach(doc => {
    const data = doc.data();
    if (data.eventId) eventIds.add(data.eventId);
  });

  // Check which events still exist
  const existingEvents = new Set();
  for (const eventId of eventIds) {
    const eventDoc = await db.collection('events').doc(eventId).get();
    if (eventDoc.exists) existingEvents.add(eventId);
  }

  // Find orphans
  const orphans = attendeesSnap.docs.filter(doc => {
    const data = doc.data();
    return !data.eventId || !existingEvents.has(data.eventId);
  });

  console.log(`Deleting ${orphans.length} orphaned attendees...`);

  // Delete in batches
  const batchSize = 500;
  for (let i = 0; i < orphans.length; i += batchSize) {
    const batch = db.batch();
    orphans.slice(i, i + batchSize).forEach(doc => batch.delete(doc.ref));
    await batch.commit();
  }

  res.json({ 
    total: attendeesSnap.size, 
    orphaned: orphans.length, 
    remaining: attendeesSnap.size - orphans.length,
    status: 'cleaned' 
  });
});
