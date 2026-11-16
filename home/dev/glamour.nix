# Glamour (markdown rendering in gh, glow, ...) style using the Base24 ANSI
# palette indices, so it follows the terminal theme like everything else
# (see ./pi/themes/base24-ansi.json for the same mapping).
{ config, ... }:
let
  # Indices from the ANSI column of the Base24 spec, the terminal remaps 16-21.
  ansi = {
    base00 = "0";
    base01 = "18";
    base02 = "19";
    base03 = "8";
    base04 = "20";
    base05 = "7";
    base06 = "21";
    base07 = "15";
    base08 = "1";
    base09 = "16";
    base0A = "3";
    base0B = "2";
    base0C = "6";
    base0D = "4";
    base0E = "5";
    base0F = "17";
  };

  # Code block highlighting goes through chroma's terminal256 formatter, which
  # only takes RGB and maps it to the closest palette index. These RGB values
  # are exact matches for entries in its table, so come out as the intended
  # index. Only 1-7 and 16-21 are usable: chroma maps the RGB of 0 and 8-15
  # to duplicates in the colour cube / greyscale ramp instead.
  chroma = {
    base01 = "#000087";
    base02 = "#0000af";
    base04 = "#0000d7";
    base05 = "#c0c0c0";
    base06 = "#0000ff";
    base08 = "#800000";
    base09 = "#000000";
    base0A = "#808000";
    base0B = "#008000";
    base0C = "#008080";
    base0D = "#000080";
    base0E = "#800080";
    base0F = "#00005f";
  };

  style = {
    document = {
      block_prefix = "\n";
      block_suffix = "\n";
      margin = 2;
    };
    block_quote = {
      color = ansi.base04;
      indent = 1;
      indent_token = "│ ";
    };
    paragraph = { };
    list.level_indent = 2;
    heading = {
      block_suffix = "\n";
      color = ansi.base0D;
      bold = true;
    };
    h1 = {
      prefix = " ";
      suffix = " ";
      color = ansi.base00;
      background_color = ansi.base0D;
      bold = true;
    };
    h2.prefix = "## ";
    h3.prefix = "### ";
    h4.prefix = "#### ";
    h5.prefix = "##### ";
    h6 = {
      prefix = "###### ";
      color = ansi.base04;
      bold = false;
    };
    text = { };
    strikethrough.crossed_out = true;
    emph.italic = true;
    strong.bold = true;
    hr = {
      color = ansi.base03;
      format = "\n--------\n";
    };
    item.block_prefix = "• ";
    enumeration.block_prefix = ". ";
    task = {
      ticked = "[✓] ";
      unticked = "[ ] ";
    };
    link = {
      color = ansi.base04;
      underline = true;
    };
    link_text = {
      color = ansi.base0D;
      bold = true;
    };
    image = {
      color = ansi.base0E;
      underline = true;
    };
    image_text = {
      color = ansi.base04;
      format = "Image: {{.text}} →";
    };
    code = {
      color = ansi.base0E;
      background_color = ansi.base01;
    };
    code_block = {
      color = ansi.base04;
      margin = 2;
      chroma = {
        text = { };
        error.color = chroma.base08;
        comment.color = chroma.base04;
        comment_preproc.color = chroma.base0C;
        keyword.color = chroma.base0E;
        keyword_reserved.color = chroma.base0E;
        keyword_namespace.color = chroma.base0E;
        keyword_type.color = chroma.base0A;
        operator = { };
        punctuation = { };
        name = { };
        name_builtin.color = chroma.base0C;
        name_tag.color = chroma.base08;
        name_attribute.color = chroma.base0A;
        name_class = {
          color = chroma.base0A;
          bold = true;
        };
        name_constant.color = chroma.base09;
        name_decorator.color = chroma.base0C;
        name_exception.color = chroma.base08;
        name_function.color = chroma.base0D;
        name_other = { };
        literal = { };
        literal_number.color = chroma.base09;
        literal_date = { };
        literal_string.color = chroma.base0B;
        literal_string_escape.color = chroma.base0C;
        generic_deleted.color = chroma.base08;
        generic_emph.italic = true;
        generic_inserted.color = chroma.base0B;
        generic_strong.bold = true;
        generic_subheading.color = chroma.base04;
        background = { };
      };
    };
    table = { };
    definition_list = { };
    definition_term = { };
    definition_description.block_prefix = "\n🠶 ";
    html_block = { };
    html_span = { };
  };
in
{
  xdg.configFile."glamour/base24-ansi.json".text = builtins.toJSON style;

  home.sessionVariables.GLAMOUR_STYLE = "${config.xdg.configHome}/glamour/base24-ansi.json";
}
