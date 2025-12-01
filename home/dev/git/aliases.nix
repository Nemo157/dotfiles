{ config, pkgs, ... }: {
  programs.git.settings.alias = {
    di = "diff --color-words";
    f = "fetch --all";
    fb = "!git f && git br -av";
    br = "branch";
    st = "status --short";
    dw = "diff --word-diff";
    ds = "diff --cached";
    d = "diff";
    pnp = "!git pull && git push";
    lc = "log ORIG_HEAD.. --stat";
    lcn = "log ORIG_HEAD.. --stat --no-merges";
    # Returns the names of any files that have changed both in the current branch and the named branch
    intersect = "!bash -c 'comm -12 <(git log ..$1 --format='format:' --name-only | sed '/^$/d' | sort) <(git log $1.. --format='format:' --name-only | sed '/^$/d' | sort)' -";
    frp = "!bash -c 'git fetch && [[ \"$(git intersect origin/master)\" == \"\" ]] && git rebase origin/master && git push || echo \"Intersecting files:\n\" && git intersect origin/master' -";
    ri = "rebase --interactive --autosquash";
    rc = "rebase --continue";
    lol = "log --graph --decorate --pretty=oneline --abbrev-commit --all";
    lol2 = "log --graph --pretty=tformat:'%C(bold yellow)%D%Creset %>|(16)%Cred%h%Creset %s %>|(140)%Cgreen%ar %>|(156)%C(bold blue)%an%Creset %C(cyan)%G?' --abbrev-commit --date=relative --all";
    lo = "log --graph --decorate --pretty=oneline --abbrev-commit --all --max-count=10";
    brs = "log --graph --decorate --pretty=oneline --abbrev-commit --all --simplify-by-decoration";
    co = "checkout";
    ci = "commit";
    abs = "absorb -b origin/HEAD";
    flo = "!git forest --all --reverse --pretty=format:\"%C(yellow)%h %C(blue)(%ar) %C(reset)%s\" --color --style=2";
    s = "show --show-signature";
    pushf = "push --force-with-lease --force-if-includes";
    jj = ''!bash -c 'git --git-dir="$(jj root)/.jj/repo/store/git/" "$@"' -'';
  };
}
