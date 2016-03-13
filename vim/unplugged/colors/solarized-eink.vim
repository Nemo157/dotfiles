" Based on a combination of Solarized (http://ethanschoonover.com/solarized)
" and eink.vim (https://bitbucket.org/kisom/eink.vim)

hi clear
if exists("syntax_on")
    syntax reset
endif

let colors_name = "eink"

if !has('gui_running')
  if &background == "light"
     echo "Not supported"
  else
    hi Normal       cterm=NONE          ctermbg=NONE    ctermfg=12
    hi SpecialKey   cterm=bold                          ctermfg=NONE
    hi IncSearch    cterm=reverse                       ctermfg=NONE
    hi Search       cterm=reverse                       ctermfg=NONE
    hi MoreMsg      cterm=bold                          ctermfg=NONE
    hi ModeMsg      cterm=bold                          ctermfg=NONE
    hi LineNr       cterm=NONE                          ctermfg=238
    hi StatusLine   cterm=bold,reverse                  ctermfg=NONE
    hi StatusLineNC cterm=reverse                       ctermfg=NONE
    hi VertSplit    cterm=reverse                       ctermfg=NONE
    hi Title        cterm=bold                          ctermfg=NONE
    hi Visual       cterm=reverse                       ctermfg=NONE
    hi VisualNOS    cterm=bold                          ctermfg=NONE
    hi WarningMsg   cterm=standout                      ctermfg=NONE
    hi WildMenu     cterm=standout                      ctermfg=NONE
    hi Folded       cterm=standout                      ctermfg=NONE
    hi FoldColumn   cterm=standout                      ctermfg=NONE
    hi DiffAdd      cterm=bold                          ctermfg=NONE
    hi DiffChange   cterm=bold                          ctermfg=NONE
    hi DiffDelete   cterm=bold                          ctermfg=NONE
    hi DiffText     cterm=reverse                       ctermfg=NONE
    hi Type         cterm=None          ctermbg=NONE    ctermfg=NONE
    hi Keyword      cterm=None          ctermbg=NONE    ctermfg=NONE
    hi Number       cterm=None          ctermbg=NONE    ctermfg=NONE
    hi Char         cterm=None          ctermbg=NONE    ctermfg=NONE
    hi Format       cterm=None          ctermbg=NONE    ctermfg=NONE
    hi Special      cterm=underline     ctermbg=NONE    ctermfg=NONE
    hi Constant     cterm=None          ctermbg=NONE    ctermfg=NONE
    hi PreProc      cterm=None                          ctermfg=NONE
    hi Directive    cterm=NONE          ctermbg=NONE    ctermfg=NONE
    hi Conditional  cterm=NONE          ctermbg=NONE    ctermfg=NONE
    hi Comment      cterm=NONE          ctermbg=NONE    ctermfg=245
    hi Func         cterm=None          ctermbg=8       ctermfg=12
    hi Identifier   cterm=NONE          ctermbg=NONE    ctermfg=NONE
    hi Statement    cterm=NONE          ctermbg=NONE    ctermfg=NONE
    hi Ignore       cterm=bold                          ctermfg=NONE
    hi String       cterm=underline                     ctermfg=NONE
    hi ErrorMsg     cterm=reverse       ctermbg=15      ctermfg=9
    hi Error        cterm=reverse       ctermbg=15      ctermfg=9
    hi Todo         cterm=bold,standout ctermbg=0       ctermfg=11
    hi MatchParen   cterm=bold          ctermbg=12      ctermfg=NONE
    hi ColorColumn                      ctermbg=255
  endif
else
  echo "Not supported"
endif
