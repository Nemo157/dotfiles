hi clear
if exists("syntax_on")
    syntax reset
endif

let colors_name = "eink2"

if !has('gui_running')
  if &background == "light"
     echo "Not supported"
  else
    hi Normal       cterm=none          ctermbg=none    ctermfg=none
    hi SpecialKey   cterm=none          ctermbg=none    ctermfg=8
    hi IncSearch    cterm=reverse                       ctermfg=none
    hi Search       cterm=reverse                       ctermfg=none
    hi MoreMsg      cterm=bold                          ctermfg=none
    hi ModeMsg      cterm=bold                          ctermfg=none
    hi LineNr       cterm=none          ctermbg=0       ctermfg=2
    hi StatusLine   cterm=bold          ctermbg=0       ctermfg=7
    hi StatusLineNC cterm=none          ctermbg=0       ctermfg=7
    hi VertSplit    cterm=none          ctermbg=0       ctermfg=14
    hi Title        cterm=bold                          ctermfg=none
    hi Visual       cterm=none                          ctermfg=3
    hi VisualNOS    cterm=bold                          ctermfg=none
    hi WarningMsg   cterm=standout                      ctermfg=none
    hi WildMenu     cterm=standout                      ctermfg=none
    hi Folded       cterm=none          ctermbg=0       ctermfg=8
    hi FoldColumn   cterm=none          ctermbg=0       ctermfg=8
    hi DiffAdd      cterm=bold          ctermbg=none    ctermfg=2
    hi DiffChange   cterm=none          ctermbg=none    ctermfg=5
    hi DiffDelete   cterm=bold          ctermbg=none    ctermfg=1
    hi DiffText     cterm=none          ctermbg=none    ctermfg=13
    hi Type         cterm=none          ctermbg=none    ctermfg=none
    hi Keyword      cterm=none          ctermbg=none    ctermfg=none
    hi Number       cterm=none          ctermbg=none    ctermfg=none
    hi Char         cterm=none          ctermbg=none    ctermfg=none
    hi Format       cterm=none          ctermbg=none    ctermfg=none
    hi Special      cterm=none          ctermbg=none    ctermfg=none
    hi Constant     cterm=none          ctermbg=none    ctermfg=none
    hi PreProc      cterm=none                          ctermfg=none
    hi Directive    cterm=none          ctermbg=none    ctermfg=none
    hi Conditional  cterm=none          ctermbg=none    ctermfg=none
    hi Comment      cterm=none          ctermbg=none    ctermfg=8
    hi Conceal      cterm=none          ctermbg=none    ctermfg=10
    hi Func         cterm=none          ctermbg=8       ctermfg=12
    hi Identifier   cterm=none          ctermbg=none    ctermfg=none
    hi Statement    cterm=none          ctermbg=none    ctermfg=none
    hi Ignore       cterm=bold                          ctermfg=none
    hi String       cterm=none                          ctermfg=none
    hi ErrorMsg     cterm=none          ctermbg=none    ctermfg=1
    hi Error        cterm=none          ctermbg=none    ctermfg=1
    hi SpellBad     cterm=none          ctermbg=none    ctermfg=1
    hi SpellCap     cterm=none          ctermbg=none    ctermfg=1
    hi Todo         cterm=none          ctermbg=none    ctermfg=1
    hi MatchParen   cterm=none          ctermbg=3       ctermfg=none
    hi ColorColumn  cterm=none          ctermbg=0       ctermfg=1
    hi CursorLine   cterm=none          ctermbg=none    ctermfg=none
    hi CursorLineNr cterm=none          ctermbg=0       ctermfg=10
  endif
else
  echo "Not supported"
endif
