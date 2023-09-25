{ config, pkgs, vimUtils, fetchFromGitHub, ... }:
{
  vim-lengthmatters = vimUtils.buildVimPluginFrom2Nix {
    pname = "vim-lengthmatters";
    version = "2022-05-17";
    src = fetchFromGitHub {
      owner = "whatyouhide";
      repo = "vim-lengthmatters";
      rev = "98afd5af24e13d3aeaa6442ee41bbf6685595961";
      sha256 = "sha256-H/UOFzSVyMovUFR7gS8mUVBzVyBpyVUqUtVP49kz53U=";
    };
  };

  Nemo157-airline-themes = vimUtils.buildVimPluginFrom2Nix {
    pname = "Nemo157-airline-themes";
    version = "2020-03-17";
    src = fetchFromGitHub {
      owner = "Nemo157";
      repo = "vim-airline-themes";
      rev = "33fbff84ae342183a34d06f987deb38898abe038";
      sha256 = "sha256-CWeRUB3k3BibQP6d6KCUxF9LLZUYhABZxyGNd35W7ec=";
    };
  };

  Nemo157-ale-cargo-rubber = vimUtils.buildVimPluginFrom2Nix {
    pname = "ale-cargo-rubber";
    version = "HEAD";
    src = ./plugins/ale-cargo-rubber;
  };

  Nemo157-eink = vimUtils.buildVimPluginFrom2Nix {
    pname = "eink";
    version = "HEAD";
    src = ./plugins/eink;
  };
}
