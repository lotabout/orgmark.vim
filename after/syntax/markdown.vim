syn match   orgmarkCheckboxEmpty /\[ \]/ contained
syn match   orgmarkCheckboxPending /\[o\]/ contained
syn match orgmarkCheckboxComplete /\[X\]/ contained

" copied and modified from vim-markdown
syn region mkdListItemLine start="^\s*\%([-*+]\|\d\+\.\)\s\+" end="$" oneline contains=@mkdNonListItem,mkdListItem,@Spell,orgmarkCheckboxEmpty,orgmarkCheckboxPending,orgmarkCheckboxComplete

if hlexists('gitcommitUnmergedFile')
  highlight default link orgmarkCheckboxEmpty gitcommitUnmergedFile
endif

if hlexists('gitcommitBranch')
  highlight default link orgmarkCheckboxPending gitcommitBranch
endif

if hlexists('gitcommitSelectedFile')
  highlight default link orgmarkCheckboxComplete gitcommitSelectedFile
endif
