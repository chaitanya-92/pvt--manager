# LordSu — Private Root Manager Build Notes

Rebrand of KernelSU-Next into a private, exclusive root manager, LKM-mode (no custom kernel).

## Identity

| | |
|---|---|
| App name | **LordSu** |
| Package / applicationId | `com.lordsu.manager` |
| Keystore | `manager/key.jks` (gitignored) |
| Key alias | `lordsu` |
| Store/key password | `<kept-private>` *(change for real use)* |
| Key type | **RSA 2048** (required — see limit below) |

## Signing certificate values baked into the kernel

```
KSU_NEXT_MANAGER_SIZE = 0x2c7   (711 bytes)
KSU_NEXT_MANAGER_HASH = a27d92c6d30e471e2fe97088c8d61700b913caf493cb5adcda8aeffe1c8c791e
```

Already applied to `kernel/Kbuild` (lines ~127 and ~131), replacing the official
KernelSU-Next defaults (`0x3e6` / `79e5...`). This makes LordSu the **only** trusted
manager — there is no second-signature fallback, so the stock KernelSU-Next / KowSU /
SukiSU managers will be rejected.

## HARD REQUIREMENTS discovered in the kernel source (`kernel/manager/apk_sign.c`)

1. **Certificate must be <= 1024 bytes.** The kernel copies the signing cert into a
   fixed `CERT_MAX_LENGTH 1024` buffer and rejects anything bigger ("cert length
   overlimit"). RSA-4096 (1369 bytes) is too big — that's why the key is **RSA-2048**
   (711 bytes). Do NOT switch back to 4096.
2. **APK must be signed with v2 scheme ONLY.** The kernel rejects the APK if it also
   has a **v1** (JAR) signature ("Unexpected v1 signature scheme") or a **v3 / v3.1**
   signature ("Unexpected v3 signature scheme"), and requires exactly one v2 block.
   The inherited `apksign` build config already produces this for the official
   manager; we only swapped the key, so it should still hold — **verify after build**
   (see below).

## What is already done

Manager (`manager/`): package renamed to `com.lordsu.manager`; app name LordSu; crown
header logo; Contributors card removed; "Having trouble?" -> github.com/chaitanya-92 and
t.me/Who_colki; own RSA-2048 signing key wired via gitignored `keystore.properties`.

Kernel (`kernel/`): `kernel/Kbuild` now trusts LordSu's signature (values above).

## Build & install (LKM path — like KowSU, no custom kernel)

CI is already wired: `build-manager.yml` decodes a base64 `KEYSTORE` secret into
`key.jks`, signs the release, and (as a dependency job) also builds the LKM. I added
`main` as a trigger branch and enabled APK artifact upload on `main`.

1. Create the GitHub repo (Private recommended) and push this whole `KernelSU-Next`
   repo to `main` (commands in chat).
2. Add these **Actions secrets** (repo → Settings → Secrets and variables → Actions):
   - `KEYSTORE`          = base64 of `manager/key.jks`  → `base64 -i manager/key.jks | pbcopy`
   - `KEYSTORE_PASSWORD` = `<kept-private>`
   - `KEY_ALIAS`         = `lordsu`
   - `KEY_PASSWORD`      = `<kept-private>`
3. The push to `main` auto-runs **Build Manager** (or run it manually from the Actions
   tab). It produces two artifacts: **`manager`** (the signed LordSu APK) and the
   **LKM `kernelsu.ko`** for `android12-5.10` (your Moto G73).
4. On the phone: install the LordSu APK. Open LordSu → **Install** → patch your stock
   `boot.img` with the custom LKM → flash the patched boot (fastboot). Reboot.
5. LordSu shows "Working"; KowSU (if still installed) is no longer recognized.

## VERIFY after building the release APK (important)

```bash
# 1) confirm v2-only signing (must show v2=true, v1=false, v3=false)
apksigner verify --verbose app-release.apk | grep -i "scheme v"

# 2) confirm the cert hash matches what we baked into the kernel
apksigner verify --print-certs app-release.apk | grep -i "SHA-256"
# should equal: a27d92c6d30e471e2fe97088c8d61700b913caf493cb5adcda8aeffe1c8c791e
```
If v1 or v3 is present, disable them in the app signing config (enableV1Signing=false,
enableV3Signing=false, enableV2Signing=true) and rebuild.

## Regenerate the key with your own password (recommended)

```bash
cd manager
: > key.jks   # truncate (can't delete on this mount); or just rm on your Mac
keytool -genkeypair -v -keystore key.jks -alias lordsu \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass <YOUR_PASS> -keypass <YOUR_PASS> -dname "CN=LordSu"
keytool -exportcert -keystore key.jks -alias lordsu -storepass <YOUR_PASS> -file cert.der
echo "SIZE(hex) = 0x$(printf '%x' $(stat -c%s cert.der))"
echo "HASH      = $(sha256sum cert.der | awk '{print $1}')"
rm cert.der
# then update keystore.properties AND kernel/Kbuild with the new SIZE/HASH,
# keeping the cert under 1024 bytes.
```

## Optional: also lock by package name

In `kernel/Kbuild` you can additionally require the manager package name by defining
`KSU_MANAGER_PACKAGE := com.lordsu.manager` (the code guards on `#ifdef
KSU_MANAGER_PACKAGE`). Signature alone is already unique, so this is optional.
