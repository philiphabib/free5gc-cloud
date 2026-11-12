#!/usr/bin/env python3
"""add-certs-mount.py — add free5gc-certs volume+volumeMount to NF deployments."""

import sys
import time
from pathlib import Path

try:
    from ruamel.yaml import YAML
except ImportError:
    print("ruamel.yaml not found. Installing to user site...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--user", "ruamel.yaml"])
    from ruamel.yaml import YAML

CHART = Path.home() / "free5gc-cloud" / "templates"
NFS = ["amf", "ausf", "smf", "udm", "udr", "pcf", "nssf", "nrf", "n3iwf"]
SECRET = "free5gc-certs"
MOUNT_PATH = "/free5gc/cert"
VOL_NAME = "free5gc-certs"

yaml = YAML()
yaml.preserve_quotes = True
yaml.width = 4096


def patch(path, nf):
    with path.open() as f:
        doc = yaml.load(f)

    if not isinstance(doc, dict) or doc.get("kind") != "Deployment":
        print("  ! {} is not a Deployment".format(path.name))
        return False

    spec = doc.setdefault("spec", {}).setdefault("template", {}).setdefault("spec", {})
    containers = spec.get("containers", [])
    if not containers:
        print("  ! no containers in {}".format(path.name))
        return False

    target = None
    for c in containers:
        if c.get("name") == nf:
            target = c
            break
    if target is None:
        target = containers[0]

    for vm in target.get("volumeMounts", []) or []:
        if vm.get("name") == VOL_NAME:
            print("  = {} already patched".format(nf))
            return False

    vms = target.setdefault("volumeMounts", [])
    vms.append({
        "name": VOL_NAME,
        "mountPath": MOUNT_PATH,
        "readOnly": True,
    })

    vols = spec.setdefault("volumes", [])
    if not any(v.get("name") == VOL_NAME for v in vols):
        vols.append({
            "name": VOL_NAME,
            "secret": {"secretName": SECRET},
        })

    backup = path.with_suffix(path.suffix + ".bak." + str(int(time.time())))
    backup.write_bytes(path.read_bytes())

    with path.open("w") as f:
        yaml.dump(doc, f)

    print("  + patched {}".format(nf))
    return True


def main():
    print("=== Patching NF deployments ===")
    patched = 0
    for nf in NFS:
        path = CHART / nf / "deployment.yaml"
        if not path.exists():
            print("  ! {} not found".format(path))
            continue
        try:
            if patch(path, nf):
                patched += 1
        except Exception as e:
            print("  x {}: {}".format(nf, e))

    print("\nPatched {} deployments.\n".format(patched))

    print("=== Verification ===")
    ok = True
    for nf in NFS:
        path = CHART / nf / "deployment.yaml"
        if not path.exists():
            continue
        with path.open() as f:
            doc = yaml.load(f)
        spec = doc.get("spec", {}).get("template", {}).get("spec", {})
        vols = spec.get("volumes", []) or []
        has_vol = any(v.get("name") == VOL_NAME for v in vols)
        has_mount = any(
            vm.get("name") == VOL_NAME
            for c in spec.get("containers", [])
            for vm in (c.get("volumeMounts") or [])
        )
        if has_vol and has_mount:
            print("  OK {}".format(nf))
        else:
            print("  !! {} (vol={}, mount={})".format(nf, has_vol, has_mount))
            ok = False

    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
