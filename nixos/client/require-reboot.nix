{
  # Live-switching across a nixpkgs bump restarts core services under the
  # running desktop and tends to freeze it, so refuse and require
  # `colmena apply-local boot` + reboot instead.
  #
  # To bypass deliberately (after `apply-local boot`):
  #   sudo NIXOS_NO_CHECK=1 \
  #     /nix/var/nix/profiles/system/bin/switch-to-configuration switch
  system.preSwitchChecks.requireRebootOnNixpkgsChange = ''
    case "$2" in
      switch | test) ;;
      *) exit 0 ;;
    esac

    current="$(cat /run/current-system/nixos-version)"
    incoming="$(cat "$1/nixos-version")"

    if [ "$current" != "$incoming" ]; then
      echo "nixpkgs changed: $current -> $incoming"
      echo "refusing to live-$2, use \`colmena apply-local boot\` and reboot"
      echo "to bypass, after \`colmena apply-local boot\`:"
      echo "  sudo NIXOS_NO_CHECK=1 /nix/var/nix/profiles/system/bin/switch-to-configuration $2"
      exit 1
    fi
  '';
}
