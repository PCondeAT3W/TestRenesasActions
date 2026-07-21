


#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
    echo "Uso: $0 --version \"1.0.0.0\" --build R|D [--objcopy /ruta/arm-none-eabi-objcopy]"
    exit 1
}

fail() {
    echo "Error: $*" >&2
    exit 1
}

# Permite sobrescribir la herramienta, por ejemplo:
# SREC_CAT=/opt/srecord/bin/srec_cat ./crc.sh ...
SREC="${SREC_CAT:-srec_cat}"
OBJCOPY=""

[[ $# -ge 4 ]] || usage
[[ "${1,,}" == "--version" ]] || usage
[[ -n "$2" ]] || usage
[[ "${3,,}" == "--build" ]] || usage
[[ -n "$4" ]] || usage

VERSION="$2"

case "${4^^}" in
    R) BUILD="Release" ;;
    D) BUILD="Debug" ;;
    *) usage ;;
esac

shift 4

if [[ $# -gt 0 ]]; then
    [[ $# -eq 2 ]] || usage
    [[ "${1,,}" == "--objcopy" ]] || usage
    [[ -n "$2" ]] || usage
    OBJCOPY="$2"
fi

VERSION_NUM="${VERSION//./}"

fw_path="build/RA6T2-${BUILD}/ra6t2_build"
in_file="${fw_path}/RA6T2.hex"
in_elf="${fw_path}/RA6T2.elf"
out_path="${fw_path}/FW"
bin_file="${out_path}/Corrv${VERSION_NUM}.bin"
out_file="${out_path}/Corrv${VERSION_NUM}.hex"
out_elf="${out_path}/RA6T2.crc.elf"
tmp_hex="${out_path}/tmp_base.hex"
tmp_meta="${out_path}/tmp_meta.bin"

mkdir -p "$out_path"

cleanup() {
    rm -f -- "$tmp_hex" "$tmp_meta"
}
trap cleanup EXIT

if [[ "$SREC" == */* ]]; then
    [[ -x "$SREC" ]] || fail "srec_cat no encontrado o no ejecutable en \"$SREC\""
else
    command -v "$SREC" >/dev/null 2>&1 ||
        fail "srec_cat no encontrado en PATH"
fi

command -v python3 >/dev/null 2>&1 ||
    fail "python3 no encontrado en PATH"

[[ -f "$in_file" ]] || fail "No existe \"$in_file\""
[[ -f "$in_elf" ]] || fail "No existe \"$in_elf\""

if [[ -n "$OBJCOPY" ]]; then
    if [[ "$OBJCOPY" == */* ]]; then
        [[ -x "$OBJCOPY" ]] ||
            fail "objcopy no encontrado o no ejecutable en \"$OBJCOPY\""
    else
        command -v "$OBJCOPY" >/dev/null 2>&1 ||
            fail "objcopy no encontrado en PATH: \"$OBJCOPY\""
    fi
fi

# ============================================================
# Imagen absoluta:
# 0xE000..0xE003 = CRC provisional
# 0xE004..0xE007 = ultima direccion: 0x0003FFFF
# 0xE008..0x3FFFF = metadata restante + firmware
# ============================================================

"$SREC" -disable-sequence-warning \
    "(" "$in_file" -intel -fill 0xFF 0x00000 0x40000 \
        -crop 0x0E008 0x40000 ")" \
    -generate 0x0E000 0x0E004 -constant-l-e 0x00000000 4 \
    -generate 0x0E004 0x0E008 -constant-l-e 0x0003FFFF 4 \
    -output "$tmp_hex" -intel

# Convertir a BIN. El offset se aplica despues de generar
# correctamente la imagen absoluta.
"$SREC" "$tmp_hex" -intel \
    -crop 0x0E000 0x40000 \
    -offset -0x0E000 \
    -output "$bin_file" -binary

# Calcular el CRC igual que el bootloader:
# crc inicial = 0xFFFFFFFF
# rango       = bin[0x0004..final]
# metadata    = ~crc, little-endian en bin[0x0000..0x0003]
python3 - "$bin_file" "$tmp_meta" <<'PY'
from pathlib import Path
import sys

bin_path = Path(sys.argv[1])
meta_path = Path(sys.argv[2])

data = bytearray(bin_path.read_bytes())

expected_size = 0x32000
if len(data) != expected_size:
    raise SystemExit(
        f"Tamano BIN incorrecto: 0x{len(data):X}; "
        f"esperado: 0x{expected_size:X}"
    )

last_address = int.from_bytes(data[4:8], byteorder="little")
if last_address != 0x3FFFF:
    raise SystemExit(
        f"Campo 0xE004 incorrecto: 0x{last_address:08X}"
    )

crc = 0xFFFFFFFF
polynomial = 0xEDB88320

for value in data[4:]:
    crc ^= value
    for _ in range(8):
        if crc & 1:
            crc = (crc >> 1) ^ polynomial
        else:
            crc >>= 1
        crc &= 0xFFFFFFFF

crc_final = (~crc) & 0xFFFFFFFF
data[0:4] = crc_final.to_bytes(4, byteorder="little")

bin_path.write_bytes(data)
meta_path.write_bytes(data[:512])

print(f"CRC interno = 0x{crc:08X}")
print(f"CRC final   = 0x{crc_final:08X} / {crc_final}")
PY

# Regenerar el HEX final desde el BIN parcheado.
"$SREC" "$bin_file" -binary \
    -offset 0x0E000 \
    -output "$out_file" -intel

if [[ -n "$OBJCOPY" ]]; then
    "$OBJCOPY" \
        --update-section ".META_DATA=${tmp_meta}" \
        "$in_elf" \
        "$out_elf"
fi

echo "OK"
echo "HEX: \"$out_file\""
echo "BIN: \"$bin_file\""

if [[ -n "$OBJCOPY" ]]; then
    echo "ELF: \"$out_elf\""
fi