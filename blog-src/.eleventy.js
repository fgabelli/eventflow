const rssPlugin = require("@11ty/eleventy-plugin-rss");
const Image = require("@11ty/eleventy-img");                                                                                                                              
const markdownIt = require("markdown-it");
const mdAnchor = require("markdown-it-anchor");                                                                                                                           
const mdAttrs = require("markdown-it-attrs");
const mdFootnote = require("markdown-it-footnote");                                                                                                                       
const slugify = require("slugify");
const pluginTOC = require("eleventy-plugin-toc");
                                                                                                                                                                          
module.exports = function (eleventyConfig) {                                                                                                                              
  eleventyConfig.addPlugin(rssPlugin);
  eleventyConfig.addPlugin(pluginTOC, { tags: ["h2"], ul: true, wrapper: "nav", wrapperClass: "toc" });
                                                                                                                                                                          
  // Passthrough assets                                                                                                                                                   
  eleventyConfig.addPassthroughCopy({ "src/assets": "blog/assets" });
                                                                                                                                                                          
  // Markdown                                                                                                                                                             
  const md = markdownIt({ html: true, linkify: true, typographer: true })
    .use(mdAnchor, {                                                                                                                                                      
      permalink: mdAnchor.permalink.headerLink(),
      slugify: (s) => slugify(s, { lower: true, strict: true, locale: "it" }),                                                                                            
    })                                                                                                                                                                    
    .use(mdAttrs)                                                                                                                                                         
    .use(mdFootnote);                                                                                                                                                     
  eleventyConfig.setLibrary("md", md);
                                                                                                                                                                          
  // Collections                                                                                                                                                          
  eleventyConfig.addCollection("posts", (api) =>
    api.getFilteredByGlob("src/blog/posts/*.md")
      .filter((p) => p.date <= new Date())
      .sort((a, b) => b.date - a.date)
  );

  // English blog collection (separate dir, no date-gating)
  eleventyConfig.addCollection("postsEn", (api) =>
    api.getFilteredByGlob("src/blog/posts-en/*.md")
      .filter((p) => p.date <= new Date())
      .sort((a, b) => b.date - a.date)
  );

  // Filters
  eleventyConfig.addFilter("dateIta", (d) =>
    new Date(d).toLocaleDateString("it-IT", {
      year: "numeric", month: "long", day: "numeric",
    })
  );
  eleventyConfig.addFilter("dateEn", (d) =>
    new Date(d).toLocaleDateString("en-GB", {
      year: "numeric", month: "long", day: "numeric",
    })
  );
  eleventyConfig.addFilter("isoDate", (d) => {
    if (!d) return new Date().toISOString();
    try { return new Date(d).toISOString(); } catch(e) { return new Date().toISOString(); }
  });                                                                                                  
  eleventyConfig.addFilter("readingTime", (content) => {                                                                                                                  
    const words = (content || "").replace(/<[^>]+>/g, "").split(/\s+/).length;
    return Math.max(1, Math.round(words / 220));                                                                                                                          
  });                                                                                                                                                                     
  eleventyConfig.addFilter("absoluteUrl", (url, base) =>                                                                                                                  
    new URL(url, base).toString()                                                                                                                                         
  );                                                                                                                                                                      
  
  // Shortcode immagini responsive con WebP/AVIF                                                                                                                          
  eleventyConfig.addAsyncShortcode("img", async function (src, alt, sizes = "(min-width: 800px) 800px, 100vw", loading = "lazy") {
    if (!alt) throw new Error(`Manca alt per ${src}`);                                                                                                                    
    const metadata = await Image(`src/${src}`, {                                                                                                                          
      widths: [400, 800, 1200],                                                                                                                                           
      formats: ["avif", "webp", "jpeg"],                                                                                                                                  
      outputDir: "./dist/blog/assets/img/",                                                                                                                               
      urlPath: "/blog/assets/img/",                                                                                                                                       
    });                                                                                                                                                                   
    return Image.generateHTML(metadata, {                                                                                                                                 
      alt, sizes, loading, decoding: "async",                                                                                                                             
    });         
  });                                                                                                                                                                     
  
  eleventyConfig.addShortcode("year", () => String(new Date().getFullYear()));                                                                                                                                                                     
                
  return {                                                                                                                                                                
    dir: {      
      input: "src",
      output: "dist",
      includes: "_includes",
      data: "_data",                                                                                                                                                      
    },
    markdownTemplateEngine: "njk",                                                                                                                                        
    htmlTemplateEngine: "njk",                                                                                                                                            
    templateFormats: ["md", "njk", "11ty.js"],
  };                                                                                                                                                                      
};
