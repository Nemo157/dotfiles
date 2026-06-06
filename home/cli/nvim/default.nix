{ config, pkgs, ... }: let
  plugins = pkgs.vimPlugins // pkgs.callPackage ../vim/plugins.nix { };
in {
  home.packages = [
    pkgs.terraform-ls
    pkgs.typescript-language-server
  ];

  programs.neovim = {
    enable = true;

    withRuby = false;
    withPython3 = false;

    plugins = [
      plugins.vim-gitgutter
      plugins.vim-easymotion
      plugins.editorconfig-vim
      plugins.vim-dispatch
      plugins.vim-indent-guides
      plugins.fzf-vim
      plugins.tabular
      plugins.supertab
      plugins.vim-autoformat
      plugins.vim-airline

      plugins.vim-colors-solarized

      plugins.elm-vim
      plugins.idris-vim
      plugins.purescript-vim
      plugins.vim-tmux
      plugins.typescript-vim
      plugins.vim-elixir
      plugins.vim-ledger
      plugins.vim-markdown
      plugins.vim-mustache-handlebars
      plugins.vim-nix
      plugins.vim-ps1
      plugins.vim-toml

      plugins.nvim-lspconfig
      plugins.rustaceanvim

      plugins.Nemo157-airline-themes
      plugins.Nemo157-eink
    ];

    extraConfig = ''
      colorscheme base24-eink2

      set undofile
      set number
      set ignorecase
      set smartcase
      set modeline
      set notermguicolors

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

      " Give latex higher priority over tex.
      let g:tex_flavor = "latex"

      let g:formatdef_rustfmt = '"rustfmt"'
      let g:formatters_rust = ['rustfmt']

      " Set SuperTab to try and determine completion type automatically.
      let g:SuperTabDefaultCompletionType = "context"
      let g:SuperTabMappingForward = '<nul>'
      let g:SuperTabMappingBackward = '<s-nul>'

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
      au FileType rust setlocal nospell " disable spellcheck since we have vale instead

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

    initLua = ''
      vim.lsp.enable({
        "terraformls",
        "ts_ls",
      })
    '';
  };
}
