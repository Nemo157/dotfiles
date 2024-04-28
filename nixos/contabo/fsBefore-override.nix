{ pkgs, lib, modulesPath, config, ... }:
let
  # Use older version of fsBefore, as this commit:
  #
  #     commit b07602a604d6d5db3b1ff85d1c3c008ad25245fa
  #     Author: jakobrs <jakobrs100@gmail.com>
  #     Date:   Thu May 21 09:10:47 2020 +0200
  #
  #         nixos/lib, nixos/filesystems: Make fsBefore more stable, and add `depends` option
  #
  # causes issue https://github.com/NixOS/nixpkgs/issues/152615:
  #
  #     Breaking change from 21.05 to 21.11: filesystem topology
  #     requirements
  #
  #     Failed assertions:
  #     - The 'fileSystems' option can't be topologically sorted:
  #       mountpoint dependency path / -> /old-root loops to /
  fsBefore = a: b:
    a.mountPoint == b.device
    || lib.hasPrefix "${a.mountPoint}${lib.optionalString (!(lib.hasSuffix "/" a.mountPoint)) "/"}" b.mountPoint;

  utils = (import (modulesPath + "/../lib/utils.nix") { inherit lib config pkgs; })
    // { inherit fsBefore; };
in
{
  _module.args = {
    utils = lib.mkForce utils;
  };
}
