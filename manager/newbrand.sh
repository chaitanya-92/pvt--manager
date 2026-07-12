#!/usr/bin/env bash
#
# newbrand.sh — generate a per-brand signing key for a KernelSU-Next manager
# and print the size/hash values to bake into kernel/Kbuild.
#
# Usage:
#   ./newbrand.sh <alias> <storepass> [out-dir]
#
# Example:
#   ./newbrand.sh xsu 'S3cret!' keys/xsu
#
# Produces (in out-dir, default ./keys/<alias>):
#   key.jks   — the RSA-2048 keystore for this brand (KEEP PRIVATE, gitignored)
#   cert.der  — exported cert (only used to compute size/hash; safe to delete)
#
# Then it prints the exact KSU_NEXT_MANAGER_SIZE_n / KSU_NEXT_MANAGER_HASH_n
# lines to add to kernel/Kbuild for the next free slot.
#
# HARD LIMITS enforced by the kernel (kernel/manager/apk_sign.c):
#   * Cert must be <= 1024 bytes  -> RSA-2048 only (RSA-4096 is too big).
#   * APK must be signed v2-ONLY  -> no v1 (JAR) and no v3/v3.1 blocks.

set -euo pipefail

ALIAS="${1:-}"
STOREPASS="${2:-}"
OUTDIR="${3:-keys/${ALIAS}}"

if [[ -z "$ALIAS" || -z "$STOREPASS" ]]; then
  echo "Usage: $0 <alias> <storepass> [out-dir]" >&2
  exit 1
fi

command -v keytool  >/dev/null || { echo "keytool not found (install a JDK)"    >&2; exit 1; }
command -v sha256sum >/dev/null || SHA256() { shasum -a 256 "$1"; }
command -v sha256sum >/dev/null && SHA256() { sha256sum "$1"; }

mkdir -p "$OUTDIR"
JKS="$OUTDIR/key.jks"
DER="$OUTDIR/cert.der"

if [[ -f "$JKS" ]]; then
  echo "Refusing to overwrite existing $JKS — pick a new alias/out-dir." >&2
  exit 1
fi

echo "==> Generating RSA-2048 key for brand '$ALIAS' ..."
keytool -genkeypair -v -keystore "$JKS" -alias "$ALIAS" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$STOREPASS" -keypass "$STOREPASS" \
  -dname "CN=$ALIAS" >/dev/null

echo "==> Exporting certificate ..."
keytool -exportcert -keystore "$JKS" -alias "$ALIAS" \
  -storepass "$STOREPASS" -file "$DER" -rfc >/dev/null 2>&1 || \
keytool -exportcert -keystore "$JKS" -alias "$ALIAS" \
  -storepass "$STOREPASS" -file "$DER" >/dev/null

# The kernel hashes the DER cert bytes exactly as embedded in the APK v2 block,
# so use the raw DER (not -rfc/PEM) for size + hash.
keytool -exportcert -keystore "$JKS" -alias "$ALIAS" \
  -storepass "$STOREPASS" -file "$DER" >/dev/null

SIZE_DEC=$(stat -c%s "$DER" 2>/dev/null || stat -f%z "$DER")
SIZE_HEX=$(printf '0x%x' "$SIZE_DEC")
HASH=$(SHA256 "$DER" | awk '{print $1}')

echo
echo "==> Brand '$ALIAS' certificate:"
echo "    size = $SIZE_HEX  ($SIZE_DEC bytes)"
echo "    hash = $HASH"

if (( SIZE_DEC > 1024 )); then
  echo
  echo "!! ERROR: cert is $SIZE_DEC bytes (> 1024). The kernel will reject it." >&2
  echo "!! Regenerate with RSA-2048 (this script already does) and a short CN." >&2
  exit 1
fi

cat <<EOF

==> Add ONE free slot to kernel/Kbuild (use _2, _3 or _4 — first unused):

KSU_NEXT_MANAGER_SIZE_2 := $SIZE_HEX
KSU_NEXT_MANAGER_HASH_2 := $HASH

Slot #1 is the primary manager (KSU_NEXT_MANAGER_SIZE / _HASH). Extra brands
go in _2 / _3 / _4. Do NOT set KSU_MANAGER_PACKAGE (brands differ by package).

==> Then, for this brand's manager app, point its signing config at:
    keystore : $JKS
    alias    : $ALIAS
    (store/key password as given)

==> After building the APK, verify v2-only signing:
    apksigner verify --verbose app-release.apk | grep -i "scheme v"
      -> v1=false  v2=true  v3=false
    apksigner verify --print-certs app-release.apk | grep -i "SHA-256"
      -> must equal $HASH

rm -f "$DER" when done (only size/hash matter; keep key.jks safe).
EOF
