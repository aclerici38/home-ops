# The notarized release binary. Renovate bumps both values in the llmkube chart's PR.
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  version = "v0.10.17";
  sha256 = "eb8c0adf1716c085ad9fd64cac905deb841e662a609eb12c77c914324464adf0";
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
