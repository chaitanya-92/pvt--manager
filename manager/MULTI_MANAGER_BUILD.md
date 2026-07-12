# Multiple Managers — Different Keys

How to run several independent root-manager brands (like LordSu, but more than one),
each with its **own signing key**, all trusted by the same KernelSU-Next kernel/LKM.

## How trust works

The kernel identifies a manager purely by its **APK signing certificate** —
`is_manager_apk()` in `kernel/manager/apk_sign.c` compares the cert's `(size, sha256)`
against baked-in values. Out of the box it checks exactly **one** cert
(`EXPECTED_MANAGER_SIZE` / `EXPECTED_MANAGER_HASH`), so only one brand is trusted.

To trust several brands with different keys, the kernel must check a **list** of certs.
That change is already applied:

- `kernel/manager/apk_sign.c` — `is_manager_apk()` now tries the primary cert plus
  optional extra slots (`EXPECTED_MANAGER_SIZE_2..4`), first match wins.
- `kernel/Kbuild` — optional `KSU_NEXT_MANAGER_SIZE_2..4` / `_HASH_2..4` macros feed
  those slots. Slot 1 stays the primary (currently LordSu).

So: **slot 1 = LordSu**, slots 2–4 = up to three more brands. Add more slots by
extending both files the same way if you need >4.

## The hard limits (do not violate)

1. **Cert ≤ 1024 bytes** → use **RSA-2048** (≈711–720 bytes). RSA-4096 (~1369 B) is
   rejected with "cert length overlimit".
2. **APK signed with v2 scheme ONLY** — no v1 (JAR), no v3/v3.1. The inherited
   `apksign` config already does this; verify per brand after building.
3. **Do NOT define `KSU_MANAGER_PACKAGE`.** It pins the kernel to a single package
   name, which breaks multi-brand (each brand has its own package). Signature alone
   is unique enough.

## Process — per new brand

Repeat this whole section for each brand (call them brand-B, brand-C, …).

### 1. Generate the brand's key + get its size/hash

```bash
cd manager
./newbrand.sh <alias> '<storepass>' keys/<alias>
# e.g. ./newbrand.sh xsu 'S3cret!' keys/xsu
```

It prints the `KSU_NEXT_MANAGER_SIZE_n` / `KSU_NEXT_MANAGER_HASH_n` lines and where
the `key.jks` landed. Keys live under `manager/keys/` (gitignored).

### 2. Wire the cert into the kernel (one free slot)

Edit `kernel/Kbuild`, fill the next unused slot with the values from step 1:

```make
KSU_NEXT_MANAGER_SIZE_2 := 0x2cd
KSU_NEXT_MANAGER_HASH_2 := 9d2b...ff1f84
```

(Use `_2` for the first extra brand, `_3` for the second, `_4` for the third.)

### 3. Rebrand the manager app

Each brand is a separate copy/build of `manager/` with its own identity — exactly the
LordSu rebrand steps in `LORDSU_BUILD.md`, changed per brand:

- **applicationId / package** — e.g. `com.xsu.manager` (must be unique per brand).
- **App name + icon/branding** — strings and drawables.
- **Signing config** — point `keystore.properties` (or CI `KEYSTORE` secret) at this
  brand's `keys/<alias>/key.jks`, alias, and passwords.
- Keep v2-only signing (`enableV1Signing=false`, `enableV2Signing=true`,
  `enableV3Signing=false`).

Tip: the `manager/spoof` script auto-randomizes the `com.rifsxd.ksunext` package
across the tree — handy as a starting point if you want quick throwaway package names
rather than hand-picking each.

### 4. Build each brand's APK

```bash
cd manager
./gradlew clean assembleRelease   # per brand's checkout/signing config
```

Verify v2-only + correct hash before shipping:

```bash
apksigner verify --verbose app-release.apk | grep -i "scheme v"     # v1=false v2=true v3=false
apksigner verify --print-certs app-release.apk | grep -i "SHA-256"  # == the brand's hash
```

### 5. Build the kernel / LKM once (trusts all brands)

Build the LKM (or kernel) **after** all brand slots are filled in `kernel/Kbuild`.
A single LKM now recognizes every wired brand. Flash it (patch `boot.img` → fastboot),
reboot, then install any brand's APK — each shows "Working".

## Checklist

- [ ] One RSA-2048 key per brand (`newbrand.sh`), each cert ≤ 1024 bytes.
- [ ] Each brand's size/hash in its own `kernel/Kbuild` slot.
- [ ] Unique `applicationId` per brand; `KSU_MANAGER_PACKAGE` left undefined.
- [ ] Each APK signed v2-only with its own key; hash verified.
- [ ] LKM/kernel rebuilt after all slots filled; flashed once.

## Gotchas

- **Reusing one key across brands?** Then you don't need extra slots at all — same
  cert hash, so the single primary slot already trusts them. Extra slots are only for
  *different* keys. (You picked different keys.)
- **A brand shows "not working":** almost always the APK picked up a v1 or v3
  signature, or the slot hash doesn't match the key that actually signed it. Re-run
  the two `apksigner verify` checks above.
- **Cert > 1024 bytes:** you used RSA-4096 or a long CN/SAN. Regenerate RSA-2048.
