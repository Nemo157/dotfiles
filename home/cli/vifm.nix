{ pkgs, ... }:
let
  getExe = pkgs.lib.getExe;
  vifm-image-viewer = pkgs.writeShellApplication {
    name = "vifm-image-viewer";
    runtimeInputs = with pkgs; [ imagemagick kitty ];
    text = ''
      if [ "$1" == "clear" ]
      then
        kitten icat --clear --silent
      else
        file="$2"
        cols="$3"
        rows="$4"
        col="$5"
        row="$6"

        # ffprobe -hide_banner -pretty "$file" 2>&1

        # IFS=';' read -rs -d t -p $'\e[16t' _ h w
        # (( height = h * rows ))
        # (( width = w * cols ))

        # TODO detect terminal
        # needs https://github.com/xaizek/vifm/commit/ff096996a91566f2c2c3354fc9e378fbf3ca9948
        # probably

        # --use-window-size "$cols,$rows,$height,$width"
        # --stdin=no

        (( half = rows / 2 ))

        tmp="$(mktemp --tmpdir vifm-image-viewer-XXXXXX.png)"

        ffmpeg -hide_banner -i "$file" -frames:v 1 -update 1 -y "$tmp" 2>/dev/null

        kitten icat \
          --place "''${cols}x$half@''${col}x$row" \
          --transfer-mode=memory \
          "$tmp" \
          </dev/tty >/dev/tty

        rm "$tmp"

        for (( i = 0 ; i < half + 1 ; i++ ))
        do
          echo
        done

        ffprobe -hide_banner -pretty "$file" 2>&1

        # exec magick "$file" -scale "''${width}x$height>" six:-
      fi
    '';
  };
in {
  home.packages = with pkgs; [
    vifm

    archivemount
    bat
    binutils
    coreutils
    curlftpfs
    delta
    dust
    fd
    ffmpeg
    fuse-7z-ng
    fuseiso
    gnupg
    gnutar
    imagemagick
    jq
    cfr
    links2
    lsd
    lynx
    p7zip
    poppler-utils
    ripgrep
    sox
    sshfs
    unrar
    unzip
    xz
    zip
    vifm-image-viewer
  ];

  xdg.configFile = {
    "vifm/vifmrc".text = ''
      set vicmd=vim
      set syscalls
      set trash
      set history=100
      set nofollowlinks
      set sortnumbers
      set undolevels=100
      set vimhelp
      set norunexec
      set timefmt=%Y-%m-%d\ %H:%M
      set wildmenu
      set wildstyle=popup
      set suggestoptions=normal,visual,view,otherpane,keys,marks,registers
      set ignorecase
      set smartcase
      set nohlsearch
      set incsearch
      set scrolloff=4
      set slowfs=curlftpfs
      set statusline="%= %A %10u:%-7g %15s %20d  "
      set quickview
      set grepprg="rg --line-number %i %a %s"
      set findprg="fd %A %s"

      colorscheme eink

      fileviewer *.pdf pdftotext -nopgbrk %c -

      fileviewer *.flac soxi

      fileviewer *.bmp,*.jpg,*.jpeg,*.png,*.gif,*.xpm,*.svg,*.image,*.webp,
                \*.avi,*.mp[4g],*.wmv,*.ogv,*.mkv,*.mpeg,
                \*.mov,*.webm,*.ts,*.mts,*.m4v,*.divx
               \ vifm-image-viewer show %c %pw %ph %px %py %pu %N
               \ %pc
               \ vifm-image-viewer clear %N

      fileviewer *.avi,*.mp[34g],*.wmv,*.dat,*.3gp,*.ogv,*.mkv,*.mpeg,*.vob,*.flac
                \*.fl[icv],*.m2v,*.mov,*.webm,*.ts,*.mts,*.m4[av],*.r[am],*.qt,*.divx,
                \*.as[fx],*.bmp,*.jpg,*.jpeg,*.png,*.gif,*.xpm
               \ ffprobe -hide_banner -pretty %c 2>&1

      filetype *.html,*.htm links2, lynx

      filetype *.o nm %f | less

      filetype *.[1-8] man ./%c
      fileviewer *.[1-8] man ./%c | col -b

      fileviewer *.class cfr %c

      " MD5
      filetype *.md5
             \ {Check MD5 hash sum}
             \ md5sum -c %f %S,

      " SHA1
      filetype *.sha1
             \ {Check SHA1 hash sum}
             \ sha1sum -c %f %S,

      " SHA256
      filetype *.sha256
             \ {Check SHA256 hash sum}
             \ sha256sum -c %f %S,

      " SHA512
      filetype *.sha512
             \ {Check SHA512 hash sum}
             \ sha512sum -c %f %S,

      " GPG signature
      filetype *.asc
             \ {Check signature}
             \ !!gnupg --verify %c,

      " FuseZipMount
      filetype *.zip,*.jar,*.war,*.ear,*.oxt,*.apkg,*.hlc
             \ {Mount with archivemount}
             \ FUSE_MOUNT|archivemount %SOURCE_FILE %DESTINATION_DIR,
             \ {Extract here}
             \ unzip %c,
      fileviewer *.zip,*.jar,*.war,*.ear,*.oxt,*.apkg,*.hlc zip -sf %c

      " ArchiveMount
      filetype *.tar,*.tar.bz2,*.tbz2,*.tgz,*.tar.gz,*.tar.xz,*.txz,*.crate
             \ {Mount with archivemount}
             \ FUSE_MOUNT|archivemount %SOURCE_FILE %DESTINATION_DIR,
      fileviewer *.tgz,*.tar.gz tar -tzf %c
      fileviewer *.tar.bz2,*.tbz2 tar -tjf %c
      fileviewer *.tar.txz,*.txz xz --list %c
      fileviewer *.tar tar -tf %c

      " Fuse7z and 7z archives
      filetype *.7z
             \ {Mount with fuse-7z-ng}
             \ FUSE_MOUNT|fuse-7z-ng %SOURCE_FILE %DESTINATION_DIR,
             \ {Extract here}
             \ 7z x %c,
      fileviewer *.7z 7z l %c

      " Rar2FsMount and rar archives
      filetype *.rar
             \ {Mount with archivemount}
             \ FUSE_MOUNT|archivemount %SOURCE_FILE %DESTINATION_DIR,
             \ {Extract here}
             \ unrar x %c,
      fileviewer *.rar unrar v %c

      " IsoMount
      filetype *.iso
             \ {Mount with fuseiso}
             \ FUSE_MOUNT|fuseiso %SOURCE_FILE %DESTINATION_DIR,

      " SshMount
      filetype *.ssh
             \ {Mount with sshfs}
             \ FUSE_MOUNT2|sshfs %PARAM %DESTINATION_DIR %FOREGROUND,

      " FtpMount
      filetype *.ftp
             \ {Mount with curlftpfs}
             \ FUSE_MOUNT2|curlftpfs -o ftp_port=-,,disable_eprt %PARAM %DESTINATION_DIR %FOREGROUND,

      fileviewer *.patch delta --paging=never <%f
      fileviewer *.diff delta --paging=never <%f
      fileviewer *.json jq --color-output . %c
      fileviewer *[^/] bat --color=always -pp %f

      fileviewer */ lsd --tree --long --color=always %f
      filetype */ dust -n %ph %f | less -R

      set viewcolumns=-{name}..,9{ext},7{}.

      " allow c-p/c-n in normal mode to cycle the view pane through different file viewers
      nnoremap <silent> <c-p> <c-w><c-w>A<c-w><c-w>
      nnoremap <silent> <c-n> <c-w><c-w>a<c-w><c-w>
    '';

    "vifm/colors/eink.vifm".text = ''
      hi Border       cterm=none      ctermbg=0      ctermfg=10
      hi TopLine      cterm=none      ctermbg=0      ctermfg=10
      hi TopLineSel   cterm=none      ctermbg=none   ctermfg=5
      hi CmdLine      cterm=none      ctermbg=0      ctermfg=10
      hi StatusLine   cterm=none      ctermbg=0      ctermfg=7
      hi CurrLine     cterm=reverse   ctermbg=none   ctermfg=none
      hi Win          cterm=none      ctermbg=none   ctermfg=none
    '';
  };
}
