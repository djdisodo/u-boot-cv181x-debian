#!/usr/bin/env bash
set -euo pipefail

source_dir=""
output=""

while (($#)); do
	case "$1" in
		--source-dir)
			source_dir="$2"
			shift 2
			;;
		--output)
			output="$2"
			shift 2
			;;
		*)
			echo "unknown argument: $1" >&2
			exit 1
			;;
	esac
done

if [[ -z "$source_dir" || -z "$output" ]]; then
	echo "usage: $0 --source-dir DIR --output FILE" >&2
	exit 1
fi

tmp_dts="${output}.tmp.dts"
board_dir="$source_dir/debian/board"
kernel_dir="$board_dir/kernel-upstream"
dts_dir="$kernel_dir/arch/riscv/boot/dts/sophgo"
include_dir="$kernel_dir/include"

mkdir -p "$(dirname "$output")"

cpp -x assembler-with-cpp -undef -nostdinc -D__DTS__ \
	-I"$board_dir" \
	-I"$dts_dir" \
	-I"$include_dir" \
	"$board_dir/sg2002-milkv-duo256m-opensbi.dts" > "$tmp_dts"

dtc -I dts -O dtb -o "$output" "$tmp_dts"
rm -f "$tmp_dts"
