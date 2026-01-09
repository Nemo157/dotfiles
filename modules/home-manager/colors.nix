# Light+dark mode version of nix-colors module
{ lib, config, ... }:

let
  cfg = config.colorScheme;
  hexColorType = lib.mkOptionType {
    name = "hex-color";
    descriptionClass = "noun";
    description = "RGB color in hex format";
    check = x: lib.isString x && !(lib.hasPrefix "#" x);
  };
  colorScheme = lib.types.submodule {
    options = {
      slug = lib.mkOption {
        type = lib.types.str;
        example = "awesome-scheme";
        description = ''
          Color scheme slug (sanitized name)
        '';
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "Awesome Scheme";
        description = ''
          Color scheme (pretty) name
        '';
      };
      description = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "A very nice theme";
        description = ''
          Color scheme author
        '';
      };
      author = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "Gabriel Fontes (https://m7.rs)";
        description = ''
          Color scheme author
        '';
      };
      variant = lib.mkOption {
        type = lib.types.enum [ "dark" "light" ];
        default =
          if builtins.substring 0 1 cfg.palette.base00 < "5" then
            "dark"
          else
            "light";
        description = ''
          Whether the scheme is dark or light
        '';
      };

      palette = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.coercedTo lib.types.str (lib.removePrefix "#") hexColorType
        );
        default = { };
        example = lib.literalExpression ''
          {
            base00 = "002635";
            base01 = "00384d";
            base02 = "517F8D";
            base03 = "6C8B91";
            base04 = "869696";
            base05 = "a1a19a";
            base06 = "e6e6dc";
            base07 = "fafaf8";
            base08 = "ff5a67";
            base09 = "f08e48";
            base0A = "ffcc1b";
            base0B = "7fc06e";
            base0C = "14747e";
            base0D = "5dd7b9";
            base0E = "9a70a4";
            base0F = "c43060";
          }
        '';
        description = ''
          Atribute set of hex colors.

          These are usually base00-base0F, but you may use any name you want.
          For example, these can have meaningful names (bg, fg), or be base24.

          The colorschemes provided by nix-colors follow the base16 standard.
          Some might leverage base24 and have 24 colors, but these can be safely
          used as if they were base16.

          You may include a leading #, but it will be stripped when accessed from
          config.colorSchemes.dark/light.palettte.
        '';
      };
    };
  };
in
{
  options.colorSchemes = {
    light = lib.mkOption {
      type = colorScheme;
    };
    dark = lib.mkOption {
      type = colorScheme;
    };
  };
}
