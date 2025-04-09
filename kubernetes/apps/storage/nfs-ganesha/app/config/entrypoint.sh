#!/bin/sh
set -e

ln -sf /proc/self/mounts /etc/mtab
exec /usr/bin/catatonit -- /usr/local/bin/ganesha.nfsd "$@"
