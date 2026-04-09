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

    patches = [ ./patches/anthropic-target-url.patch ];

    build-system = with python3.pkgs; [
      hatchling
    ];

    pythonRelaxDeps = [ "litellm" ];

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

  systemdServices = {
    headroom-proxy = {
      Unit = {
        Description = "Headroom context compression proxy for Claude Code";
        After = [ "network-online.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${package}/bin/headroom proxy --port 8787 --no-telemetry";
        Restart = "on-failure";
        RestartSec = 5;
        Environment = [
          "HEADROOM_TELEMETRY=off"
          "HEADROOM_HOST=127.0.0.1"
          "HEADROOM_PORT=8787"
          "HEADROOM_MODE=cost_savings"
          "ORT_LOG_LEVEL=3" # suppress onnxruntime provider bridge warnings (no CUDA on AMD GPU)
          # Chain: Claude → headroom (8787) → better-ccflare (8788) → api.anthropic.com.
          # headroom's click CLI reads this via os.environ.get("ANTHROPIC_TARGET_API_URL")
          # in headroom/cli/proxy.py and passes it into ProxyConfig.anthropic_api_url.
          "ANTHROPIC_TARGET_API_URL=http://127.0.0.1:8788"
        ];
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
