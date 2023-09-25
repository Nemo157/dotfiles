{ config, pkgs, nur, ... }: {
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

      userChrome = ''
          #titlebar, #sidebar-header {
            visibility: collapse !important;
          }
      '';

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
