#!/usr/bin/env bash
# Normalize the on-disk tree so `flate` can render the per-namespace OCI
# artifacts offline — the artifacts aren't pushed to the registry at PR time,
# so flate (which renders what's literally on disk) can't pull them.
#
# Each apps/<ns>/ is packaged into its OWN OCI artifact (artifact root =
# apps/<ns>/) that the namespace's Kustomization sources via an OCIRepository.
# flate models a source as "fetch from registry" or "the whole working tree";
# it has no notion of "one artifact per subfolder", so we bridge the gap:
#
#   1. delete the per-namespace OCIRepository CRs. With the sourceRef CR gone,
#      flate's bootstrap-alias (pkg/discovery/bootstrap.go) resolves the missing
#      source to the local repo root instead of a 403 from the registry.
#   2. rewrite each deploy Kustomization's artifact-relative `path: ./x` to the
#      repo-root-relative `./kubernetes/apps/<ns>/x` that alias expects (the
#      alias roots at the git repo root, not at apps/<ns>/).
#   3. replicate the repo-root .sourceignore. In production it keeps payload
#      dirs out of the `apps` GitRepository artifact, so the cluster-level `apps`
#      Kustomization (path ./kubernetes/apps) only ever applies deploy/ +
#      namespace.yaml. flate aliases that self-referential GitRepository to the
#      raw working tree (no .sourceignore applied), so without this it would
#      double-apply every payload resource — unsubstituted, since the parent
#      apps Kustomization carries no per-namespace substituteFrom. Pin it with an
#      explicit kustomization.yaml listing just the control-plane files.
#
# Payload HelmReleases carry an explicit metadata.namespace in-tree, so flate's
# offline dependsOn graph resolves cross-namespace HR refs without stamping here.
#
# Mutates the tree in place and expects a FRESH tree (re-running on an already-
# normalized tree double-prefixes paths) — intended for ephemeral CI checkouts.
# Locally, run it against a throwaway copy. Requires `yq` (v4).
#
# Usage: scripts/flate-normalize.sh [repo-root]   (default: .)
set -euo pipefail

root="${1:-.}"
apps="${root}/kubernetes/apps"
[ -d "$apps" ] || { echo "flate-normalize: no such dir: $apps" >&2; exit 1; }

# 1 + 2 — drop self-referential OCIRepositories and re-root their Kustomizations.
find "$apps" -path '*/deploy/repository.yaml' -delete
for f in "$apps"/*/deploy/*.yaml; do
  [ -e "$f" ] || continue
  ns="$(basename "$(dirname "$(dirname "$f")")")"
  yq -i '(select(.kind == "Kustomization") | .spec.path) |=
           "./kubernetes/apps/'"$ns"'/" + sub("^\./"; "")' "$f"
done

# 3 — constrain the cluster `apps` Kustomization to the control-plane files only
# (mirrors .sourceignore). Paths are relative to apps/ (the Kustomization root).
{
  echo "apiVersion: kustomize.config.k8s.io/v1beta1"
  echo "kind: Kustomization"
  echo "resources:"
  for f in "$apps"/*/deploy/*.yaml "$apps"/*/namespace.yaml; do
    [ -e "$f" ] || continue
    echo "  - ${f#"$apps"/}"
  done
} > "$apps/kustomization.yaml"
