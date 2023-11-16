{ pkgs, ... }:
let
  getExe = pkgs.lib.getExe;
in {
  home.packages = [ pkgs.vifm ];

  xdg.configFile = {
    "vifm/vifmrc".text = with pkgs; ''
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

      fileviewer *.pdf ${poppler_utils}/bin/pdftotext -nopgbrk %c -

      fileviewer *.mp3 ${getExe mp3info}
      fileviewer *.flac ${sox}/bin/soxi

      fileviewer *.avi,*.mp4,*.wmv,*.dat,*.3gp,*.ogv,*.mkv,*.mpg,*.mpeg,*.vob,
                \*.fl[icv],*.m2v,*.mov,*.webm,*.ts,*.mts,*.m4v,*.r[am],*.qt,*.divx,
                \*.as[fx]
               \ ${ffmpeg}/bin/ffprobe -pretty %c 2>&1

      filetype *.html,*.htm ${getExe links2}, ${getExe lynx}

      filetype *.o ${binutils}/bin/nm %f | less

      filetype *.[1-8] man ./%c
      fileviewer *.[1-8] man ./%c | col -b

      fileviewer *.bmp,*.jpg,*.jpeg,*.png,*.gif,*.xpm
               \ ${imagemagick}/bin/identify %f

      " MD5
      filetype *.md5
             \ {Check MD5 hash sum}
             \ ${coreutils}/bin/md5sum -c %f %S,

      " SHA1
      filetype *.sha1
             \ {Check SHA1 hash sum}
             \ ${coreutils}/bin/sha1sum -c %f %S,

      " SHA256
      filetype *.sha256
             \ {Check SHA256 hash sum}
             \ ${coreutils}/bin/sha256sum -c %f %S,

      " SHA512
      filetype *.sha512
             \ {Check SHA512 hash sum}
             \ ${coreutils}/bin/sha512sum -c %f %S,

      " GPG signature
      filetype *.asc
             \ {Check signature}
             \ !!${getExe gnupg} --verify %c,

      " FuseZipMount
      filetype *.zip,*.jar,*.war,*.ear,*.oxt,*.apkg
             \ {Mount with archivemount}
             \ FUSE_MOUNT|${getExe archivemount} %SOURCE_FILE %DESTINATION_DIR,
             \ {View contents}
             \ ${getExe unzip} -l %c | less,
             \ {Extract here}
             \ ${getExe unzip} %c,
      fileviewer *.zip,*.jar,*.war,*.ear,*.oxt ${getExe zip} -sf %c

      " ArchiveMount
      filetype *.tar,*.tar.bz2,*.tbz2,*.tgz,*.tar.gz,*.tar.xz,*.txz
             \ {Mount with archivemount}
             \ FUSE_MOUNT|${getExe archivemount} %SOURCE_FILE %DESTINATION_DIR,
      fileviewer *.tgz,*.tar.gz ${getExe gnutar} -tzf %c
      fileviewer *.tar.bz2,*.tbz2 ${getExe gnutar} -tjf %c
      fileviewer *.tar.txz,*.txz ${getExe xz} --list %c
      fileviewer *.tar ${getExe gnutar} -tf %c

      " Fuse7z and 7z archives
      filetype *.7z
             \ {Mount with fuse-7z-ng}
             \ FUSE_MOUNT|${getExe fuse-7z-ng} %SOURCE_FILE %DESTINATION_DIR,
      fileviewer *.7z ${getExe p7zip} l %c

      " Rar2FsMount and rar archives
      filetype *.rar
             \ {Mount with fuse-7z-ng}
             \ FUSE_MOUNT|${getExe fuse-7z-ng} %SOURCE_FILE %DESTINATION_DIR,
      fileviewer *.rar ${getExe unrar} v %c

      " IsoMount
      filetype *.iso
             \ {Mount with fuseiso}
             \ FUSE_MOUNT|${getExe fuseiso} %SOURCE_FILE %DESTINATION_DIR,

      " SshMount
      filetype *.ssh
             \ {Mount with sshfs}
             \ FUSE_MOUNT2|${getExe sshfs} %PARAM %DESTINATION_DIR %FOREGROUND,

      " FtpMount
      filetype *.ftp
             \ {Mount with curlftpfs}
             \ FUSE_MOUNT2|${getExe curlftpfs} -o ftp_port=-,,disable_eprt %PARAM %DESTINATION_DIR %FOREGROUND,

      fileviewer *.patch ${getExe delta} --paging=never <%f
      fileviewer *.diff ${getExe delta} --paging=never <%f
      fileviewer *[^/] ${getExe bat} --color=always -pp %f

      fileviewer */ ${getExe lsd} --tree --long --color=always %f
      filetype */ ${getExe du-dust} -n %ph %f | less -R

      set viewcolumns=-{name}..,9{ext},7{}.
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
