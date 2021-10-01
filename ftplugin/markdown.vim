setlocal foldmethod=manual
setlocal foldopen-=search
setlocal foldtext=orgmark#FoldText()

command! -buffer OrgMarkCycle call orgmark#cycle()
command! -buffer OrgToggleFold call orgmark#toggleFold()

au BufRead *.{md,mdx,mdown,mkd,mkdn,markdown,mdwn} call orgmark#rebuildMarks()
au BufWrite *.{md,mdx,mdown,mkd,mkdn,markdown,mdwn} call orgmark#rebuildMarks()

nmap <buffer> <silent> <S-Tab> :OrgMarkCycle<CR>
nmap <buffer> <silent> <TAB> :OrgToggleFold<CR>
