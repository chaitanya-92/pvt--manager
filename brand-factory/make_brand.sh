#!/usr/bin/env bash
#
# make_brand.sh — generate ONE complete, independent root-manager brand.
#
# Usage:
#   ./make_brand.sh "Display Name" <pkgslug> [password]
#
# Example:
#   ./make_brand.sh "Nova SU" novasu
#   ./make_brand.sh "Aster SU" astersu 'MyStrongPass'
#
# Produces under ./out/<pkgslug>/ :
#   * a full project renamed to com.<pkgslug>.manager, app name "Display Name"
#   * a fresh RSA-2048 signing key (keys/<pkgslug>/key.jks)
#   * kernel/Kbuild wired to trust ONLY this brand's cert
#   * a monogram icon (initials on a colored background)
# And under ./dist/ :
#   * <pkgslug>-project.zip        -> push this to the brand's GitHub repo
#   * <pkgslug>_KEYSTORE_base64.txt -> paste into the repo's KEYSTORE secret
# Appends a row to ./BRANDS.md with package, hash, password.
#
# Requirements: bash, rsync, keytool (JDK), python3 + Pillow, zip.

set -euo pipefail

NAME="${1:-}"; PKG="${2:-}"; PASS="${3:-${PKG}2026}"
if [[ -z "$NAME" || -z "$PKG" ]]; then
  echo "Usage: $0 \"Display Name\" <pkgslug> [password]" >&2; exit 1
fi
if ! [[ "$PKG" =~ ^[a-z][a-z0-9]*$ ]]; then
  echo "pkgslug must be lowercase letters/digits only (e.g. novasu)" >&2; exit 1
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
TPL="$HERE/template"
BASE=sonasu                       # package token used inside the template
OUT="$HERE/out/$PKG"
DIST="$HERE/dist"
[[ -d "$TPL" ]] || { echo "template not found at $TPL" >&2; exit 1; }
command -v keytool >/dev/null || { echo "keytool not found (install a JDK)" >&2; exit 1; }

echo "==> [$NAME] copying template -> out/$PKG"
rm -rf "$OUT"; mkdir -p "$OUT" "$DIST"
rsync -a --exclude='manager/keys' --exclude='**/build/' --exclude='**/.gradle/' \
      --exclude='keystore.properties' "$TPL"/ "$OUT"/

cd "$OUT"

echo "==> renaming package com.$BASE.manager -> com.$PKG.manager"
find manager kernel -type f \( -name '*.kt' -o -name '*.java' -o -name '*.kts' -o -name '*.xml' \
     -o -name '*.aidl' -o -name '*.cc' -o -name '*.cpp' -o -name '*.h' -o -name '*.properties' \) -print0 \
  | xargs -0 sed -i \
      -e "s/com\.$BASE\.manager/com.$PKG.manager/g" \
      -e "s|com/$BASE/manager|com/$PKG/manager|g" \
      -e "s/com_${BASE}_manager/com_${PKG}_manager/g"
mv "manager/app/src/main/java/com/$BASE" "manager/app/src/main/java/com/$PKG"
mv "manager/app/src/main/aidl/com/$BASE" "manager/app/src/main/aidl/com/$PKG"

echo "==> app name + output filename"
sed -i "s#<string name=\"app_name\" translatable=\"false\">[^<]*</string>#<string name=\"app_name\" translatable=\"false\">$NAME</string>#" \
  manager/app/src/main/res/values/strings.xml
PREFIX="$(echo "$NAME" | tr ' ' '_')"
sed -i "s/output.outputFileName = \"[^\"]*_\${managerVersionName}/output.outputFileName = \"${PREFIX}_\${managerVersionName}/" \
  manager/app/build.gradle.kts

echo "==> generating RSA-2048 key"
( cd manager && ./newbrand.sh "$PKG" "$PASS" "keys/$PKG" >/dev/null )
SZ="0x$(printf '%x' "$(stat -c%s manager/keys/$PKG/cert.der 2>/dev/null || stat -f%z manager/keys/$PKG/cert.der)")"
HASH="$(sha256sum manager/keys/$PKG/cert.der 2>/dev/null | awk '{print $1}')"
[[ -z "$HASH" ]] && HASH="$(shasum -a 256 manager/keys/$PKG/cert.der | awk '{print $1}')"

echo "==> wiring kernel + verifier + keystore (hash $HASH)"
sed -i -E "s/# Primary manager:.*/# Primary manager: $NAME (com.$PKG.manager), RSA-2048./" kernel/Kbuild
sed -i -E "s/(KSU_NEXT_MANAGER_SIZE :=) .*/\1 $SZ/" kernel/Kbuild
sed -i -E "s/(KSU_NEXT_MANAGER_HASH :=) .*/\1 $HASH/" kernel/Kbuild
sed -i -E "s/^EXPECTED = \".*\"/EXPECTED = \"$HASH\"/" manager/verify_apk.py
cat > manager/keystore.properties <<EOF
KEYSTORE_FILE=keys/$PKG/key.jks
KEYSTORE_PASSWORD=$PASS
KEY_ALIAS=$PKG
KEY_PASSWORD=$PASS
EOF

echo "==> monogram icon"
python3 "$HERE/icon_gen.py" "manager/app/src/main/res" "$NAME"

echo "==> packaging"
base64 -w0 "manager/keys/$PKG/key.jks" 2>/dev/null > "$DIST/${PKG}_KEYSTORE_base64.txt" \
  || base64 -i "manager/keys/$PKG/key.jks" | tr -d '\n' > "$DIST/${PKG}_KEYSTORE_base64.txt"
( cd "$HERE/out" && rm -f "$DIST/${PKG}-project.zip" && \
  zip -rq "$DIST/${PKG}-project.zip" "$PKG" -x "$PKG/manager/keys/*" )

# sanity
LEFT="$(grep -rl "com\.$BASE\.manager" manager kernel 2>/dev/null | grep -v "keys/" || true)"
[[ -n "$LEFT" ]] && { echo "!! leftover base package refs:"; echo "$LEFT"; exit 1; }

# record
[[ -f "$HERE/BRANDS.md" ]] || echo "| Brand | Package | Cert hash | Key pass | Zip |
|---|---|---|---|---|" > "$HERE/BRANDS.md"
echo "| $NAME | com.$PKG.manager | \`$HASH\` | $PASS | dist/${PKG}-project.zip |" >> "$HERE/BRANDS.md"

cat <<EOF

======================================================================
DONE: $NAME
  package : com.$PKG.manager
  cert    : $SZ  hash=$HASH
  push    : dist/${PKG}-project.zip   -> new repo
  secret  : dist/${PKG}_KEYSTORE_base64.txt (KEYSTORE), pass=$PASS, alias=$PKG
======================================================================
EOF
