# OpenWrt x86_64 固件自动构建

通过 GitHub Actions 自动编译的 OpenWrt 固件，面向 **x86_64 软路由**，预集成 **OpenClash**（含最新 Mihomo 内核）与常用运维插件，默认简体中文界面。

## 构建规格

| 项目 | 值 |
|---|---|
| 源码 | [openwrt/openwrt](https://github.com/openwrt/openwrt) `openwrt-24.10` 稳定分支 |
| 目标 | x86 / 64（BIOS + UEFI 双启动镜像） |
| 根分区 | 1024 MB |
| 代理插件 | [vernesong/OpenClash](https://github.com/vernesong/OpenClash) + MetaCubeX/mihomo 最新内核（构建时自动拉取） |
| DNS | dnsmasq-full（含 nftset，不装 dnsmasq / dnsmasq-dhcpv6） |

## 预装插件

| 插件 | 说明 | 来源 |
|---|---|---|
| luci-app-openclash | 代理客户端，内置 Mihomo 核心（`/etc/openclash/core/clash_meta`） | vernesong/OpenClash |
| frpc | FRP 内网穿透客户端 | 官方 packages feed |
| netdata + luci-app-netdata | 实时性能监控 | 官方 feed + ImmortalWrt LuCI |
| luci-app-statistics | 基于 collectd/rrdtool 的流量与系统统计 | 官方 luci feed |
| ttyd + luci-app-ttyd | 网页终端 | 官方 feed |
| luci-app-timecontrol | 家长控制（上网时段限制，基于 nftables） | sirpdboy |
| luci-app-autoreboot | 定时重启 | ImmortalWrt LuCI |
| openlist + luci-app-openlist | 网盘聚合挂载 | 官方 packages feed |

> 注：本固件**不包含** Nikki、PassWall 等其它代理插件。

## 如何触发构建

- **手动**：Actions → `Build OpenWrt` → `Run workflow`
- **自动**：推送修改 `.config`、`feeds.conf.add` 或工作流文件到 `main` 分支

构建耗时约 1.5~3.5 小时，完成后自动创建 GitHub Release（标签 `build-<运行号>`），每个镜像文件可单独下载。

## 如何下载固件

进入仓库 **Releases** 页面，选择最新的 `build-*` 版本，下载所需镜像：

| 文件 | 用途 |
|---|---|
| `*-squashfs-combined-efi.img.gz` | **UEFI 启动首选** |
| `*-squashfs-combined.img.gz` | **传统 BIOS / Legacy 启动首选** |
| `*-ext4-combined-efi.img.gz` / `*-ext4-combined.img.gz` | ext4 根文件系统版本 |
| `*-rootfs.tar.gz` | Docker / LXC 导入 |
| `*.manifest` / `sha256sums` | 软件包清单与校验 |

写入方式：`dd`、balenaEtcher 或 Rufus。

## 默认信息

- 管理地址：`http://192.168.1.1`
- 用户名 `root`，默认无密码（首次登录后请设置）
- SSH 端口 22，LuCI 端口 80

## 如何修改配置

编辑 `.config`（Kconfig 文本格式）后推送到 `main`：

```
CONFIG_PACKAGE_luci-app-xxx=y
```

常用项：

- `# CONFIG_PACKAGE_luci-app-openclash is not set` —— 移除 OpenClash
- `CONFIG_TARGET_ROOTFS_PARTSIZE=2048` —— 调整根分区大小

## 本地复现

```bash
cat feeds.conf.add openwrt/feeds.conf.default > openwrt/feeds.conf
cp .config openwrt/.config
cd openwrt
./scripts/feeds update -a && ./scripts/feeds install -a
make defconfig && make -j$(nproc)
```

产物位于 `openwrt/bin/targets/x86/64/`。

## 免责声明

固件仅供学习研究，请遵守当地法律法规；刷机有风险，操作需谨慎。
