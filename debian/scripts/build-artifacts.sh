#!/usr/bin/env bash
set -euo pipefail

source_dir=""
build_dir=""
cross_compile=""
board_name=""
board_defconfig=""
install_dir=""
opensbi_platform=""
target_arch=""
package_name=""
package_version=""
package_release=""
u_boot_version=""
opensbi_version=""
kernel_dts_source_url=""
kernel_dts_source_rev=""

while (($#)); do
	case "$1" in
		--source-dir)
			source_dir="$2"
			shift 2
			;;
		--build-dir)
			build_dir="$2"
			shift 2
			;;
		--cross-compile)
			cross_compile="$2"
			shift 2
			;;
		--board-name)
			board_name="$2"
			shift 2
			;;
		--board-defconfig)
			board_defconfig="$2"
			shift 2
			;;
		--install-dir)
			install_dir="$2"
			shift 2
			;;
		--opensbi-platform)
			opensbi_platform="$2"
			shift 2
			;;
		--target-arch)
			target_arch="$2"
			shift 2
			;;
		--package-name)
			package_name="$2"
			shift 2
			;;
		--package-version)
			package_version="$2"
			shift 2
			;;
		--package-release)
			package_release="$2"
			shift 2
			;;
		--u-boot-version)
			u_boot_version="$2"
			shift 2
			;;
		--opensbi-version)
			opensbi_version="$2"
			shift 2
			;;
		--kernel-dts-source-url)
			kernel_dts_source_url="$2"
			shift 2
			;;
		--kernel-dts-source-rev)
			kernel_dts_source_rev="$2"
			shift 2
			;;
		*)
			echo "unknown argument: $1" >&2
			exit 1
			;;
	esac
done

if [[ -z "$source_dir" || -z "$build_dir" || -z "$cross_compile" || -z "$board_name" || -z "$board_defconfig" || -z "$install_dir" || -z "$opensbi_platform" || -z "$target_arch" || -z "$package_name" || -z "$package_version" || -z "$package_release" || -z "$u_boot_version" || -z "$opensbi_version" || -z "$kernel_dts_source_url" || -z "$kernel_dts_source_rev" ]]; then
	echo "missing required arguments" >&2
	exit 1
fi

jobs="${JOBS:-$(nproc)}"
uboot_build="$build_dir/u-boot"
opensbi_build="$build_dir/opensbi"
work_out="$build_dir/out/$board_name"
opensbi_dtb="$build_dir/${board_name}-opensbi.dtb"

rm -rf "$build_dir"
mkdir -p "$uboot_build" "$opensbi_build" "$work_out"

"$source_dir/debian/scripts/compile-opensbi-dtb.sh" \
	--source-dir "$source_dir" \
	--output "$opensbi_dtb"

make -C "$source_dir/opensbi" \
	O="$opensbi_build" \
	PLATFORM="$opensbi_platform" \
	CROSS_COMPILE="$cross_compile" \
	FW_FDT_PATH="$opensbi_dtb" \
	-j"$jobs"

opensbi_bin="$opensbi_build/platform/$opensbi_platform/firmware/fw_dynamic.bin"

make -C "$source_dir" \
	O="$uboot_build" \
	ARCH=riscv \
	CROSS_COMPILE="$cross_compile" \
	"$board_defconfig"

"$source_dir/scripts/config" --file "$uboot_build/.config" \
	-d EFI_LOADER \
	-d CMD_BOOTEFI_HELLO_COMPILE \
	-d CMD_BOOTEFI_SELFTEST \
	-d POSITION_INDEPENDENT

make -C "$source_dir" \
	O="$uboot_build" \
	ARCH=riscv \
	CROSS_COMPILE="$cross_compile" \
	olddefconfig

make -C "$source_dir" \
	O="$uboot_build" \
	ARCH=riscv \
	CROSS_COMPILE="$cross_compile" \
	-j"$jobs"

python3 "$source_dir/debian/tools/fiptool" \
	--fsbl "$source_dir/debian/assets/cv181x.bin" \
	--ddr_param "$source_dir/debian/assets/ddr_param.bin" \
	--opensbi "$opensbi_bin" \
	--uboot "$uboot_build/u-boot.bin" \
	--rtos "$source_dir/debian/assets/cvirtos.bin" \
	"$work_out/fip.bin"

install -m0644 "$uboot_build/u-boot.bin" "$work_out/u-boot.bin"
install -m0644 "$opensbi_bin" "$work_out/fw_dynamic.bin"
install -m0644 "$opensbi_dtb" "$work_out/${board_name}-opensbi.dtb"

cat > "$work_out/build.env" <<EOF
PACKAGE_NAME=$package_name
PACKAGE_VERSION=$package_version
PACKAGE_RELEASE=$package_release
BOARD_NAME=$board_name
BOARD_DEFCONFIG=$board_defconfig
INSTALL_DIR=$install_dir
FIP_INSTALL_PATH=/boot/fip.bin
U_BOOT_URL=https://github.com/u-boot/u-boot.git
U_BOOT_REF=v$u_boot_version
OPENSBI_URL=https://github.com/riscv-software-src/opensbi.git
OPENSBI_REF=v$opensbi_version
KERNEL_DTS_SOURCE_URL=$kernel_dts_source_url
KERNEL_DTS_SOURCE_REV=$kernel_dts_source_rev
CROSS_COMPILE=$cross_compile
TARGET_ARCH=$target_arch
OPENSBI_PLATFORM=$opensbi_platform
EOF
