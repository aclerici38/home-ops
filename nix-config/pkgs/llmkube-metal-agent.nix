{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  # renovate: datasource=docker depName=ghcr.io/defilantech/charts/llmkube
  version = "0.9.25";

  # Upstream ships prebuilt release tarballs; the binaries are ad-hoc
  # (linker-)signed by the Go toolchain, so macOS executes them as-is.
  sources = {
    aarch64-darwin = {
      arch = "arm64";
      hash = "sha256-PbQQmo4VZZrZe+4Kj+DKHE6MWGNPOVv2nKH0HTCKsbE=";
    };
    x86_64-darwin = {
      arch = "amd64";
      hash = "sha256-bdrebpnFEYoo7BdHF0IZ9WDaxcxqi5F3cnx6hGEK05o=";
    };
  };

  inherit (stdenvNoCC.hostPlatform) system;
  source =
    sources.${system} or (throw "llmkube-metal-agent: unsupported platform ${system} (macOS only)");
in
stdenvNoCC.mkDerivation {
  pname = "llmkube-metal-agent";
  inherit version;

  src = fetchurl {
    url = "https://github.com/defilantech/LLMKube/releases/download/v${version}/LLMKube-metal-agent_${version}_darwin_${source.arch}.tar.gz";
    inherit (source) hash;
  };

  # The tarball is flat: the binary sits at the root alongside LICENSE, docs and
  # the upstream LaunchAgent plists. Only the binary is wanted here — the plists
  # are deliberately not installed, since modules/llmkube.nix declares a
  # LaunchDaemon instead (upstream's runs per-user and dies at logout).
  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 llmkube-metal-agent "$out/bin/llmkube-metal-agent"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/llmkube-metal-agent" --version | grep -q "${version}"
    runHook postInstallCheck
  '';

  meta = {
    description = "LLMKube Metal agent: runs llama.cpp on Apple GPUs for a remote Kubernetes cluster";
    homepage = "https://github.com/defilantech/LLMKube";
    license = lib.licenses.asl20;
    platforms = lib.attrNames sources;
    mainProgram = "llmkube-metal-agent";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
