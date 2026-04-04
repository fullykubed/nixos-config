{
  pkgs,
  versions,
  ...
}:
let
  python3 = pkgs.python312;

  package = python3.pkgs.buildPythonPackage {
    pname = "headroom-ai";
    version = versions.headroom;
    pyproject = true;

    src = pkgs.fetchPypi {
      pname = "headroom_ai";
      version = versions.headroom;
      hash = versions.headroomSrcHash;
    };

    build-system = with python3.pkgs; [
      hatchling
    ];

    dependencies = with python3.pkgs; [
      # Core
      tiktoken
      pydantic
      litellm
      click
      rich
      # Proxy extras
      fastapi
      uvicorn
      httpx
      h2 # HTTP/2 support for httpx
      openai
      mcp
      magika
      zstandard
      websockets
      onnxruntime
      transformers
    ];

    # Skip tests during build (they require network access)
    doCheck = false;

    meta = with pkgs.lib; {
      description = "Context optimization layer for LLM applications";
      homepage = "https://github.com/chopratejas/headroom";
      license = licenses.asl20;
      mainProgram = "headroom";
    };
  };
in
{
  inherit package;
}
