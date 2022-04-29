if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1  " Don't load another plugin for this buffer

au BufRead *.{md,mdx,mdown,mkd,mkdn,markdown,mdwn} call orgmark#rebuildMarks()
au BufWrite *.{md,mdx,mdown,mkd,mkdn,markdown,mdwn} call orgmark#rebuildMarks()
