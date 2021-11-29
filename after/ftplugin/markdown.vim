au BufRead *.{md,mdx,mdown,mkd,mkdn,markdown,mdwn} call orgmark#rebuildMarks()
au BufWrite *.{md,mdx,mdown,mkd,mkdn,markdown,mdwn} call orgmark#rebuildMarks()

