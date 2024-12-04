set -x

if [ -e "$CARGO_HOME" ]
then
  echo "Found existing CARGO_HOME in $CARGO_HOME" >&2
  exit
fi

echo "Creating XDG compatible CARGO_HOME in $CARGO_HOME" >&2

_link_cargo_dir_to() {
  to="$1"
  base="$2"
  shift 2
  while [[ $# -gt 0 ]]; do
    mkdir -p "$CARGO_HOME/$(dirname "$1")" "$base/$to/$(dirname "$1-")"
    ln -st "$CARGO_HOME/$(dirname "$1")" "$base/$to/$1"
    shift
  done
}

_link_cargo_dir() {
  _link_cargo_dir_to cargo "$@"
}

xdg_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
xdg_cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"

_link_cargo_dir "$xdg_config_home" config.toml
_link_cargo_dir "$xdg_data_home" credentials.toml
_link_cargo_dir "$xdg_cache_home" git/db/ registry/{index,cache}/ target/ .global-cache
_link_cargo_dir "$XDG_RUNTIME_DIR" git/checkouts/ registry/src/ .package-cache

# smh cargo-audit, get your own dirs, stop borrowing cargo's
_link_cargo_dir_to cargo-audit "$xdg_config_home" audit.toml
_link_cargo_dir_to cargo-audit "$XDG_RUNTIME_DIR" advisory-db.rustsec.lock

# smh cargo-deny too, get your own dirs!
_link_cargo_dir_to cargo-deny "$xdg_cache_home" advisory-dbs/

# `cargo install --list` as used by `x test tidy` needs to be able to write
# to these files, even though it should only be reading them, give it temp
# files it can throw data into and we'll delete it later :ferrisPensive:
_link_cargo_dir "$XDG_RUNTIME_DIR" .crates.toml .crates2.json

chmod -R a-w,a+t "$CARGO_HOME"
