#!/usr/bin/env bash
# Evidence provider for the AI PR reviewer: render what this PR *actually*
# changes in the cluster (not just the YAML tag/digest), via flate.
#
# flate diffs the PR tree against the base checkout, so the job must check out
# with fetch-depth: 0. Always exits 0 — a missing flate, a render error, or a
# non-Kubernetes PR degrades to a short note rather than failing the review.
set -uo pipefail

if ! command -v flate >/dev/null 2>&1; then
  echo "flate not on PATH; skipping rendered diff."
  exit 0
fi

found=0
for cluster in home cloud; do
  for resource in hr ks; do
    out="$(flate diff "${resource}" --path "./kubernetes/flux/${cluster}" 2>/dev/null)" || true
    if [ -n "${out}" ]; then
      found=1
      echo "### Rendered ${resource} diff (${cluster})"
      echo '```'
      echo "${out}"
      echo '```'
      echo
    fi
  done
done

if [ "${found}" -eq 0 ]; then
  echo "No rendered Kubernetes manifest changes for this PR."
fi
exit 0
