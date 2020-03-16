hi clear
if exists("syntax_on")
    syntax reset
endif

let colors_name = "eink2"


let s:bg=0
let s:fg=7
if &background == "light"
  let s:bg=7
  let s:fg=0
endif

hi Normal         cterm=none          ctermbg=none    ctermfg=none
hi SpecialKey     cterm=none          ctermbg=none    ctermfg=8
hi IncSearch      cterm=reverse                       ctermfg=none
hi Search         cterm=reverse                       ctermfg=none
hi MoreMsg        cterm=bold                          ctermfg=none
hi ModeMsg        cterm=bold                          ctermfg=none
hi Title          cterm=bold                          ctermfg=none
hi Visual         cterm=none                          ctermfg=3
hi VisualNOS      cterm=bold                          ctermfg=none
hi WarningMsg     cterm=standout                      ctermfg=none
hi WildMenu       cterm=standout                      ctermfg=none
hi DiffAdd        cterm=bold          ctermbg=none    ctermfg=2
hi DiffChange     cterm=none          ctermbg=none    ctermfg=5
hi DiffDelete     cterm=bold          ctermbg=none    ctermfg=1
hi DiffText       cterm=none          ctermbg=none    ctermfg=13
hi Type           cterm=none          ctermbg=none    ctermfg=none
hi Keyword        cterm=none          ctermbg=none    ctermfg=none
hi Number         cterm=none          ctermbg=none    ctermfg=none
hi Char           cterm=none          ctermbg=none    ctermfg=none
hi Format         cterm=none          ctermbg=none    ctermfg=none
hi Special        cterm=none          ctermbg=none    ctermfg=none
hi Constant       cterm=none          ctermbg=none    ctermfg=none
hi PreProc        cterm=none                          ctermfg=none
hi Directive      cterm=none          ctermbg=none    ctermfg=none
hi Conditional    cterm=none          ctermbg=none    ctermfg=none
hi Comment        cterm=none          ctermbg=none    ctermfg=8
hi Conceal        cterm=none          ctermbg=none    ctermfg=10
hi Func           cterm=none          ctermbg=8       ctermfg=12
hi Identifier     cterm=none          ctermbg=none    ctermfg=none
hi Statement      cterm=none          ctermbg=none    ctermfg=none
hi Ignore         cterm=bold                          ctermfg=none
hi String         cterm=none                          ctermfg=none
hi ErrorMsg       cterm=none          ctermbg=none    ctermfg=1
hi Error          cterm=none          ctermbg=none    ctermfg=1
hi SpellBad       cterm=none          ctermbg=none    ctermfg=1
hi SpellCap       cterm=none          ctermbg=none    ctermfg=3
hi Todo           cterm=none          ctermbg=none    ctermfg=3
hi MatchParen     cterm=none          ctermbg=3       ctermfg=none
hi CursorLine     cterm=none          ctermbg=none    ctermfg=none

execute 'hi Folded         cterm=none ctermbg=' . s:bg . ' ctermfg=8'
execute 'hi FoldColumn     cterm=none ctermbg=' . s:bg . ' ctermfg=8'
execute 'hi LineNr         cterm=none ctermbg=' . s:bg . ' ctermfg=2'
execute 'hi StatusLine     cterm=bold ctermbg=' . s:bg . ' ctermfg=' . s:fg
execute 'hi StatusLineNC   cterm=none ctermbg=' . s:bg . ' ctermfg=' . s:fg
execute 'hi VertSplit      cterm=none ctermbg=' . s:bg . ' ctermfg=14'
execute 'hi ColorColumn    cterm=none ctermbg=' . s:bg . ' ctermfg=1'
execute 'hi CursorLineNr   cterm=none ctermbg=' . s:bg . ' ctermfg=10'
execute 'hi SignColumn     cterm=none ctermbg=' . s:bg . ' ctermfg=10'
execute 'hi AleErrorSign   cterm=none ctermbg=' . s:bg . ' ctermfg=1'
execute 'hi AleWarningSign cterm=none ctermbg=' . s:bg . ' ctermfg=3'
