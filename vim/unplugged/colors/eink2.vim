hi clear
if exists("syntax_on")
    syntax reset
endif

let colors_name = "eink2"

if &background == "light"
  let s:hibg=7
  let s:hifg=10
  let s:lofg=14
else
  let s:hibg=0
  let s:hifg=14
  let s:lofg=10
endif

hi Normal         cterm=none          ctermbg=none    ctermfg=none
hi IncSearch      cterm=reverse                       ctermfg=none
hi Search         cterm=reverse                       ctermfg=none
hi MoreMsg        cterm=bold                          ctermfg=none
hi ModeMsg        cterm=bold                          ctermfg=none
hi Title          cterm=bold                          ctermfg=none
hi Visual         cterm=none                          ctermfg=3
hi VisualNOS      cterm=bold                          ctermfg=none
hi WarningMsg     cterm=standout                      ctermfg=none
hi WildMenu       cterm=standout                      ctermfg=none
hi DiffAdd        cterm=none          ctermbg=none    ctermfg=2
hi DiffChange     cterm=none          ctermbg=none    ctermfg=3
hi DiffDelete     cterm=none          ctermbg=none    ctermfg=1
hi DiffText       cterm=none          ctermbg=none    ctermfg=8
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

hi link SpecialComment Comment

execute 'hi Comment         cterm=none ctermbg=none       ctermfg='.s:lofg
execute 'hi Conceal         cterm=none ctermbg=none       ctermfg='.s:hifg
execute 'hi Func            cterm=none ctermbg='.s:lofg.' ctermfg=12'
execute 'hi SpecialKey      cterm=none ctermbg=none       ctermfg='.s:lofg
execute 'hi Folded          cterm=none ctermbg='.s:hibg.' ctermfg='.s:lofg
execute 'hi FoldColumn      cterm=none ctermbg='.s:hibg.' ctermfg='.s:lofg
execute 'hi LineNr          cterm=none ctermbg='.s:hibg.' ctermfg=10'
execute 'hi StatusLine      cterm=bold ctermbg='.s:hibg.' ctermfg='.s:hifg
execute 'hi StatusLineNC    cterm=none ctermbg='.s:hibg.' ctermfg='.s:hifg
execute 'hi VertSplit       cterm=none ctermbg='.s:hibg.' ctermfg=14'
execute 'hi ColorColumn     cterm=none ctermbg='.s:hibg.' ctermfg=1'
execute 'hi CursorLineNr    cterm=none ctermbg='.s:hibg.' ctermfg=10'
execute 'hi SignColumn      cterm=none ctermbg='.s:hibg.' ctermfg=10'

execute 'hi AleErrorSign    cterm=none ctermbg='.s:hibg.' ctermfg=1'
execute 'hi AleWarningSign  cterm=none ctermbg='.s:hibg.' ctermfg=3'
