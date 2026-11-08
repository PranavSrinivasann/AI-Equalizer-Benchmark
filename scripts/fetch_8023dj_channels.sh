#!/usr/bin/env bash
# Download the public 200G/lane channel S-parameters used in Phase 3 and
# extract the thru and crosstalk files for the three loss levels into
# data/8023dj/<level>/.  Re-running skips files already present.
set -euo pipefail
cd "$(dirname "$0")/.."
BASE=https://www.ieee802.org/3/dj/public/tools
OUT=data/8023dj
CACHE=$OUT/.zips
mkdir -p "$CACHE"

fetch() {  # level zip-url inner-folder file-prefix
  local level=$1 url=$2 inner=$3 prefix=$4 zip
  zip=$CACHE/$(basename "$url")
  [ -s "$zip" ] || curl -fsSL -o "$zip" "$url"
  mkdir -p "$OUT/$level"
  unzip -oj -q "$zip" "$inner/${prefix}_thru1.s4p" "$inner/${prefix}_xtalk*.s4p" -d "$OUT/$level"
}

# ~20 dB: KR backplane, 100 mm
fetch loss20 $BASE/KR/akinwale_3dj_01_2310.zip akinwale_3dj_01_2310 \
  Tx_NPC_250mm_32AWG_BPK_100mm_27AWG_BPK_250mm_32AWG_NPC_Rx
# ~30 dB: KR backplane, 1200 mm
fetch loss30 $BASE/KR/akinwale_3dj_01_2310.zip akinwale_3dj_01_2310 \
  Tx_NPC_250mm_32AWG_BPK_1200mm_27AWG_BPK_250mm_32AWG_NPC_Rx
# ~40 dB stress: cabled OSFP channel, 27 dB cable (module vendor Y), plus package
fetch loss40 $BASE/CR/akinwale_3dj_02_2311.zip akinwale_3dj_01_2311 \
  Tx_PCB_4dB_OSFP_27dB_OSFP_4dB_PCB_Rx_TP0_TP5_VendorY
echo done; ls -R "$OUT" | head -40
