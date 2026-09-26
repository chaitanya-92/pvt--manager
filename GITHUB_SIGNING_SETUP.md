# PvtManager GitHub signing

Configure these Actions repository secrets:

`PVTMANAGER_KEYSTORE`, `PVTMANAGER_KEYSTORE_PASSWORD`, `PVTMANAGER_KEY_ALIAS`, `PVTMANAGER_KEY_PASSWORD`.

Generate a new private key locally with:

```bash
./manager/newbrand.sh pvtmanager '<strong-password>' keys/pvtmanager
```

Keep the resulting JKS private and never commit it.

The branch's current kernel trust value is:

```text
size = 0x2d4
sha256 = 170a759adce1829245973792032e404783a9d0e3efdfe87f0804350d7ca3a1a9
```

The Gradle build expects the temporary properties `KEYSTORE_FILE`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, and `KEY_PASSWORD`; the workflow supplies them from the dedicated PvtManager secrets.
