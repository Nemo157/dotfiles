
{ pkgs-final, pkgs-prev, ... }:

pkgs-prev.atuin.overrideAttrs (atuin-final: atuin-prev: rec {
  version = "424012215b2217947bfb523d44b9b6819a8822fb";
  src = pkgs-final.fetchFromGitHub {
    owner = "atuinsh";
    repo = "atuin";
    rev = version;
    sha256 = "sha256-xGIfr8MGZ3x9kf2fkPzPeCGZpCfEk7zKkpeVRMqDUGo=";
  };
  cargoDeps = atuin-prev.cargoDeps.overrideAttrs {
    name = "atuin-${version}-vendor.tar.gz";
    inherit src;
    outputHash = "sha256-ugp6Fv6n8T2h1XNVBr26bnB2raVeI/2w8TSiK/I496Y=";
  };
})
