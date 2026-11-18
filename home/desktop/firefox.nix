{ config, pkgs, ... }:
let
  csshacks = pkgs.fetchFromGitHub {
    owner = "MrOtherGuy";
    repo = "firefox-csshacks";
    rev = "1ff9383984632fe91b8466730679e019de13c745";
    sha256 = "sha256-KmkiSpxzlsPBWoX51o27l+X1IEh/Uv8RMkihGRxg98o=";
  };
in
{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox-esr;

    # TODO: move to new default:
    # configPath = "${config.xdg.configHome}/mozilla/firefox";
    configPath = ".mozilla/firefox";

    profiles.default = {
      path = "njgb2g6v.default";

      search = {
        default = "ddg";
        force = true;
        engines = {
          "Nix Packages" = {
            urls = [
              {
                template = "https://search.nixos.org/packages";
                params = [
                  {
                    name = "type";
                    value = "packages";
                  }
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];

            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "@np" ];
          };

          "NixOS Options" = {
            urls = [
              {
                template = "https://search.nixos.org/options";
                params = [
                  {
                    name = "type";
                    value = "packages";
                  }
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];

            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "@no" ];
          };

          "NixOS Wiki" = {
            urls = [
              {
                template = "https://nixos.wiki/index.php";
                params = [
                  {
                    name = "search";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "@nw" ];
          };

          Noogle = {
            urls = [
              {
                template = "https://noogle.dev/q";
                params = [
                  {
                    name = "term";
                    value = "\"{searchTerms}\"";
                  }
                ];
              }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "@nf" ];
          };

          ProtonDB = {
            urls = [
              {
                template = "https://www.protondb.com/search";
                params = [
                  {
                    name = "q";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            icon = "https://www.protondb.com/sites/protondb/images/favicon-32x32.png";
            definedAliases = [ "@pd" ];
          };

          "HomeManager Options" = {
            urls = [
              {
                template = "https://home-manager-options.extranix.com/";
                params = [
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "@ho" ];
          };

          "Amazon.de".metaData.hidden = true;
          bing.metaData.hidden = true;
          ecosia.metaData.hidden = true;
          google.metaData.hidden = true;
          perplexity.metaData.hidden = true;
          wikipedia.metaData.hidden = true;
        };
      };

      settings = {
        # FUCK YOU MOZILLA
        "browser.ml.chat.enabled" = false;
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

        # middle mouse should scroll not paste
        "middlemouse.paste" = false;
        "general.autoScroll" = true;

        "browser.uiCustomization.state" =
          let
            stylus = "_7a7a4a92-a2a0-41d1-9fd7-1e92480d612d_-browser-action";
            tampermonkey = "firefox_tampermonkey_net-browser-action";
            libredirect = "7esoorv3_alefvanoon_anonaddy_me-browser-action";
            bitwarden = "_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action";
            ublock = "ublock0_raymondhill_net-browser-action";

            tridactyl = "tridactyl_vim_cmcaine_co_uk-browser-action";
            multi-account-containers = "_testpilot-containers-browser-action";
            refined-github = "_a4c4eda4-fb84-4a84-b4a1-f7c1cbf2a1ad_-browser-action";
            sideberry = "_3c078156-979c-498b-8990-85f7987dd929_-browser-action";
            universal-trakt-scrobbler = "_0dab3ff3-6b8f-4553-82da-1fa00c0e9f94_-browser-action";
            web-archives = "_d07ccf11-c0cd-4938-a265-2a4d6ad01189_-browser-action";

            nav-bar-extensions = [
              stylus
              tampermonkey
              libredirect
              bitwarden
              ublock
            ];

            unified-extensions = [
              sideberry
              web-archives
              multi-account-containers
              universal-trakt-scrobbler
              refined-github
              tridactyl
            ];
          in
          builtins.toJSON {
            placements = {
              nav-bar = nav-bar-extensions ++ [
                "unified-extensions-button"

                "back-button"
                "forward-button"
                "vertical-spacer"
                "stop-reload-button"
                "reset-pbm-toolbar-button"

                "urlbar-container"

                "downloads-button"
                "fxa-toolbar-menu-button"
              ];

              TabsToolbar = [
                "firefox-view-button"
                "tabbrowser-tabs"
                "new-tab-button"
                "alltabs-button"
              ];

              widget-overflow-fixed-list = [ ];

              unified-extensions-area = unified-extensions;

              toolbar-menubar = [ "menubar-items" ];
              vertical-tabs = [ ];
              PersonalToolbar = [
                "import-button"
                "personal-bookmarks"
              ];
            };

            seen =
              nav-bar-extensions
              ++ unified-extensions
              ++ [
                "save-to-pocket-button"
                "developer-button"
                "screenshot-button"
                "reset-pbm-toolbar-button"
              ];

            dirtyAreaCache = [
              "nav-bar"
              "PersonalToolbar"
              "toolbar-menubar"
              "TabsToolbar"
              "unified-extensions-area"
              "vertical-tabs"
            ];

            currentVersion = 24;
            newElementCount = 21;
          };
      };

      userChrome = builtins.concatStringsSep "\n" (
        builtins.map builtins.readFile [
          "${csshacks}/chrome/hide_tabs_toolbar.css"
          # Preferable, but there's too many bugs with menu dropdowns not dropping
          # up when they're at the bottom of the screen
          # "${csshacks}/chrome/navbar_below_content.css"
        ]
      );

      extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
        augmented-steam
        bitwarden
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
