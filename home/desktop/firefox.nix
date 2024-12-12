{ config, pkgs, ... }:
let
  csshacks = pkgs.fetchFromGitHub {
    owner = "MrOtherGuy";
    repo = "firefox-csshacks";
    rev = "1ff9383984632fe91b8466730679e019de13c745";
    sha256 = "sha256-KmkiSpxzlsPBWoX51o27l+X1IEh/Uv8RMkihGRxg98o=";
  };
in {
  programs.firefox = {
    enable = true;
    profiles.default = {
      path = "njgb2g6v.default";

      search = {
        default = "DuckDuckGo";
        force = true;
        engines = {
          "Nix Packages" = {
            urls = [{
              template = "https://search.nixos.org/packages";
              params = [
                { name = "type"; value = "packages"; }
                { name = "query"; value = "{searchTerms}"; }
              ];
            }];

            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "@np" ];
          };

          "NixOS Options" = {
            urls = [{
              template = "https://search.nixos.org/options";
              params = [
                { name = "type"; value = "packages"; }
                { name = "query"; value = "{searchTerms}"; }
              ];
            }];

            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "@no" ];
          };

          "NixOS Wiki" = {
            urls = [{
              template = "https://nixos.wiki/index.php";
              params = [
                { name = "search"; value = "{searchTerms}"; }
              ];
            }];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "@nw" ];
          };

          Noogle = {
            urls = [{
              template = "https://noogle.dev/q";
              params = [
                { name = "term"; value = "\"{searchTerms}\""; }
              ];
            }];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "@nf" ];
          };

          ProtonDB = {
            urls = [{
              template = "https://www.protondb.com/search";
              params = [
                { name = "q"; value = "{searchTerms}"; }
              ];
            }];
            iconUpdateURL = "https://www.protondb.com/sites/protondb/images/favicon-32x32.png";
            definedAliases = [ "@pd" ];
          };

          "HomeManager Options" = {
            urls = [{
              template = "https://home-manager-options.extranix.com/";
              params = [
                { name = "query"; value = "{searchTerms}"; }
              ];
            }];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "@ho" ];
          };

          "Amazon.de".metaData.hidden = true;
          Bing.metaData.hidden = true;
          Google.metaData.hidden = true;
          "Wikipedia (en)".metaData.hidden = true;
        };
      };

      settings = {
        "browser.eme.ui.enabled" = false;
        "browser.tabs.tabmanager.enabled" = false;
        "browser.newtabpage.activity-stream.section.highlights.includePocket" = false;
        "browser.newtabpage.activity-stream.showSerch" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "network.trr.mode" = 5;
        "privacy.trackingprotection.emailtracking.enabled" = true;
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        # https://superuser.com/questions/363827/how-can-i-disable-add-application-for-mailto-links-bar-in-firefox
        "network.protocol-handler.external.mailto" = false;
      };

      userChrome = builtins.concatStringsSep "\n" (builtins.map builtins.readFile [
        "${csshacks}/chrome/hide_tabs_toolbar.css"
        # Preferable, but there's too many bugs with menu dropdowns not dropping
        # up when they're at the bottom of the screen
        # "${csshacks}/chrome/navbar_below_content.css"
      ]);

      extensions = with pkgs.nur.repos.rycee.firefox-addons; [
        augmented-steam
        bitwarden
        firefox-translations
        libredirect
        multi-account-containers
        refined-github
        sidebery
        stylus
        tampermonkey
        tridactyl
        ublock-origin
        web-archives
      ];

    };
  };
}
