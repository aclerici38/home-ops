# The notarized release binary. Renovate bumps both values in the llmkube chart's PR.
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  version = "v0.10.15";
  sha256 = "3ba213d8ba76b43ae6df0a0d2252f302f400a907b7ddaa1bfe8a64cbaf931a26";
in
stdenvNoCC.mkDerivation {
  pname = "llmkube-metal-agent";
  version = lib.removePrefix "v" version;

  src = fetchurl {
    url = "https://github.com/defilantech/LLMKube/releases/download/${version}/LLMKube-metal-agent_${lib.removePrefix "v" version}_darwin_arm64.tar.gz";
    inherit sha256;
  };
  sourceRoot = ".";

  installPhase = ''
    install -Dm755 llmkube-metal-agent $out/bin/llmkube-metal-agent
  '';

  # Stripping would invalidate the code signature
  dontFixup = true;

  meta = {
    description = "LLMKube metal-agent: serves InferenceServices natively on Apple Silicon";
    homepage = "https://github.com/defilantech/LLMKube";
    license = lib.licenses.asl20;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "llmkube-metal-agent";
  };
}
