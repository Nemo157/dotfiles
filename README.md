Nemo157/dotfiles
================

My configuration files.

Now based around `home-manager` with flakes.

Remote deployment:

```
nix run pkgs#colmena -- build
nix run pkgs#colmena -- apply test
nix run pkgs#colmena -- apply
```
