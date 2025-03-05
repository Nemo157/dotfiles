{ config, pkgs, ... }:
let
  statedir = "${config.xdg.stateHome}/vim";
  backupdir = "${statedir}/backup";
  swapdir = "${statedir}/swap";
  undodir = "${statedir}/undo";
  plugins = pkgs.vimPlugins // pkgs.callPackage ./plugins.nix { };
in {
  programs.vim = {
    enable = true;
    defaultEditor = true;

    plugins = with plugins; [
      vim-gitgutter
      vim-easymotion
      editorconfig-vim
      ale
      vim-dispatch
      vim-indent-guides
      fzf-vim
      tabular
      supertab
      vim-autoformat
      vim-airline

      vim-colors-solarized

      elm-vim
      idris-vim
      purescript-vim
      rust-vim
      vim-tmux
      typescript-vim
      vim-elixir
      vim-ledger
      vim-markdown
      vim-mustache-handlebars
      vim-nix
      vim-ps1
      vim-toml

      Nemo157-airline-themes
      Nemo157-eink
      Nemo157-ale-cargo-rubber
    ];

    settings = {
      backupdir = [ "${backupdir}//" ];
      directory = [ "${swapdir}//" ];
      undodir = [ "${undodir}//" ];

      undofile = true;

      expandtab = true;
      shiftwidth = 2;
      tabstop = 2;

      ignorecase = true;
      smartcase = true;

      modeline = true;
      number = true;
    };

    extraConfig = ''
      set viminfofile=${statedir}/viminfo
      let g:netrw_home = "${statedir}"

      colorscheme eink2

      set autochdir
      set bs=indent,eol,start
      set cedit=<Esc>
      set colorcolumn=+1
      set cursorline
      set fillchars=vert:¦,diff:⸳
      set incsearch
      set laststatus=2
      set list
      set listchars=tab:»\ ,trail:·,precedes:<,extends:>
      set modelines=10
      set nofixendofline
      set nofoldenable
      set nowrap
      set ruler
      set scrolloff=5
      set showmatch
      set sidescroll=1
      set sidescrolloff=10
      set signcolumn=yes
      set spell
      set suffixes+=.aux,.blg,.bbl,.log
      set textwidth=80
      set timeoutlen=1000
      set ttimeoutlen=10
      set updatetime=100
      set wildmenu

      let g:mapleader = ","

      let g:airline_theme='base16'
      let g:airline_powerline_fonts = 1
      let g:airline_symbols = {}
      " let g:airline_symbols.branch = ''
      " let g:airline_symbols.readonly = ''
      " let g:airline_symbols.linenr = '☰'
      " let g:airline_symbols.maxlinenr = ''
      " let g:airline_symbols.dirty='⚡'

      let airline#extensions#ale#error_symbol = ' '
      let airline#extensions#ale#warning_symbol = ' '
      let airline#extensions#ale#show_line_numbers = 0

      let g:ale_sign_error=''
      let g:ale_sign_warning=''
      let g:ale_sign_info=''
      let g:ale_sign_style_error=''
      let g:ale_sign_style_warning=''

      let g:ale_c_parse_compile_commands=1
      let g:ale_c_clangtidy_checks = ['*', '-hicpp-signed-bitwise']

      let g:ale_rust_cargo_use_clippy = 1
      let g:ale_rust_cargo_check_all_targets = 1

      " Give latex higher priority over tex.
      let g:tex_flavor = "latex"

      let g:formatdef_rustfmt = '"rustfmt"'
      let g:formatters_rust = ['rustfmt']

      " Set SuperTab to try and determine completion type automatically.
      let g:SuperTabDefaultCompletionType = "context"
      let g:SuperTabMappingForward = '<nul>'
      let g:SuperTabMappingBackward = '<s-nul>'

      let g:fugitive_gitlab_domains = []

      let g:gitgutter_sign_priority = 9
      let g:gitgutter_override_sign_column_highlight = 0
      let g:gitgutter_highlight_linenrs = 1
      let g:gitgutter_sign_added = '|'
      let g:gitgutter_sign_modified = '|'
      let g:gitgutter_sign_removed = '|'
      let g:gitgutter_sign_removed_first_line = '|'
      let g:gitgutter_sign_modified_removed = '|'

      let g:indent_guides_guide_size = 1
      let g:indent_guides_enable_on_vim_startup = 0
      let g:indent_guides_start_level = 2

      let g:EasyMotion_keys = 'uhetonaspg.c,r'

      let g:EditorConfig_max_line_indicator = "line"

      au FileType mkd\|markdown\|rst\|tex\|plaintex setlocal textwidth=80
      au FileType java\|glsl\|xml\|ps1\|vhdl\|mason setlocal tabstop=4 shiftwidth=4 noexpandtab
      au FileType c\|cpp setlocal tabstop=4 shiftwidth=4
      au FileType coffee setlocal tabstop=2 shiftwidth=2
      au FileType typescript setlocal expandtab sw=2 ts=2
      au FileType javascript setlocal expandtab sw=2 ts=2
      au FileType rust let b:ale_linter_aliases = ['rust', 'markdown']
      au FileType rust let b:ale_linters = ['cargo-rubber', 'vale']

      au BufRead,BufNewFile *.kramdown setf mkd
      au BufRead,BufNewFile *.xaml setf xml
      au BufRead,BufNewFile Guardfile\|Gemfile\|Podfile setf ruby
      au BufRead,BufNewFile *.ll\|*.llvm setf llvm
      au BufRead,BufNewFile *.sshtml setf html
      au BufRead,BufNewFile *.es6 set filetype=javascript
      au BufRead,BufNewFile *.crs setf rust
      au BufRead,BufNewFile .yamllint setf yaml
      au BufRead,BufNewFile vimrc setf vim
      au BufRead,BufNewFile freshrc setf bash
      au BufRead,BufNewFile freshrc.d/* setf bash

      " Have Vim jump to the last position when reopening a file
      au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

      map <leader>p :diffput 1<CR>
      map <leader>g :diffget 3<CR>
      map <leader>d :diffup<CR>

      map <leader> <Plug>(easymotion-prefix)
      map <Plug>(easymotion-prefix)w <Plug>(easymotion-bd-w)

      map <leader>n :lnext<CR>
      map <leader>p :lprev<CR>

      vnoremap <C-r> "hy:%s/<C-r>h//gc<left><left><left>

      map <leader>a= :Tabularize /=<CR>
      map <leader>a: :Tabularize /:\zs<CR>
      map <leader>a" :Tabularize /"<CR>

      " caps mistypings
      command! W w
      command! Wq wq
      command! Wqa wqa
      command! WQ wq
      command! WQa wqa
      command! WQA wqa
      command! -bang Q q<bang>
      command! -bang Qa q<bang>
      command! -bang QA q<bang>

      " Makes 3 splits go to horizontal layout
      command! Toh winc t | winc K | winc b | winc J | winc t

      " Makes 3 splits go to vertical layout
      command! Tov winc t | winc H | winc b | winc L | winc t
    '';
  };

  home.file = {
    "${statedir}/.keep".text = "";
    "${backupdir}/.keep".text = "";
    "${swapdir}/.keep".text = "";
    "${undodir}/.keep".text = "";
  };
}
