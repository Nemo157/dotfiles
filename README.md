Nemo157/dotfiles
================

My configuration files.

Now based around `home-manager` with flakes.

Remote deployment:

```
nix run .#deploy-rs -- --dry-activate
nix run .#deploy-rs
```
