#!/usr/bin/env bash
set -euo pipefail

CHART="${HOME}/free5gc-cloud"
TEMPLATES="${CHART}/templates"
NFS=("amf" "ausf" "smf" "udm" "udr" "pcf" "nssf" "nrf" "n3iwf")

cd "$TEMPLATES"

for nf in "${NFS[@]}"; do
  FILE="${nf}/deployment.yaml"
  [[ -f "$FILE" ]] || { echo "skip $nf (no file)"; continue; }

  if grep -q "name: free5gc-certs" "$FILE"; then
    echo "already patched: $nf"
    continue
  fi

  cp "$FILE" "${FILE}.bak.$(date +%s)"

  python3 - "$FILE" <<'PYEOF'
import sys, re

path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()

# 1. Add "- name: free5gc-certs" mount inside the existing volumeMounts: block.
vm_start = None
for i, line in enumerate(lines):
    if line.rstrip() == "          volumeMounts:":
        vm_start = i
        break

if vm_start is None:
    sys.stderr.write("no volumeMounts block in {}\n".format(path))
    sys.exit(1)

# Find end of volumeMounts block (first line at 10-space indent that isn't a list item continuation)
vm_end = len(lines)
for j in range(vm_start + 1, len(lines)):
    line = lines[j]
    if re.match(r"^          [a-zA-Z]", line):   # next container key
        vm_end = j
        break

mount_block = [
    "            - name: free5gc-certs\n",
    "              mountPath: /free5gc/cert\n",
    "              readOnly: true\n",
]
lines[vm_end:vm_end] = mount_block

# 2. Merge the new volume under the existing "      volumes:" block.
vol_start = None
for i, line in enumerate(lines):
    if line.rstrip() == "      volumes:":
        vol_start = i
        break

if vol_start is None:
    sys.stderr.write("no volumes block in {}\n".format(path))
    sys.exit(1)

# Find end of volumes block (first line at 6-space indent that isn't a list item)
vol_end = len(lines)
for j in range(vol_start + 1, len(lines)):
    line = lines[j]
    if re.match(r"^      [a-zA-Z]", line):       # next top-level key
        vol_end = j
        break

vol_block = [
    "        - name: free5gc-certs\n",
    "          secret:\n",
    "            secretName: free5gc-certs\n",
]
lines[vol_end:vol_end] = vol_block

with open(path, "w") as f:
    f.writelines(lines)

print("patched {}".format(path))
PYEOF

done

echo ""
echo "=== Verification ==="
for nf in "${NFS[@]}"; do
  FILE="${nf}/deployment.yaml"
  [[ -f "$FILE" ]] || continue
  ns=$(grep -c "Release.Namespace" "$FILE")
  mnt=$(grep -c "mountPath: /free5gc/cert" "$FILE")
  vol=$(grep -c "name: free5gc-certs" "$FILE")
  vkeys=$(grep -c "^      volumes:" "$FILE")
  dep=$(grep -c "^kind: Deployment" "$FILE")
  echo "$nf: ns=$ns mount=$mnt vol=$vol volumes_keys=$vkeys deployments=$dep"
done

echo ""
echo "=== Helm render ==="
cd "$CHART"
helm template free5gc . --namespace free5gc > /tmp/render.yaml
echo "lines: $(wc -l < /tmp/render.yaml)"
echo "free5gc-certs refs: $(grep -c 'free5gc-certs' /tmp/render.yaml)"
echo "Deployment count: $(grep -c '^kind: Deployment' /tmp/render.yaml)"
