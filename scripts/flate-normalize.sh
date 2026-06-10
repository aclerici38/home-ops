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
#
# Payload HelmReleases carry an explicit metadata.namespace in-tree (Flux would
# otherwise inject it via targetNamespace at apply time), so flate's offline
# dependsOn graph resolves cross-namespace HR refs without any stamping here.
#
# Idempotent. Mutates the tree in place — intended for ephemeral CI checkouts.
# Locally, run it against a throwaway copy. Requires `yq` (v4).
#
# Usage: scripts/flate-normalize.sh [repo-root]   (default: .)
set -euo pipefail

root="${1:-.}"
apps="${root}/kubernetes/apps"
[ -d "$apps" ] || { echo "flate-normalize: no such dir: $apps" >&2; exit 1; }

# Drop self-referential OCIRepositories and re-root their Kustomizations.
find "$apps" -path '*/deploy/repository.yaml' -delete
for f in "$apps"/*/deploy/*.yaml; do
  [ -e "$f" ] || continue
  ns="$(basename "$(dirname "$(dirname "$f")")")"
  yq -i '(select(.kind == "Kustomization") | .spec.path) |=
           "./kubernetes/apps/'"$ns"'/" + sub("^\./"; "")' "$f"
done
