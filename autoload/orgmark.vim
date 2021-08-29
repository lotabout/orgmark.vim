" Group 1: header
" Group 2: fenced start with language
" Group 3: fenced end
" Group 4: list item

function! s:Wrapper(group)
    function! s:Handler(lnum, col) closure
        echo [a:group, a:lnum, a:col]
    endfunction
    return funcref('s:Handler')
endfunction


let s:levelRegexpDict = {
    \ 1: '\v^(#[^#]@=|.+\n\=+$)',
    \ 2: '\v^(##[^#]@=|.+\n-+$)',
    \ 3: '\v^###[^#]@=',
    \ 4: '\v^####[^#]@=',
    \ 5: '\v^#####[^#]@=',
    \ 6: '\v^######[^#]@='
\ }

" calculate the level of current header, assume line (l:num) is a header
function! orgmark#HeaderLevelOf(lnum, col)
    let l:text = getline(a:lnum)
    for l:key in keys(s:levelRegexpDict)
        if l:text =~ get(s:levelRegexpDict, l:key)
            return l:key
        endif
    endfor
    return 0
endfunction

function! orgmark#getHeaderTag(lnum, col)
    let l:level = orgmark#HeaderLevelOf(a:lnum, a:col)
    return {'type': 'Header', 'level': l:level, 'ln': a:lnum, 'col': a:col}
endfunction

function! orgmark#getFenceTag(lnum, col, in_fence)
    let l:text = getline(a:lnum)
    if l:text =~ '^\s*```[^`]\+$' " fenced start with language
        let l:lang = substitute(l:text, '^\s*```', '', '')
        return {'type': 'FenceStart', 'ln': a:lnum, 'col': a:col}
    elseif !a:in_fence
        return {'type': 'FenceStart', 'ln': a:lnum, 'col': a:col}
    else
        return {'type': 'FenceEnd', 'ln': a:lnum, 'col': a:col}
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
            call add(l:marks, orgmark#getHeaderTag(l:lnum, l:col))
        elseif l:group == 3 " fenced code (with language) start
            call add(l:marks, orgmark#getFenceTag(l:lnum, l:col, l:in_fence))
            let l:in_fence = v:true
        elseif l:group == 4 " toggle fenced code
            call add(l:marks, orgmark#getFenceTag(l:lnum, l:col, l:in_fence))
            let l:in_fence = !l:in_fence
        endif
        let [l:lnum, l:col, l:group] = searchpos(s:headerRegexes, 'Wp')
    endwhile
    call setpos('.', l:pos)
    return l:marks
endfunction

function! orgmark#ensureMarks()
    if !exists('b:orgmark_marks')
        call orgmark#rebuildMarks()
    endif
    return b:orgmark_marks
endfunction

function! orgmark#rebuildMarks()
    let b:orgmark_marks = orgmark#buildMarks()
endfunction


function! orgmark#foldRange(start_line, next_start_line)
    if a:start_line <= 0
        return
    endif

    let l:end_line = a:next_start_line >= line('$') ? line('$') : a:next_start_line - 1
    execute a:start_line ',' l:end_line 'fold'
endfunction

"==================================================
" Orgmark Cycle

" Accept 3 modes
" OVERVIEW: show only the first level header
" CONTENTS: show all headers but no content
" SHOW ALL: show everything
function! orgmark#cycle()
    if !exists('b:orgmark_cycle_status')
        let b:orgmark_cycle_status = 'SHOW ALL'
    endif

    if b:orgmark_cycle_status == 'SHOW ALL'
        call orgmark#cycleOverview()
        let b:orgmark_cycle_status = 'OVERVIEW'
    elseif b:orgmark_cycle_status == 'OVERVIEW'
        call orgmark#cycleContent()
        let b:orgmark_cycle_status = 'CONTENTS'
    else
        call orgmark#cycleShowAll()
        let b:orgmark_cycle_status = 'SHOW ALL'
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
            call orgmark#foldRange(l:last_tag.ln, tag.ln)
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
            call orgmark#foldRange(l:last_tag.ln, tag.ln)
        endif

        let l:last_tag = tag
        let l:lowest_level_til_now = min([tag.level, l:lowest_level_til_now])
    endfor

    if !empty(l:last_tag)
        call orgmark#foldRange(l:last_tag.ln, line('.'))
    endif

    execute l:saved_lnum
endfunction

"==================================================
" Orgmark ToggleFold

" try to unfold if current line is the start of a fold
" And return true if action is taken
function! orgmark#tryUnfold()
    let l:ln = line('.')
    let l:fold_start = foldclosed(l:ln)
    if l:fold_start > 0
        silent normal! zo
        call cursor(l:fold_start, 0)
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
    let l:endLnum = empty(l:tagsWithLeLevel) ? line('$') : l:tagsWithLeLevel[0].ln
    call orgmark#foldRange(l:ln, l:endLnum)
endfunction

function! orgmark#tryFoldFenced()
    let l:marks = orgmark#ensureMarks()
    let l:ln = line('.')

    let l:tags =  filter(copy(l:marks), {idx, tag -> tag.ln == l:ln})
    if empty(l:tags) || l:tags[0].type != 'FenceStart'
        return
    endif
    let l:currentTag = l:tags[0]

    " find next FenceEnd
    let l:endLnum = line('$')
    for tag in l:marks
        if tag.ln <= l:ln
            continue
        endif
        if tag.type == 'FenceEnd'
            let l:endLnum = tag.ln + 1
            break
        endif
    endfor
    call orgmark#foldRange(l:currentTag.ln, l:endLnum)
endfunction

function! orgmark#tryFoldList()
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

    call orgmark#foldRange(l:ln, l:endLnum)
endfunction

let s:headerRegex = '\v^#+[^#]*$'
let s:fencedRegex = '\v(^\s*```[^`]+$)|(^\s*```$)'
let s:listRegex = '\v\s*([-+*]|\d+.|[a-z]\))\s'

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
        call orgmark#tryFoldList()
    endif
endfunction

function! orgmark#FoldText()
  let line = getline(v:foldstart)
  return line
endfunction
