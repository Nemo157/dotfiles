{
  lib,
  python3Packages,
  fetchPypi,
}:

python3Packages.buildPythonApplication rec {
  pname = "speaches-cli";
  version = "0.1.0";
  pyproject = true;

  src = fetchPypi {
    inherit version;
    pname = "speaches_cli";
    hash = "sha256-7Rr6BpH7+hzJ6ZIfFnWxtiw647jvY2Wc+NZlqZ0vKu8=";
  };

  build-system = with python3Packages; [
    hatchling
  ];

  dependencies = with python3Packages; [
    httpx
    typer
  ];

  meta = with lib; {
    description = "CLI tool for managing speaches STT/TTS models and server";
    homepage = "https://github.com/speaches-ai/speaches";
    license = with licenses; [ mit ];
    mainProgram = "speaches-cli";
  };
}
