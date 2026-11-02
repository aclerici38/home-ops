# The notarized release binary. Renovate bumps both values in the llmkube chart's PR.
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  version = "v0.10.16";
  sha256 = "7d10dee47d90b3686e152150f3240e9b28c5384f38a75f4000226c86f162a913";
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
