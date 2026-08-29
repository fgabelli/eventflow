const isFuture = (data) => data.page.date > new Date();

// IT slug -> EN slug (only articles that have an English counterpart).
// normativa-eventi-italia-siae and biglietteria-associazioni-onlus are IT-only.
const EN_SLUG = {
  "alternative-eventbrite-italia": "eventbrite-alternatives",
  "biglietteria-online-guida": "online-ticketing-guide",
  "check-in-evento-smartphone": "event-check-in-with-smartphone",
  "commissioni-biglietteria-eventi": "event-ticketing-fees",
  "errori-organizzazione-eventi-aziendali": "corporate-event-mistakes",
  "evento-aziendale-checklist": "corporate-event-checklist",
  "gestione-fasce-orarie-eventi": "event-time-slots",
  "pagina-registrazione-evento-che-converte": "event-registration-page-that-converts",
  "promuovere-evento-marketing": "how-to-promote-an-event",
};

module.exports = {
  layout: "layouts/post.njk",
  ogType: "article",
  eleventyComputed: {
    permalink: (data) =>
      isFuture(data) ? false : `/blog/${data.page.fileSlug}/index.html`,
    eleventyExcludeFromCollections: (data) => isFuture(data),
    altIt: (data) => `https://ticketto.it/blog/${data.page.fileSlug}/`,
    altEn: (data) =>
      EN_SLUG[data.page.fileSlug]
        ? `https://ticketto.it/en/blog/${EN_SLUG[data.page.fileSlug]}/`
        : null,
  },
};
