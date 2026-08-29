module.exports = {
  layout: "layouts/post.njk",
  ogType: "article",
  lang: "en",
  locale: "en_US",
  eleventyComputed: {
    // EN posts publish at /en/blog/<slug>/ ; no date-gating (all counterparts already live in IT)
    permalink: (data) => `/en/blog/${data.page.fileSlug}/index.html`,
    altEn: (data) => `https://ticketto.it/en/blog/${data.page.fileSlug}/`,
    altIt: (data) =>
      data.itSlug ? `https://ticketto.it/blog/${data.itSlug}/` : null,
  },
};
