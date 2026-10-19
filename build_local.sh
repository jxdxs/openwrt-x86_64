#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "Starting OpenWrt Local Build"
echo "Time: $(date)"
echo "=========================================="

cd /home/yun/openwrt/openwrt

echo "=== Step 1: Installing feeds ==="
./scripts/feeds install -a

echo "=== Step 2: Fixing GOTOOLCHAIN ==="
if [ -f feeds/packages/lang/golang/golang-package.mk ]; then
  sed -i 's/GOTOOLCHAIN=local/GOTOOLCHAIN=auto/' feeds/packages/lang/golang/golang-package.mk
  grep 'GOTOOLCHAIN' feeds/packages/lang/golang/golang-package.mk || true
fi

echo "=== Step 3: Round 1 make defconfig ==="
make defconfig

echo "=== Step 4: Patching metadata for LuCI / Passwall depends ==="
if [ -f tmp/.config-package.in ]; then
  awk '
    /^[ \t]*config PACKAGE_luci$/ || /^[ \t]*menuconfig PACKAGE_luci$/ || /^[ \t]*config PACKAGE_luci-app-passwall$/ || /^[ \t]*menuconfig PACKAGE_luci-app-passwall$/ { blk=1 }
    blk && /^[ \t]*depends on/ { next }
    blk && /^[ \t]*help/ { blk=0 }
    { print }
  ' tmp/.config-package.in > tmp/.cfg.new
  mv tmp/.cfg.new tmp/.config-package.in
fi

echo "=== Step 5: Forcing requested config symbols ==="
force_y() {
  local s="$1"
  if grep -q "^$s=y$" .config; then echo "already $s"
  elif grep -q "^# $s is not set$" .config; then sed -i "s|^# $s is not set$|$s=y|" .config; echo "forced $s"
  else echo "$s=y" >> .config; echo "appended $s"; fi
}
force_n() {
  local s="$1"
  if grep -q "^# $s is not set$" .config; then echo "already disabled $s"
  elif grep -q "^$s=y$" .config; then sed -i "s|^$s=y$|# $s is not set|" .config; echo "forced disabled $s"
  else echo "# $s is not set" >> .config; echo "appended disable $s"; fi
}
force_y CONFIG_PACKAGE_luci
force_y CONFIG_LUCI_LANG_zh_Hans
force_y CONFIG_PACKAGE_luci-app-openclash
force_n CONFIG_RUBY_ENABLE_YJIT

echo "=== Step 6: Round 2 make defconfig ==="
make defconfig

echo "=== Step 7: Verifying key config symbols ==="
fail=0
check_y() { grep -qE "^$1=y" .config && echo "OK  $1=y" || { echo "MISSING $1"; fail=1; }; }
check_n() { grep -qE "^# $1 is not set" .config && echo "OK  $1 disabled" || { echo "MISSING $1 disabled"; fail=1; }; }
check_y CONFIG_TARGET_x86
check_y CONFIG_TARGET_x86_64
grep -qE "^CONFIG_TARGET_ROOTFS_PARTSIZE=256" .config && echo "OK  ROOTFS_PARTSIZE=256" || echo "WARN ROOTFS_PARTSIZE not 256 (kept default)"
check_y CONFIG_PACKAGE_luci
check_y CONFIG_PACKAGE_luci-app-openclash
check_y CONFIG_LUCI_LANG_zh_Hans
check_y CONFIG_PACKAGE_dnsmasq-full
check_n CONFIG_PACKAGE_dnsmasq
check_n CONFIG_PACKAGE_dnsmasq-dhcpv6
check_n CONFIG_RUBY_ENABLE_YJIT
if grep -qE '^CONFIG_PACKAGE_luci-app-passwall=y' .config; then echo "MISSING passwall should be absent"; fail=1; else echo "OK  passwall absent"; fi
if [ "$fail" -ne 0 ]; then
  echo "Configuration verification failed!"
  exit 1
fi
echo "Configuration verified successfully!"

echo "=== Step 8: Pre-downloading package sources (make download) ==="
make download -j8 || true

echo "=== Step 9: Compiling OpenWrt firmware ==="
NPROC=$(nproc)
echo "Using $NPROC parallel threads..."
if ! make -j"$NPROC"; then
  echo "Parallel build failed, retrying with verbose single thread for diagnostic..."
  make -j1 V=s
  exit 1
fi

echo "=== Step 10: Build verification ==="
CORE_HIT=$(find build_dir -name 'clash_meta' -type f 2>/dev/null | head -1)
echo "clash_meta found at: ${CORE_HIT:-<not found>}"
if [ -z "$CORE_HIT" ]; then
  echo "WARNING: clash_meta core not found in build_dir"
fi

echo "=== Build Completed Successfully! ==="
echo "Firmware files:"
ls -lh bin/targets/x86/64/
