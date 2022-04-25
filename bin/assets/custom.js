/*======================================================================*/
/* ref: https://github.com/lotabout/hexo-filter-fix-cjk-spacing/blob/master/lib/fix-cjk-spacing.js */
var cjk_chars = "([\u2000-\u206f\u3000-\u312F\u3200-\u32ff\u3400-\u4dbf\u4e00-\u9fff\uac00-\ud7af\uf900-\ufaff\uff00-\uffee])";
var cjk_lines = new RegExp(cjk_chars+ "((?:\n|\r\n)[ \t]*)(?=" + cjk_chars+ ")", 'g');

function join_cjk(text) {
  return text.replace(cjk_lines, "$1");
}

function fix_cjk_spacing(content) {
  var regx_backtick = /(\s*)(`{3,}|~{3,}) *(.*) *\n([\s\S]+?)\s*\2(\n+|$)/g;
  var tmp_array;
  var start_index = 0;
  var new_content = [];
  while ((tmp_array = regx_backtick.exec(content)) !== null) {
    // add all
    new_content.push(join_cjk(content.substr(start_index, tmp_array.index - start_index)));

    // add code block
    new_content.push(tmp_array[0]);
    start_index = regx_backtick.lastIndex;
  }

  new_content.push(join_cjk(content.substr(start_index)));
  return new_content.join('');
}

/*======================================================================*/
// load markdown and fix CJK spacing
var markdownBase64 = '#markdown-base64#';
var markdown = decodeURIComponent(escape(window.atob(markdownBase64)))
var markdownFixed = fix_cjk_spacing(markdown)

/*======================================================================*/
// setup marked and highlight
var toc = []
var renderer = (function () {
    var renderer = new marked.Renderer();
    renderer.heading = function (text, level, raw) {
        var anchor = this.options.headerPrefix + raw.toLowerCase().replace(/[^\w]+/g, '-');
        toc.push({
            anchor: anchor,
            level: level,
            text: text
        });
      return `<h${level} id="${anchor}"><a class="header-anchor" href="#${anchor}"></a>${text}</h${level}>\n`
    };

    // mermaid
    renderer.defaultCode = renderer.code;
    renderer.code = function(code, language) {
      if (language === 'mermaid') {
        return '<div class="mermaid">'+code+'</div>'
      } else {
        return renderer.defaultCode(code, language)
      }
    }
    return renderer;
})();

marked.setOptions({
  renderer: renderer,
  highlight: function(code, lang) {
    const language = hljs.getLanguage(lang) ? lang : 'plaintext';
    return hljs.highlight(code, { language }).value;
  },
  langPrefix: 'hljs language-', // highlight.js css expects a top-level 'hljs' class.
  pedantic: false,
  gfm: true,
  breaks: false,
  sanitize: false,
  smartLists: true,
  smartypants: false,
  xhtml: false
});

/*======================================================================*/
// parse markdown and render
document.getElementById('content').innerHTML = marked.parse(markdownFixed);

/*======================================================================*/
// MathJax settigns
MathJax.Hub.Config({"HTML-CSS": { preferredFont: "TeX", availableFonts: ["STIX","TeX"], linebreaks: { automatic:true }, EqnChunk: (MathJax.Hub.Browser.isMobile ? 10 : 50) },
    tex2jax: { inlineMath: [ ["$", "$"], ["\\(","\\)"] ], processEscapes: true, ignoreClass: "tex2jax_ignore|dno",skipTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code']},
    TeX: {  noUndefined: { attributes: { mathcolor: "red", mathbackground: "#FFEEEE", mathsize: "90%" } }, Macros: { href: "{}" } },
    messageStyle: "none"
}); 


MathJax.Hub.Queue(function() {
    var all = MathJax.Hub.getAllJax(), i;
    for(i=0; i < all.length; i += 1) {
        all[i].SourceElement().parentNode.className += ' has-jax';
    }
});

