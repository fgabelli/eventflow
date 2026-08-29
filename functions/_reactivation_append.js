

// ═══════════════════════════════════════════════════════════════
// ─── REACTIVATION CAMPAIGN (org dormienti) — marketing, temporaneo
// Aggiunto 2026-07-06. Endpoint protetto da token. Rimuovibile.
// ═══════════════════════════════════════════════════════════════
const REACTIVATION_TOKEN = "rz7Qn2reactivTicketto2026";
const REACTIVATION_SUBJECT = "Il tuo primo evento su Ticketto è a 2 minuti";
const REACTIVATION_CTA_URL = "https://ticketto.it/events";

function reactivationEmailHtml(name) {
  const n = (name && String(name).trim()) ? String(name).trim().split(" ")[0] : "ciao";
  return [
    '<div style="font-family: -apple-system, Segoe UI, Roboto, sans-serif; background:#F4F4F8; padding:24px;">',
    '<div style="max-width:520px; margin:0 auto; background:#ffffff; border-radius:16px; overflow:hidden; border:1px solid #ECECF3;">',
    '<div style="background:linear-gradient(135deg,#6366F1,#8B5CF6); padding:28px 32px;">',
    '<span style="color:#fff; font-size:20px; font-weight:700;">🎫 Ticketto</span>',
    '</div>',
    '<div style="padding:32px;">',
    '<p style="font-size:16px; color:#1A1A2E; margin:0 0 16px;">Ciao <strong>' + n + '</strong>,</p>',
    '<p style="font-size:16px; line-height:1.6; color:#333; margin:0 0 16px;">hai creato il tuo account Ticketto ma non hai ancora lanciato il tuo primo evento.</p>',
    '<p style="font-size:16px; line-height:1.6; color:#333; margin:0 0 24px;">Ci vogliono davvero <strong>2 minuti</strong>: dai un nome, scegli i posti, e ottieni un link da condividere. Le iscrizioni arrivano da sole — niente chat infinite, niente fogli Excel da aggiornare a mano.</p>',
    '<div style="text-align:center; margin:0 0 28px;">',
    '<a href="' + REACTIVATION_CTA_URL + '" style="display:inline-block; background:#6366F1; color:#fff; text-decoration:none; font-weight:600; font-size:16px; padding:14px 32px; border-radius:10px;">Crea il tuo evento →</a>',
    '</div>',
    '<p style="font-size:15px; color:#333; margin:0 0 8px;">Qualche idea per partire:</p>',
    '<ul style="font-size:15px; line-height:1.8; color:#333; margin:0 0 8px; padding-left:20px;">',
    '<li>🚌 una gita o un viaggio di gruppo</li>',
    '<li>🎓 un Family Day o un doposcuola</li>',
    '<li>📚 un book club</li>',
    '<li>🎉 una festa o un compleanno</li>',
    '</ul>',
    '<p style="font-size:16px; color:#333; margin:24px 0 0;">A presto,<br>Fabio — Ticketto</p>',
    '</div>',
    '<div style="padding:20px 32px; border-top:1px solid #ECECF3; background:#FAFAFC;">',
    '<p style="font-size:12px; color:#9A9AAE; margin:0; line-height:1.5;">Ricevi questa email perché hai un account su Ticketto. Se non vuoi più riceverle, <a href="mailto:event@ticketto.it?subject=unsubscribe" style="color:#9A9AAE;">clicca qui per disiscriverti</a>.</p>',
    '</div>',
    '</div>',
    '</div>',
  ].join("");
}

exports.sendReactivationCampaign = onRequest({ cors: true }, async (req, res) => {
  const token = req.query.token;
  const mode = req.query.mode; // "test" | "count" | "all"
  const to = req.query.to;
  if (token !== REACTIVATION_TOKEN) { res.status(403).json({ error: "forbidden" }); return; }

  const resend = new Resend(RESEND_API_KEY);
  const headers = { "List-Unsubscribe": "<mailto:event@ticketto.it?subject=unsubscribe>" };

  try {
    if (mode === "test") {
      if (!to) { res.status(400).json({ error: "missing 'to'" }); return; }
      const { data, error } = await resend.emails.send({
        from: EMAIL_FROM, to: [to], subject: REACTIVATION_SUBJECT,
        html: reactivationEmailHtml("Fabio"), headers,
      });
      res.json({ ok: !error, mode: "test", to, id: data && data.id, error });
      return;
    }

    if (mode === "count" || mode === "all") {
      const orgsSnap = await db.collection("organizations").get();
      const now = Date.now();
      const r = { orgsTotal: orgsSnap.size, dormant: 0, skippedInternal: 0, skippedFresh: 0, noEmail: 0, alreadySent: 0, eligible: 0, sent: 0, errors: 0 };
      for (const orgDoc of orgsSnap.docs) {
        const org = orgDoc.data() || {};
        const orgId = orgDoc.id;
        const name = org.name || "";
        const evSnap = await db.collection("events").where("orgId", "==", orgId).limit(1).get();
        if (!evSnap.empty) continue;
        r.dormant++;
        if (/revan|test|apple|prova|demo/i.test(name)) { r.skippedInternal++; continue; }
        let createdMs = 0;
        if (org.createdAt && typeof org.createdAt.toMillis === "function") createdMs = org.createdAt.toMillis();
        else if (org.createdAt) createdMs = Date.parse(org.createdAt) || 0;
        if (createdMs && (now - createdMs) < 7 * 86400000) { r.skippedFresh++; continue; }
        let email = null, displayName = name;
        const userSnap = await db.collection("users").where("organizationIds", "array-contains", orgId).limit(1).get();
        if (!userSnap.empty) { const u = userSnap.docs[0].data(); email = u.email; displayName = u.displayName || name; }
        if (!email && org.email) email = org.email;
        if (!email || !String(email).includes("@")) { r.noEmail++; continue; }
        const logRef = db.collection("reactivation_log").doc(orgId);
        const logDoc = await logRef.get();
        if (logDoc.exists) { r.alreadySent++; continue; }
        r.eligible++;
        if (mode === "count") continue;
        try {
          const { data, error } = await resend.emails.send({
            from: EMAIL_FROM, to: [email], subject: REACTIVATION_SUBJECT,
            html: reactivationEmailHtml(displayName), headers,
          });
          if (error) { r.errors++; }
          else {
            r.sent++;
            await logRef.set({ orgId, email, displayName: displayName || null, sentAt: admin.firestore.FieldValue.serverTimestamp(), resendId: (data && data.id) || null, campaign: "reactivation-2026-07" });
          }
        } catch (e) { r.errors++; }
      }
      res.json({ ok: true, mode, result: r });
      return;
    }

    res.status(400).json({ error: "mode must be test | count | all" });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});
