{
  lib,
  python3Packages,
  fetchPypi,
}:

python3Packages.buildPythonApplication rec {
  pname = "keymap-drawer";
  version = "0.22.0";
  pyproject = true;

  src = fetchPypi {
    inherit version;
    pname = "keymap_drawer";
    hash = "sha256-obsWbu5MEZVx1Za+2WkKCABYwmYAyAFnC2d4GZN0rVo=";
  };

  build-system = with python3Packages; [
    poetry-core
  ];

  dependencies = with python3Packages; [
    pydantic
    pcpp
    pyyaml
    platformdirs
    pydantic-settings
    tree-sitter
    tree-sitter-grammars.tree-sitter-devicetree
    pyparsing
  ];

  meta = with lib; {
    description = "A CLI tool to help parse and draw keyboard layouts.";
    homepage = src.meta.homepage;
    license = with licenses; [ mit ];
    maintainers = [ maintainers.nemo157 ];
    mainProgram = "keymap";
  };
}

