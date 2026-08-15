# GitHub Actions Signing Configuration

To enable automated signing of the APK in GitHub Actions CI/CD, you need to add the signing secrets to your GitHub repository.

## How to Add Secrets to GitHub

1. Navigate to your GitHub repository
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Add the following secrets:

## Required Secrets

### 1. KEYSTORE
The base64-encoded signing key (key.jks).

**To generate the base64 value:**
```bash
cd manager
base64 -i keys/pvtmanager/key.jks | pbcopy  # macOS: copies to clipboard
# OR
base64 -w0 keys/pvtmanager/key.jks > /tmp/keystore_base64.txt  # Linux/macOS
# Then copy the contents of /tmp/keystore_base64.txt to the secret
```

**Secret Name:** `KEYSTORE`  
**Secret Value:** The base64-encoded key.jks file contents

### 2. KEYSTORE_PASSWORD
The password for the keystore.

**Secret Name:** `KEYSTORE_PASSWORD`  
**Secret Value:** `changeme` (or the password you used when generating the key)

### 3. KEY_ALIAS
The alias of the key within the keystore.

**Secret Name:** `KEY_ALIAS`  
**Secret Value:** `pvtmanager`

### 4. KEY_PASSWORD
The password for the private key.

**Secret Name:** `KEY_PASSWORD`  
**Secret Value:** `changeme` (or the password you used when generating the key)

## Verification

After adding the secrets, you can verify they're set up correctly by:

1. Pushing a commit to trigger a build
2. Checking the GitHub Actions workflow log
3. Looking for "Write key" step output (it should not show errors)

## Security Notes

- **NEVER** commit the `key.jks` file to the repository (it's in `.gitignore`)
- **NEVER** commit passwords in code (use GitHub Secrets)
- **NEVER** share the keystore file or passwords
- Keep the keystore file (`manager/keys/pvtmanager/key.jks`) in a secure location

## If You Want to Change the Key

If you want to use a different password or regenerate the key for security reasons:

1. Generate a new key with `./manager/newbrand.sh <new-alias> '<new-password>' keys/<new-alias>`
2. Update `manager/keystore.properties` with the new paths and passwords
3. Update all four GitHub Secrets with the new values
4. Update the kernel/Kbuild file if the size/hash changes (they shouldn't for RSA-2048, but verify)

## Existing Build Workflow References

The GitHub Actions workflows (`build-manager.yml` and `build-manager-ci.yml`) are already configured to:
- Read these secrets during builds
- Decode the base64 KEYSTORE and save it as `key.jks`
- Write the signing credentials to `gradle.properties`
- Sign the APK with v2-only signing (no v1 or v3 signatures)

No changes are needed to the workflow files themselves.
