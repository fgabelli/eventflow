/**
 * Backfill script: adds 'language: "it"' to all existing events
 * that don't have a language field set.
 *
 * Usage:
 *   cd functions
 *   node backfill_event_language.js
 *
 * Requires: firebase-admin (already in functions/package.json)
 */

const admin = require('firebase-admin');

// Initialize with default credentials (uses GOOGLE_APPLICATION_CREDENTIALS or default SA)
admin.initializeApp({ projectId: 'eventflow-3541b' });

const db = admin.firestore();

async function backfill() {
  console.log('🔍 Fetching all events without language field...');

  const eventsRef = db.collection('events');
  const snapshot = await eventsRef.get();

  if (snapshot.empty) {
    console.log('✅ No events found. Nothing to do.');
    return;
  }

  const docsToUpdate = [];
  snapshot.forEach((doc) => {
    const data = doc.data();
    if (!data.language) {
      docsToUpdate.push(doc.ref);
    }
  });

  if (docsToUpdate.length === 0) {
    console.log('✅ All events already have a language field.');
    return;
  }

  console.log(`📝 Found ${docsToUpdate.length} events without language. Setting to "it"...`);

  // Firestore batch limit is 500
  const batchSize = 500;
  for (let i = 0; i < docsToUpdate.length; i += batchSize) {
    const batch = db.batch();
    const chunk = docsToUpdate.slice(i, i + batchSize);
    for (const ref of chunk) {
      batch.update(ref, { language: 'it' });
    }
    await batch.commit();
    console.log(`  ✅ Batch ${Math.floor(i / batchSize) + 1}: updated ${chunk.length} events`);
  }

  console.log(`\n🎉 Done! Updated ${docsToUpdate.length} events with language: "it"`);
}

backfill()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Error:', err);
    process.exit(1);
  });
