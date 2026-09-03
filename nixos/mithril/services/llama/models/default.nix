{ config, pkgs, lib, ... }: {
  imports = [
    ./gemma-4.nix
    ./qwen-3.8.nix
    ./audio-cpp.nix
    ./stable-diffusion.nix
  ];

  options.services.llama-swap.models = {
    llama = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf (lib.types.oneOf [
        lib.types.str lib.types.path lib.types.bool lib.types.package
        lib.types.int lib.types.float
      ]));
      default = {};
      description = ''
        Llama.cpp text models. Each entry is an attrset of arguments;
        each `key = value` pair becomes a `--key value` flag passed to
        llama-server. Use `true` for value-less flags.
      '';
    };

    stable-diffusion = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf (lib.types.oneOf [
        lib.types.str lib.types.path lib.types.bool lib.types.package
        lib.types.int lib.types.float
      ]));
      default = {};
      description = ''
        Stable-diffusion.cpp image models. Each entry is an attrset of
        arguments; each `key = value` pair becomes a `--key value` flag
        passed to sd-server.
      '';
    };

    audio = lib.mkOption {
      type = lib.types.attrsOf (pkgs.formats.json {}).type;
      default = {};
      description = ''
        audio.cpp models. Each entry is a model config object embedded
        into the audio.cpp server JSON config.
      '';
    };
  };

  config = {
    _module.args.fetchHF = { repo, rev, file, hash ? "" }:
      pkgs.fetchurl {
        url = "https://huggingface.co/${repo}/resolve/${rev}/${file}";
        inherit hash;
      };

    services.llama-swap.settings.models =
      let
        argsToList = args: lib.concatLists (lib.mapAttrsToList (k: v:
          if v == true then [ "--${k}" ]
          else [ "--${k}" (toString v) ]
        ) args);
      in
      lib.foldl (a: b: a // b) {} [
        (lib.mapAttrs (name: args: {
          cmd = lib.escapeShellArgs ([
            (lib.getExe' pkgs.unstable.llama-cpp-rocm "llama-server")
            "--host" "127.0.0.1"
            "--port" "\${PORT}"
            "--offline"
            "--log-verbosity" "4"
            "--cache-ram" "0"
            "--threads-http" "1"
          ] ++ argsToList args);
          capabilities = { "in" = [ "text" ]; out = [ "text" ]; tools = true; };
        }) config.services.llama-swap.models.llama)

        (lib.mapAttrs (name: args: {
          cmd = lib.escapeShellArgs ([
            (lib.getExe' pkgs.unstable.stable-diffusion-cpp-rocm "sd-server")
            "--listen-ip" "127.0.0.1"
            "--listen-port" "\${PORT}"
            "--verbose"
            "--seed" "-1"
          ] ++ argsToList args);
          checkEndpoint = "/v1/models";
          capabilities = { "in" = [ "text" ]; out = [ "image" ]; };
        }) config.services.llama-swap.models.stable-diffusion)

        (lib.mapAttrs (name: model: let
          audio-cpp-rocm = pkgs.audio-cpp.rocm.override {
            rocmGpuTargets = [ "gfx1201" ];
          };
          json = pkgs.formats.json {};
        in {
          cmd = lib.escapeShellArgs [
            (lib.getExe' audio-cpp-rocm "audiocpp_server")
            "--config" (json.generate "audiocpp-server.config" { models = [ model ]; })
            "--host" "127.0.0.1"
            "--port" "\${PORT}"
            "--backend" "rocm"
            "--log"
            "--cors-origins" "*"
          ];
          capabilities = { "in" = [ "text" ]; out = [ "audio" ]; };
        }) config.services.llama-swap.models.audio)
      ];
  };
}
