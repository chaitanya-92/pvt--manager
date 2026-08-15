# Independent KernelSU-Next Manager Setup

This document summarizes the changes made to make this an independent KernelSU-Next manager with its own signing key.

## What Was Done

### 1. Generated New RSA-2048 Signing Key ✓
- **Location:** `manager/keys/pvtmanager/key.jks`
- **Key Alias:** `pvtmanager`
- **Password:** `changeme` (currently; can be regenerated with a stronger password)
- **Certificate Size:** 0x2d4 (724 bytes) — within 1024-byte kernel limit
- **Certificate Hash:** `3ade1d7529ef0261ad3b8d5eb991aa97e524e9f44b606520d33d2f169d0cc006`

**Security:** The keystore file is gitignored and will NOT be committed.

### 2. Updated Kernel Configuration ✓
**File:** `kernel/Kbuild`

The kernel now trusts TWO managers:

| Slot | Manager | Package | Size | Hash |
|------|---------|---------|------|------|
| 1 | System Service (Primary) | com.sysservice.manager | 0x2cf | c8ef6fcd62c9bd64744f79450b8f16ed48db465e60c083b259df1596b5cbdb05 |
| 2 | pvtmanager (Independent) | (unchanged) | 0x2d4 | 3ade1d7529ef0261ad3b8d5eb991aa97e524e9f44b606520d33d2f169d0cc006 |

The System Service manager is the primary (slot 1) and retains all existing functionality. The pvtmanager (slot 2) is an additional independent manager using the new signing key.

### 3. Set Up Local Signing Configuration ✓
**File:** `manager/keystore.properties` (gitignored)

Created signing credentials that the build system reads:
```properties
KEYSTORE_FILE=keys/pvtmanager/key.jks
KEYSTORE_PASSWORD=changeme
KEY_ALIAS=pvtmanager
KEY_PASSWORD=changeme
```

This allows local builds to sign the APK automatically.

### 4. Prepared GitHub Actions Setup ✓
**File:** `GITHUB_SIGNING_SETUP.md`

Detailed instructions for adding GitHub repository secrets so CI/CD builds can also sign the APK. See that file for step-by-step instructions.

## Next Steps for You

### Immediate Actions

1. **Review and Keep the Key Secure**
   - The signing key (`manager/keys/pvtmanager/key.jks`) is NOW YOUR RESPONSIBILITY
   - Back it up securely in a safe location
   - Do NOT commit it (it's gitignored)
   - Do NOT share it

2. **Change the Password** (Recommended)
   If `changeme` is not secure enough for your use case:
   - Generate a new key: `./manager/newbrand.sh pvtmanager '<STRONG_PASSWORD>' keys/pvtmanager`
   - Update `manager/keystore.properties` with the new password
   - Update GitHub repository secrets (see GITHUB_SIGNING_SETUP.md)

3. **Set Up GitHub Secrets**
   Follow the instructions in `GITHUB_SIGNING_SETUP.md` to add the signing secrets to your GitHub repository. Without these, CI builds won't be able to sign the APK.

4. **Test a Build** (Optional but recommended)
   ```bash
   cd manager
   ./gradlew clean assembleRelease
   
   # Verify v2-only signing (no v1 or v3):
   apksigner verify --verbose app/build/outputs/apk/release/app-release.apk | grep -i "scheme v"
   # Should show: v1=false, v2=true, v3=false
   
   # Verify certificate hash:
   apksigner verify --print-certs app/build/outputs/apk/release/app-release.apk | grep -i "SHA-256"
   # Should show: 3ade1d7529ef0261ad3b8d5eb991aa97e524e9f44b606520d33d2f169d0cc006
   ```

## Important Notes

### Package Name & UI
- **No changes** were made to the manager's package name or UI
- The manager still uses `com.sysservice.manager` as its package
- All existing functionality is preserved
- Only the signing key changed (slot 2 in kernel)

### Kernel Trusts Both Managers
- The kernel/LKM still recognizes the original System Service manager (slot 1) as primary
- The new signing key is added as slot 2 (additional trusted manager)
- Both will work independently with their respective signing keys

### How the Kernel Verifies Managers
The kernel (`kernel/manager/apk_sign.c`) checks the APK's signing certificate:
1. Extracts the first certificate from the APK v2 signing block
2. Computes SHA-256 hash of the DER certificate bytes
3. Compares against baked-in size + hash values
4. Matches ANY defined slot (primary or extras) = manager is trusted
5. No match = manager is rejected

### Build System
- The gradle build is already configured to read signing credentials from `keystore.properties`
- No changes to gradle configuration files were needed
- APK signing uses v2 scheme only (no v1/JAR, no v3/v3.1 signatures)

## Verification Checklist

- [x] New RSA-2048 key generated (0x2d4 size, within 1024-byte limit)
- [x] Certificate hash added to `kernel/Kbuild` as slot 2
- [x] Local `manager/keystore.properties` created and gitignored
- [x] GitHub Secrets setup documentation provided
- [x] Original manager (com.sysservice.manager) remains unchanged
- [x] No related code modified
- [x] No secrets committed to repo

## File Summary

**Modified:**
- `kernel/Kbuild` — Added KSU_NEXT_MANAGER_SIZE_2 and KSU_NEXT_MANAGER_HASH_2

**Created:**
- `manager/keystore.properties` — Signing configuration (gitignored)
- `manager/keys/pvtmanager/key.jks` — Signing key (gitignored)
- `GITHUB_SIGNING_SETUP.md` — Instructions for GitHub Actions secrets
- `INDEPENDENT_MANAGER_SETUP.md` — This file

**No Modifications To:**
- Manager app code, package, UI, or functionality
- GitHub Actions workflow files
- Any other kernel code
- Build system configuration

## Troubleshooting

### Build signing fails
- Ensure `manager/keystore.properties` exists and is readable
- Verify all passwords are correct
- Check that `manager/keys/pvtmanager/key.jks` exists

### GitHub Actions build fails
- Verify all 4 secrets are set in repository settings
- Check that KEYSTORE is properly base64-encoded
- Review `GITHUB_SIGNING_SETUP.md` for encoding instructions

### Kernel rejects APK
- Verify APK has v2-only signing (no v1/v3): `apksigner verify --verbose <apk>`
- Verify certificate hash matches kernel config: `apksigner verify --print-certs <apk> | grep SHA-256`
- Ensure hash matches exactly (case-sensitive): `3ade1d7529ef0261ad3b8d5eb991aa97e524e9f44b606520d33d2f169d0cc006`

## Additional Resources

- See `manager/LORDSU_BUILD.md` for signing certificate format details
- See `manager/MULTI_MANAGER_BUILD.md` for multi-brand manager setup
- See `kernel/manager/apk_sign.c` for kernel signature verification logic
