" Group 1: header
" Group 2: fenced start with language
" Group 3: fenced end
" Group 4: list item

"==================================================
" Helper: build tags for header & fenced code

let s:levelRegexpDict = {
    \ 1: '\v^(#[^#]@=|.+\n\=+$)',
    \ 2: '\v^(##[^#]@=|.+\n-+$)',
    \ 3: '\v^###[^#]@=',
    \ 4: '\v^####[^#]@=',
    \ 5: '\v^#####[^#]@=',
    \ 6: '\v^######[^#]@='
\ }

let s:headerRegex = '\v^#+[^#]*$'
let s:fencedRegex = '\v(^\s*```[^`]+$)|(^\s*```$)'
let s:listRegex = '\v\s*([-+*]|\d+.|[a-z]\))\s'


" calculate the level of current header, assume line (l:num) is a header
function! orgmark#HeaderLevelOf(lnum)
    let l:text = getline(a:lnum)
    for l:key in keys(s:levelRegexpDict)
        if l:text =~ get(s:levelRegexpDict, l:key)
            return l:key
        endif
    endfor
    return 0
endfunction

function! orgmark#getHeaderTag(lnum)
    let l:level = orgmark#HeaderLevelOf(a:lnum)
    return {'type': 'Header', 'level': l:level, 'ln': a:lnum}
endfunction

function! orgmark#getFenceTag(lnum, in_fence)
    let l:text = getline(a:lnum)
    if l:text =~ '^\s*```[^`]\+$' " fenced start with language
        let l:lang = substitute(l:text, '^\s*```', '', '')
        return {'type': 'FenceStart', 'ln': a:lnum}
    elseif !a:in_fence
        return {'type': 'FenceStart', 'ln': a:lnum}
    else
        return {'type': 'FenceEnd', 'ln': a:lnum}
    endif
endfunction

let s:headerRegexes= '\v(^#+[^#]*$)|(^\s*```[^`]+$)|(^\s*```$)'

function! orgmark#buildMarks()
    let l:pos = getpos('.')
    call cursor(1, 1)

    let l:marks = []
    let l:in_fence = v:false

    let [l:lnum, l:col, l:group] = searchpos(s:headerRegexes, 'cpeW')
    while l:group > 1
        if l:group == 2 && !l:in_fence " header
            call add(l:marks, orgmark#getHeaderTag(l:lnum))
        elseif l:group == 3 " fenced code (with language) start
            call add(l:marks, orgmark#getFenceTag(l:lnum, l:in_fence))
            let l:in_fence = v:true
        elseif l:group == 4 " toggle fenced code
            call add(l:marks, orgmark#getFenceTag(l:lnum, l:in_fence))
            let l:in_fence = !l:in_fence
        endif
        let [l:lnum, l:col, l:group] = searchpos(s:headerRegexes, 'Wp')
    endwhile
    call setpos('.', l:pos)
    return l:marks
endfunction

function! orgmark#buildMarksByGrep()
    let l:matchedLines = systemlist('grep --line-number ' . "'" . '\(^#\+[^#]*$\)\|\(^\s*```[^`]\+$\)\|\(^\s*```$\)'. "'", bufnr())

    let l:marks = []
    let l:in_fence = v:false
    for line in l:matchedLines
        let l:splits = split(line, ':')
        let l:lnum = str2nr(l:splits[0])
        let l:line = getline(l:lnum)
        if l:line =~ '\v^#+[^#]*$' && !l:in_fence
            call add(l:marks, orgmark#getHeaderTag(l:lnum))
        elseif l:line =~ '\v^\s*```[^`]+$'
            call add(l:marks, orgmark#getFenceTag(l:lnum, l:in_fence))
            let l:in_fence = v:true
        elseif l:line =~ '\v^\s*```$'
            call add(l:marks, orgmark#getFenceTag(l:lnum, l:in_fence))
            let l:in_fence = !l:in_fence
        endif
    endfor
    return l:marks
endfunction

function! orgmark#ensureMarks()
    if !exists('b:orgmark_marks')
        call orgmark#rebuildMarks()
    endif
    return b:orgmark_marks
endfunction

function! orgmark#rebuildMarks()
    " let b:orgmark_marks = orgmark#buildMarks()
    let b:orgmark_marks = orgmark#buildMarksByGrep()
endfunction


function! orgmark#foldRange(start_line, end_line)
    if a:start_line <= 0 || a:end_line <= 0 || a:start_line >= a:end_line
        return
    endif

    execute a:start_line ',' a:end_line 'fold'
endfunction

"==================================================
" Orgmark Cycle

" Accept 3 modes
" OVERVIEW: show only the first level header
" CONTENTS: show all headers but no content
" SHOW ALL: show everything
function! orgmark#cycleHeader()
    if !exists('b:orgmark_cycle_header_status')
        let b:orgmark_cycle_header_status = 'SHOW ALL'
    endif

    if b:orgmark_cycle_header_status == 'SHOW ALL'
        call orgmark#cycleOverview()
        echo "HEADER: OVERVIEW"
        let b:orgmark_cycle_header_status = 'OVERVIEW'
    elseif b:orgmark_cycle_header_status == 'OVERVIEW'
        call orgmark#cycleContent()
        echo "HEADER: CONTENTS"
        let b:orgmark_cycle_header_status = 'CONTENTS'
    else
        call orgmark#cycleShowAll()
        echo "HEADER: SHOW ALL"
        let b:orgmark_cycle_header_status = 'SHOW ALL'
    endif
endfunction

function! orgmark#cycleShowAll()
    silent! normal! zE
endfunction

function! orgmark#cycleContent()
    let l:saved_lnum = line('.')

    " clear all existing folds
    normal G$
    silent! normal! zE

    let l:marks = orgmark#ensureMarks()

    let l:last_tag = {}
    for tag in filter(copy(l:marks), {idx, tag -> tag.type == 'Header'})
        " tag contains
        " {'type': 'Header', 'level': l:level, 'ln': a:lnum, 'col': a:col}
        if !empty(l:last_tag)
            call orgmark#foldRange(l:last_tag.ln, tag.ln-1)
        endif
        let l:last_tag = tag
    endfor

    if !empty(l:last_tag)
        call orgmark#foldRange(l:last_tag.ln, line('$'))
    endif

    execute l:saved_lnum
endfunction

function! orgmark#cycleOverview()
    let l:saved_lnum = line('.')

    " clear all existing folds
    normal G$
    silent! normal! zE

    let l:marks = orgmark#ensureMarks()

    let l:last_tag = {}
    let l:lowest_level_til_now = 100
    for tag in filter(copy(l:marks), {idx, tag -> tag.type == 'Header'})
        " tag contains {'type': 'Header', 'level': l:level, 'ln': a:lnum, 'col': a:col}
        if tag.level > l:lowest_level_til_now
            continue
        endif

        if !empty(l:last_tag)
            call orgmark#foldRange(l:last_tag.ln, tag.ln - 1)
        endif

        let l:last_tag = tag
        let l:lowest_level_til_now = min([tag.level, l:lowest_level_til_now])
    endfor

    if !empty(l:last_tag)
        call orgmark#foldRange(l:last_tag.ln, line('$'))
    endif

    execute l:saved_lnum
endfunction

"==================================================
" Orgmark ToggleFold

" try to unfold if current line is the start of a fold
" And return true if action is taken
function! orgmark#tryUnfold(...)
    let l:ln = get(a:, 1, line('.'))
    let l:fold_start = foldclosed(l:ln)
    if l:fold_start > 0
        call cursor(l:fold_start, 0)
        silent! normal! zo
        return v:true
    endif
    return v:false
endfunction

function! orgmark#tryFoldHeader()
    let l:marks = orgmark#ensureMarks()
    let l:ln = line('.')
    let l:headerTags = filter(copy(l:marks), {idx, tag -> tag.type == 'Header'})
    let l:tags =  filter(copy(l:headerTags), {idx, tag -> tag.ln == l:ln})
    if empty(l:tags)
        return
    endif

    let l:currentLevel = l:tags[0].level
    let l:tagsWithLeLevel = filter(copy(l:headerTags), {idx, tag -> tag.ln > l:ln && tag.level <= l:currentLevel})
    let l:endLnum = empty(l:tagsWithLeLevel) ? line('$') : l:tagsWithLeLevel[0].ln - 1
    call orgmark#foldRange(l:ln, l:endLnum)
endfunction

function! orgmark#tryFoldFenced()
    let l:marks = orgmark#ensureMarks()
    let l:ln = line('.')

    let l:tags =  filter(copy(l:marks), {idx, tag -> tag.ln == l:ln})
    if empty(l:tags) || (l:tags[0].type != 'FenceStart' && l:tags[0].type != 'FenceEnd')
        return
    endif

    let l:currentTag = l:tags[0]

    if l:currentTag.type == 'FenceStart'
        " find next FenceEnd
        let l:endLnum = line('$')
        for tag in l:marks
            if tag.ln <= l:ln
                continue
            endif
            if tag.type == 'FenceEnd'
                let l:endLnum = tag.ln
                break
            endif
        endfor
        call orgmark#foldRange(l:currentTag.ln, l:endLnum)
    else
        " find previous FenceStart
        let l:start_line = 0
        for tag in l:marks
            if tag.ln > l:ln
                break
            endif
            if tag.type == 'FenceStart'
                let l:start_line = tag.ln
            endif
        endfor
        call orgmark#foldRange(l:start_line, l:currentTag.ln)
    endif
endfunction

function! orgmark#tryFoldListItem()
    let l:ln = line('.')
    let l:indent = indent(l:ln)
    let l:endLnum = line('$')

    " find the next content whose indent is less or equal to current indent
    for line in range(l:ln + 1, l:endLnum)
        if !empty(getline(line)) && indent(line) <= l:indent
            let l:endLnum = line
            break
        endif
    endfor

    " search back and skip empty lines
    for line in range(l:endLnum - 1, l:ln, -1)
        if !empty(getline(line))
            break
        endif
        let l:endLnum = line
    endfor

    call orgmark#foldRange(l:ln, l:endLnum - 1)
endfunction

function! orgmark#toggleFold()
    let l:unfold = orgmark#tryUnfold()
    if l:unfold
        return
    endif

    let l:text = getline('.')
    if l:text =~ s:headerRegex
        call orgmark#tryFoldHeader()
    elseif l:text =~ s:fencedRegex
        call orgmark#tryFoldFenced()
    elseif l:text =~ s:listRegex
        call orgmark#tryFoldListItem()
    endif
endfunction

function! orgmark#FoldText()
  let line = getline(v:foldstart)
  return line
endfunction

"==================================================
" Orgmark Fold List

function! orgmark#listType(text)
    let l:index = 0
    let l:len = len(a:text)
    " skip leading white spaces

    while l:index <= l:len && (a:text[l:index] == " " || a:text[l:index] == "\t")
        let l:index = l:index + 1
    endwhile

    let l:liststr = a:text[l:index:]
    if l:liststr =~ '^[-+*] *'
        return l:liststr[0]
    elseif l:liststr =~# '^\d\+\. *'
        return "N."
    elseif l:liststr =~# '^[a-zA-Z]\+\. *'
        return "A."
    elseif l:liststr =~# '^\d\+) *'
        return "N)"
    elseif l:liststr =~# '^[a-zA-Z]\+) *'
        return "A)"
    else
        return ""
    endif
    'https://www.safaribooksonline.com/library/view/kafka-the-definitive/9781491936153/ch04.html'
endfunction

" If the current line is a list item, return current line number
" Else search up til the first
" If nothing is found, return [0, 0]
function! orgmark#findInnerParentList()
    let l:current_line = line('.')
    let l:indent = indent(l:current_line)
    while l:current_line > 0
        let l:current_indent = indent(l:current_line)
        if l:current_indent <= l:indent && orgmark#listType(getline(l:current_line)) != ''
            return [l:current_line, l:current_indent]
        endif
        let l:current_line = l:current_line - 1
    endwhile
    return [0, 0]
endfunction

function! orgmark#findOuterMostParentList()
    let l:current_line = line('.')
    let l:last_list_type = ''
    let l:last_indent = 10000
    let l:ret_line = -1

    while l:current_line > 0
        let l:line = getline(l:current_line)
        let l:list_type = orgmark#listType(l:line)
        let l:indent = indent(l:current_line)
        if empty(l:line)
            " pass
        elseif l:indent == 0 && l:list_type == ''
            " already found list and find a non-list top level line
            break
        elseif l:indent < l:last_indent
            let l:last_indent = l:indent
            let l:last_list_type = l:list_type
            let l:ret_line = l:current_line
        elseif l:indent == l:last_indent && l:last_list_type != '' && l:list_type == l:last_list_type
            let l:ret_line = l:current_line
        elseif l:indent == 0 && l:last_list_type != '' && l:list_type != l:last_list_type
            " indent = 0 to prevent this condition
            " - Content
            "   Still          <-- False positoive here
            "   - Sublit
            break
        endif

        let l:current_line -= 1
    endwhile

    return [l:ret_line, l:last_indent]
endfunction


" Will find all sub-lists that could be expanded with start_line and indent
" callback: takes two args: (start_line, end_line_inclusive)
function! orgmark#doWithList(start_line, indent, callback)
    let l:indent = a:indent
    let l:start = a:start_line
    let l:current_type = orgmark#listType(getline(a:start_line))
    if l:current_type == ''
        return
    endif

    " search back for indent level and not the same type
    while l:start > 0
        if indent(l:start) < l:indent
            break
        endif
        if indent(l:start) == l:indent && orgmark#listType(getline(l:start)) != l:current_type
            break
        endif
        let l:start -= 1
    endwhile

    " search down
    while empty(getline(l:start)) && l:start <= line('$')
        let l:start += 1
    endwhile

    let l:running_start = l:start
    let l:running_end = l:start
    let l:ret = v:false

    for line in range(l:start + 1, line('$'))
        let l:running_end = line
        let l:current_indent = indent(line)
        let l:current_list_type = orgmark#listType(getline(line))

        if empty(getline(line)) || l:current_indent > l:indent
            continue
        elseif l:current_indent == l:indent && l:current_list_type == l:current_type
            let l:ret = a:callback(l:running_start, line - 1)
            let l:running_start = line
        else
            " same level, non list
            break
        endif
    endfor

    " search back and skip empty lines
    for line in range(l:running_end - 1, l:running_start, -1)
        let l:running_end = line
        if !empty(getline(line))
            break
        endif
    endfor

    if l:running_end > l:running_start
        let l:ret = a:callback(l:running_start, l:running_end)
    endif

    return l:ret
endfunction

" indent: fold list whose indent >= a:indent
function! orgmark#tryFoldList(start_line, indent)
    call orgmark#doWithList(a:start_line, a:indent, funcref('orgmark#foldRange'))
endfunction

function! orgmark#tryUnfoldList(start_line, indent)
    call orgmark#doWithList(a:start_line, a:indent, funcref('orgmark#tryUnfold'))
endfunction

function! orgmark#foldOuterList()
    let [l:start, l:indent] = orgmark#findOuterMostParentList()
    if l:start > 0
        call orgmark#tryFoldList(l:start, l:indent)
    endif
endfunction

function! orgmark#unfoldOuterList()
    let l:pos = getpos('.')
    let [l:start, l:indent] = orgmark#findOuterMostParentList()
    call orgmark#tryUnfoldList(l:start, l:indent)
    call setpos('.', l:pos)
endfunction

function! orgmark#foldInnerList()
    let [l:start, l:indent] = orgmark#findInnerParentList()
    if l:start > 0
        call orgmark#tryFoldList(l:start, l:indent)
    endif
endfunction

function! orgmark#unfoldInnerList()
    let l:pos = getpos('.')
    let [l:start, l:indent] = orgmark#findInnerParentList()
    call orgmark#tryUnfoldList(l:start, l:indent)
    call setpos('.', l:pos)
endfunction

" Accept 3 modes
" PARENT: show only the first level header
" INNER: show all headers but no content
" SHOW ALL: show everything
function! orgmark#cycleList()
    if !exists('b:orgmark_cycle_list_status')
        let b:orgmark_cycle_list_status = 'SHOW ALL'
    endif

    if b:orgmark_cycle_list_status == 'SHOW ALL'
        call orgmark#foldOuterList()
        echo "LIST: FOLD PARENT"
        let b:orgmark_cycle_list_status = 'PARENT'
    elseif b:orgmark_cycle_list_status == 'PARENT'
        call orgmark#unfoldOuterList()
        call orgmark#foldInnerList()
        echo "LIST: FOLD INNER"
        let b:orgmark_cycle_list_status = 'INNER'
    else
        call orgmark#unfoldInnerList()
        echo "LIST: SHOW ALL"
        let b:orgmark_cycle_list_status = 'SHOW ALL'
    endif
endfunction

function! orgmark#cycle()
    let l:text = getline('.')
    if l:text =~ s:headerRegex
        call orgmark#cycleHeader()
    elseif l:text =~ s:listRegex
        call orgmark#cycleList()
    endif
endfunction

"==================================================
" Preview markdown

let s:orgmarkScriptPath = resolve(expand('<sfile>:p:h'))
let s:osname = 'Unidentified'

if has('win32') || has('win64')
  let s:osname = 'win32'
elseif has('unix')
  let s:uname = system("uname")
  if has('mac') || has('macunix') || has("gui_macvim") || s:uname == "Darwin\n"
    let s:osname = 'mac'
  else
    let s:osname = 'unix'
  endif
endif

function! orgmark#previewMarkdown()
    let b:curr_file = expand('%:p')
    call system(s:orgmarkScriptPath . '/../bin/preview.py -i ' . b:curr_file . ' -o /tmp/vim-markdown-preview.html')

    if s:osname == 'unix'
        call system('xdg-open /tmp/vim-markdown-preview.html 1>/dev/null 2>/dev/null &')
    elseif s:osname == 'mac'
        call system('open -g /tmp/vim-markdown-preview.html')
    endif
endfunction
