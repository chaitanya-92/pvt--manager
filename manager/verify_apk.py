#!/usr/bin/env python3
"""Verify an APK's signing cert the same way the KernelSU-Next kernel does.

Reproduces kernel/manager/apk_sign.c: finds the v2 signature block, extracts the
first certificate, and SHA-256s its DER bytes. Also flags v1 / v3 signatures,
which the kernel rejects. No Android SDK / apksigner required.

Usage:  python3 verify_apk.py <path-to.apk> [expected_sha256]
Default expected hash = Aarsu primary cert baked into kernel/Kbuild.
"""
import sys, struct, hashlib, zipfile

EXPECTED = "a36f7f8ac6f7a52f1111fb59b9b457ade29325a99533c97c9e31e900cebf5882"

V2_ID, V3_ID, V31_ID = 0x7109871a, 0xf05368c0, 0x1b93ad61
MAGIC = b"APK Sig Block 42"


def find_cd_offset(data):
    # locate End Of Central Directory, read central-directory offset
    i = data.rfind(b"PK\x05\x06")
    if i < 0:
        raise ValueError("EOCD not found (not a zip/apk)")
    return struct.unpack_from("<I", data, i + 16)[0]


def get_v2_cert_and_flags(data):
    cd = find_cd_offset(data)
    size_of_block, magic = struct.unpack_from("<Q", data, cd - 24)[0], data[cd - 16:cd]
    if magic != MAGIC:
        raise ValueError("APK Signing Block magic not found (unsigned?)")
    start = cd - size_of_block - 8
    pos = start + 8
    cert = None
    has_v3 = False
    while pos < cd - 24:
        pair_len = struct.unpack_from("<Q", data, pos)[0]
        pid = struct.unpack_from("<I", data, pos + 8)[0]
        val = data[pos + 12: pos + 8 + pair_len]
        if pid == V2_ID:
            cert = parse_first_cert(val)
        elif pid in (V3_ID, V31_ID):
            has_v3 = True
        pos += 8 + pair_len
    return cert, has_v3


def parse_first_cert(val):
    # mirror kernel check_block field walk
    o = 0
    o += 4               # signers-sequence length
    o += 4               # signer length
    o += 4               # signed-data length
    digests_len = struct.unpack_from("<I", val, o)[0]; o += 4
    o += digests_len     # skip digests
    o += 4               # certificates-sequence length
    cert_len = struct.unpack_from("<I", val, o)[0]; o += 4
    return val[o:o + cert_len]


def has_v1(path):
    with zipfile.ZipFile(path) as z:
        for n in z.namelist():
            if n.upper() == "META-INF/MANIFEST.MF" or n.upper().endswith((".RSA", ".DSA", ".EC")):
                return True
    return False


def main():
    if len(sys.argv) < 2:
        print(__doc__); sys.exit(2)
    path = sys.argv[1]
    expected = (sys.argv[2] if len(sys.argv) > 2 else EXPECTED).lower()
    data = open(path, "rb").read()
    cert, v3 = get_v2_cert_and_flags(data)
    v1 = has_v1(path)

    print(f"APK        : {path}")
    if cert is None:
        print("v2 cert    : NOT FOUND  -> kernel will reject (no v2 signature)")
        sys.exit(1)
    digest = hashlib.sha256(cert).hexdigest()
    print(f"cert bytes : {len(cert)}  (limit 1024)")
    print(f"v2 SHA-256 : {digest}")
    print(f"expected   : {expected}")
    print(f"v1 present : {v1}   (must be False)")
    print(f"v3 present : {v3}   (must be False)")

    ok = (digest == expected) and (len(cert) <= 1024) and (not v1) and (not v3)
    print("\nRESULT     : " + ("PASS - Aarsu will be recognized" if ok
                               else "FAIL - see mismatched line(s) above"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
