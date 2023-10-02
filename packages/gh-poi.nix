{ lib, pkgs, fetchFromGitHub, buildGoModule, testers }:
let
  gh-poi = buildGoModule rec {
    pname = "gh-poi";
    version = "0.9.6";

    src = fetchFromGitHub {
      owner = "seachicken";
      repo = "gh-poi";
      rev = "v${version}";
      hash = "sha256-EfwpG0qtXGnMvONF9A+FaYRO9xUR1egAKW2gcckanJA=";
    };

    vendorHash = "sha256-D/YZLwwGJWCekq9mpfCECzJyJ/xSlg7fC6leJh+e8i0=";

    ldflags = [
      "-s"
      "-w"
    ];

    # These tests are excluded in CI and fail with useless error messages,
    # I think they need some extra local setup
    # https://github.com/seachicken/gh-poi/blob/1a5077183f831ac055be243a43544f86b788cb2f/.github/workflows/ci.yml#L43-L43
    preCheck = ''
      rm conn/command_test.go
    '';

    passthru.tests = {
      version = testers.testVersion { package = gh-poi; };
    };

    meta = {
      changelog = "https://github.com/${src.owner}/${src.repo}/releases/tag/${src.rev}";
      description = "Github Cli extension to safely clean up your local branches";
      homepage = "https://github.com/${src.owner}/${src.repo}";
      license = lib.licenses.mit;
    };
  };
in gh-poi
