# Sourced by tasks, not a task itself: no exec bit, so mise ignores it.
# Resolves a home|cloud cluster name to its kube context and selects it.
# Sets: CLUSTER, CLUSTER_NAME, KUBE_CONTEXT, ROOT_DIR
select_cluster() {
  export CLUSTER="$1"
  case "$CLUSTER" in
    home)  export CLUSTER_NAME=dormammu ;;
    cloud) export CLUSTER_NAME=cloud ;;
    *)     echo "ERROR: unknown cluster '$CLUSTER' (expected home|cloud)" >&2; return 1 ;;
  esac
  export KUBE_CONTEXT="admin@${CLUSTER_NAME}"
  require_context "$KUBE_CONTEXT"
  export ROOT_DIR="${MISE_PROJECT_ROOT:-$(git rev-parse --show-toplevel)}"
}

require_context() {
  kubectl config get-contexts --output name | grep -qx "$1" || {
    echo "ERROR: kube context '$1' not found; merge it first (e.g. talosctl kubeconfig)" >&2
    return 1
  }
  kubectl config use-context "$1" >/dev/null
}
