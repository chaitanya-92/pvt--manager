# PvtManager independent manager

This branch gives the manager its own application identity, branding, and signing certificate.

- Application ID: `com.pvtmanager.manager`
- App name: `PvtManager`
- Certificate size: `0x2d4` (724 bytes)
- Certificate SHA-256: `170a759adce1829245973792032e404783a9d0e3efdfe87f0804350d7ca3a1a9`
- Key algorithm: RSA-2048

The private JKS is not committed. `manager/.gitignore` excludes `key.jks`, `keystore.properties`, `keys/`, and certificate files.

## Local signing

Create `manager/keystore.properties`:

```properties
KEYSTORE_FILE=keys/pvtmanager/pvtmanager.jks
KEYSTORE_PASSWORD=<your-password>
KEY_ALIAS=pvtmanager
KEY_PASSWORD=<your-password>
```

## GitHub Actions secrets

Use dedicated secrets:

- `PVTMANAGER_KEYSTORE`
- `PVTMANAGER_KEYSTORE_PASSWORD`
- `PVTMANAGER_KEY_ALIAS`
- `PVTMANAGER_KEY_PASSWORD`

The workflows map these secrets to the Gradle signing properties expected by the Android signing plugin.

## Certificate verification

After building the release APK:

```bash
apksigner verify --print-certs manager/app/build/outputs/apk/release/*.apk
```

The SHA-256 certificate fingerprint must be:

`170a759adce1829245973792032e404783a9d0e3efdfe87f0804350d7ca3a1a9`
