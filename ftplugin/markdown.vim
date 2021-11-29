setlocal foldmethod=manual
setlocal foldopen-=search
setlocal foldtext=orgmark#FoldText()

command! -buffer OrgMarkCycle call orgmark#cycle()
command! -buffer OrgToggleFold call orgmark#toggleFold()
command! -buffer -range=% Preview <line1>,<line2>call orgmark#previewMarkdown()

nmap <buffer> <silent> <S-Tab> :OrgMarkCycle<CR>
nmap <buffer> <silent> <TAB> :OrgToggleFold<CR>
