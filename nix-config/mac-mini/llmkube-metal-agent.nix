# Hashes are refreshed on Renovate PRs by .github/workflows/llmkube-metal-agent.yaml
{
  lib,
  buildGoModule,
  fetchFromGitHub,
  go_1_27,
}:
(buildGoModule.override { go = go_1_27; }) rec {
  pname = "llmkube-metal-agent";
  # The chart, so Renovate bumps both in one PR
  # renovate: datasource=docker depName=ghcr.io/defilantech/charts/llmkube
  version = "0.10.11";

  src = fetchFromGitHub {
    owner = "defilantech";
    repo = "LLMKube";
    tag = "v${version}";
    hash = "sha256-Mezd3A3GCOPveb/Vgeo5c0TeSMgaN7bZHZUqf3a1Ob0=";
  };

  vendorHash = "sha256-M5MyqonicGLQIoiHFRAwCwCtw6uaRqsbmeTzlWlLH/I=";

  subPackages = [ "cmd/metal-agent" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
  ];

  postInstall = ''
    mv $out/bin/metal-agent $out/bin/llmkube-metal-agent
  '';

  meta = {
    description = "LLMKube metal-agent: serves InferenceServices natively on Apple Silicon";
    homepage = "https://github.com/defilantech/LLMKube";
    license = lib.licenses.asl20;
    platforms = lib.platforms.darwin;
    mainProgram = "llmkube-metal-agent";
  };
}
