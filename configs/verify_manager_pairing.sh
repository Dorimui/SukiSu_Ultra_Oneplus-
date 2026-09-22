#!/usr/bin/env bash
set -euo pipefail

: "${KSU_FOLDER:?}"
: "${COMMON_KERNEL_FOLDER:?}"
: "${KSU_COMMIT_SHA:?}"
: "${KSUVER:?}"
: "${KSU_UAPI_VERSION:?}"

[ "$(git -C "$KSU_FOLDER" rev-parse HEAD)" = "$KSU_COMMIT_SHA" ] || {
  echo '::error::SukiSU source changed after manager pairing was selected'
  exit 1
}

# SUSFS must not replace the shared userspace/kernel ABI after it is selected.
git -C "$KSU_FOLDER" show HEAD:uapi/supercall.h | cmp - "$KSU_FOLDER/uapi/supercall.h"
git -C "$KSU_FOLDER" show HEAD:uapi/app_profile.h | cmp - "$KSU_FOLDER/uapi/app_profile.h"
grep -qxF "static const __u32 KERNEL_SU_UAPI_VERSION = $KSU_UAPI_VERSION;" "$KSU_FOLDER/uapi/supercall.h"

for root in "$KSU_FOLDER/kernel" "$COMMON_KERNEL_FOLDER/drivers/kernelsu"; do
  grep -qxF "KSU_VERSION := $KSUVER" "$root/Kbuild"
  grep -qxF '#define KERNEL_SU_VERSION KSU_VERSION' "$root/include/ksu.h"
  grep -qxF '#include "ksu.h"' "$root/supercall/dispatch.c"
  if grep -qE '^[[:space:]]*#define[[:space:]]+KERNEL_SU_VERSION' "$root/supercall/dispatch.c"; then
    echo "::error::Runtime driver version overridden in $root/supercall/dispatch.c"
    exit 1
  fi
done

echo "Manager pairing verified: source=$KSU_COMMIT_SHA version=$KSUVER UAPI=$KSU_UAPI_VERSION"
