{ pkgs, ... }: {
  imports = [
    ./vifm.nix
  ];

  scripts.html2md = {
    runtimeInputs = [ pkgs.python3Packages.markdownify pkgs.wl-clipboard ];
    text = ''
      # Replace the clipboard's plain-text selection with Markdown converted
      # from the HTML selection, e.g. when copying rich snippets from GitHub.
      if html="$(wl-paste --type text/html 2>/dev/null)"; then
        printf '%s' "$html" | markdownify | tee /dev/stderr | wl-copy --type text/plain
      else
        echo "No text/html in the clipboard" >&2
      fi
    '';
  };
}
