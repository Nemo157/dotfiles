{ config, pkgs, nur, ... }:
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
              template = "https://noogle.dev/";
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
              template = "https://mipmip.github.io/home-manager-option-search/";
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

      settings = let
        doh = "https://base.dns.mullvad.net/dns-query";
      in {
        "browser.tabs.tabmanager.enabled" = false;
        "browser.newtabpage.activity-stream.section.highlights.includePocket" = false;
        "browser.newtabpage.activity-stream.showSerch" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "network.trr.custom_uri" = doh;
        "network.trr.mode" = 3;
        "network.trr.uri" = doh;
        "privacy.trackingprotection.emailtracking.enabled" = true;
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
      };

      userChrome = builtins.concatStringsSep "\n" (builtins.map builtins.readFile [
        "${csshacks}/chrome/hide_tabs_toolbar.css"
        # Preferable, but there's too many bugs with menu dropdowns not dropping
        # up when they're at the bottom of the screen
        # "${csshacks}/chrome/navbar_below_content.css"
      ]);

      extensions = with nur.repos.rycee.firefox-addons; [
        augmented-steam
        bitwarden
        firefox-translations
        libredirect
        multi-account-containers
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
