/**
 * Backfills `organizations/{orgId}/public/profile` with only safe public fields:
 * name, logo, primaryColor, blocked, trusted, plan.
 */
import fs from 'fs';

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
  const orgs = orgsRes.documents || [];
  console.log(`Found ${orgs.length} organizations to backfill public/profile...`);

  let count = 0;
  for (const org of orgs) {
    const id = org.name.split('/').pop();
    const f = org.fields || {};
    const fields = {
      name: { stringValue: f.name?.stringValue || '' },
      blocked: { booleanValue: f.blocked?.booleanValue === true },
      trusted: { booleanValue: f.trusted?.booleanValue === true },
      plan: { stringValue: f.plan?.stringValue || 'free' },
    };
    if (f.logo?.stringValue) fields.logo = { stringValue: f.logo.stringValue };
    if (f.primaryColor?.stringValue) fields.primaryColor = { stringValue: f.primaryColor.stringValue };

    const patchUrl = `${BASE_URL}/organizations/${id}/public/profile`;
    await fetchJson(patchUrl, {
      method: 'PATCH',
      body: JSON.stringify({ fields }),
    });
    count++;
  }
  console.log(`✅ Backfilled public/profile for ${count} organizations.`);
}

main().catch((err) => {
  console.error('❌ Error:', err);
  process.exit(1);
});
