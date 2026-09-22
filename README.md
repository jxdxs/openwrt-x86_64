# OpenWrt x86_64 固件自动构建

通过 GitHub Actions 自动编译的 OpenWrt 固件，面向 **x86_64 软路由**，预集成 **PassWall** 与 **OpenClash** 代理插件（含中文界面）。

## 构建规格

| 项目 | 值 |
|---|---|
| 源码 | [openwrt/openwrt](https://github.com/openwrt/openwrt) `openwrt-24.10` 稳定分支 |
| 目标 | x86 / 64（BIOS + UEFI 双启动镜像） |
| 根分区 | 256 MB |
| 插件源 | [Openwrt-Passwall/openwrt-passwall(-packages)](https://github.com/Openwrt-Passwall)（官方最新）+ [vernesong/OpenClash](https://github.com/vernesong/OpenClash) |
| 预装 | luci-app-passwall、luci-app-openclash、dnsmasq-full、中文语言包 |

## 如何触发构建

- **手动**：Actions → `Build OpenWrt` → `Run workflow`
- **自动**：推送修改 `.config`、`feeds.conf.add` 或本工作流文件到 `main` 分支

## 如何下载固件

构建完成后（约 1.5~3.5 小时）：

1. 进入该仓库的 **Actions** 标签 → 点开最新一次运行
2. 底部 **Artifacts** → 下载 `firmware-x86_64`（需登录 GitHub 账号）
3. 解压得到 `bin/targets/x86/64/` 下的镜像，常用：
   - `*-generic-squashfs-combined.img.gz` —— BIOS 启动，整盘写入（`dd` / balenaEtcher / Rufus）
   - `*-generic-squashfs-combined-efi.img.gz` —— UEFI 启动设备用这个
   - `*-manifest` / `sha256sums` —— 软件包清单与校验

## 如何修改配置

编辑根目录 `.config`（Kconfig 文本格式），例如添加插件：

```
CONFIG_PACKAGE_luci-app-xxx=y
```

推送到 `main` 即可重新构建。常用符号：

- `CONFIG_PACKAGE_luci-app-passwall2=y` —— PassWall2（需在 `feeds.conf.add` 加 passwall2 源，见上游 README）
- `# CONFIG_PACKAGE_luci-app-openclash is not set` —— 移除 OpenClash

> 注意：新增插件若来自第三方仓库，需先在 `feeds.conf.add` 中添加对应 `src-git` 行。

## 本地复现（可选）

```bash
cat feeds.conf.add openwrt/feeds.conf.default > openwrt/feeds.conf
cp .config openwrt/
cd openwrt
./scripts/feeds update -a && ./scripts/feeds install -a
git clone --depth 1 -b master https://github.com/vernesong/OpenClash.git package/OpenClash
make defconfig && make -j$(nproc)
```

## 免责声明

固件仅供学习研究，请遵守当地法律法规；刷机有风险，操作需谨慎。
