# The notarized release binary. Renovate bumps both values in the llmkube chart's PR.
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  version = "v0.10.18";
  sha256 = "ceeaabdc6caf92216f9a4ef9c1128d3309e809e4e951992975f3656c5753b95a";
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
