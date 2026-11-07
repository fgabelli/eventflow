/**
 * One-shot grandfathering script: sets `trusted: true` on existing legitimate organizations
 * (orgs with >= 1 attendee on any event, active/trialing subscription or paid plan,
 * created before 2026-10-01, or explicitly named core/client orgs),
 * excluding suspicious watchlist accounts (mildredfost, rajichan827, corpus.au).
 */
import fs from 'fs';

const WATCHLIST_PATTERNS = /mildredfost|rajichan827|corpus\.au|litedl|aiqseo/i;
const EXPLICIT_TRUSTED_NAMES = [
  'DEVERO SPA',
  'Depaola.davide',
  'The Spa',
  'Polilogoi Srl',
  'Polilogoi',
  'Bitle',
  'Bitle srls',
  'TEST',
  'Apple Review Organization',
  'AREL',
];

const cfgPath = `${process.env.HOME}/.config/configstore/firebase-tools.json`;
const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
const token = cfg.tokens?.access_token;
if (!token) {
  console.error('No access token found in firebase-tools.json');
  process.exit(1);
}

const BASE_URL = 'https://firestore.googleapis.com/v1/projects/eventflow-3541b/databases/(default)/documents';

async function fetchJson(url, options = {}) {
  const res = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}: ${await res.text()}`);
  }
  return res.json();
}

async function main() {
  const orgsRes = await fetchJson(`${BASE_URL}/organizations?pageSize=300`);
  const eventsRes = await fetchJson(`${BASE_URL}/events?pageSize=300`);
  const orgs = orgsRes.documents || [];
  const events = eventsRes.documents || [];

  const cutoff = new Date('2026-10-01T00:00:00Z');
  let updated = 0;
  let skippedWatchlist = 0;

  for (const org of orgs) {
    const id = org.name.split('/').pop();
    const f = org.fields || {};
    const name = f.name?.stringValue || '';
    const email = f.email?.stringValue || '';
    const plan = f.plan?.stringValue || 'free';
    const subStatus = f.subscriptionStatus?.stringValue || '';
    const createdAtStr = f.createdAt?.timestampValue || f.createdAt?.stringValue || org.createTime;
    const createdAt = createdAtStr ? new Date(createdAtStr) : new Date();

    if (WATCHLIST_PATTERNS.test(name) || WATCHLIST_PATTERNS.test(email)) {
      console.log(`⚠️ Skipping watchlist org: ${id} (${name})`);
      skippedWatchlist++;
      continue;
    }

    const orgEvents = events.filter((e) => e.fields?.orgId?.stringValue === id);
    const maxAtt = orgEvents.reduce((m, e) => Math.max(m, Number(e.fields?.attendeesCount?.integerValue || 0)), 0);

    const hasAttendees = maxAtt >= 1;
    const hasActiveSub = plan !== 'free' || subStatus === 'active' || subStatus === 'trialing';
    const isPreOctober = createdAt < cutoff;
    const isExplicit = EXPLICIT_TRUSTED_NAMES.some((n) => n.toLowerCase() === name.trim().toLowerCase());

    if (hasAttendees || hasActiveSub || isPreOctober || isExplicit) {
      if (f.trusted?.booleanValue === true) {
        console.log(`✓ Already trusted: ${id} (${name})`);
        continue;
      }
      const patchUrl = `${BASE_URL}/organizations/${id}?updateMask.fieldPaths=trusted`;
      await fetchJson(patchUrl, {
        method: 'PATCH',
        body: JSON.stringify({
          fields: {
            trusted: { booleanValue: true },
          },
        }),
      });
      updated++;
      if (hasAttendees || hasActiveSub || isExplicit) {
        console.log(`✅ Marked trusted: ${id} | "${name}" (plan=${plan}, maxAtt=${maxAtt})`);
      }
    }
  }

  console.log(`\n🎉 Grandfathering complete. Updated: ${updated}, Skipped watchlist: ${skippedWatchlist}`);
}

main().catch((err) => {
  console.error('❌ Error:', err);
  process.exit(1);
});
