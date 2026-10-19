# OpenWrt x86_64 软路由固件

面向 **x86_64 软路由**的 OpenWrt 固件，通过 GitHub Actions 自动构建。预集成 **OpenClash**（内置最新 Mihomo 内核）与 7 个常用运维插件，默认简体中文界面。

固件已在 PVE 虚拟机上实测：启动正常、LAN 可达、全部插件页面可访问。

---

## 构建规格

| 项目 | 值 |
|---|---|
| 源码 | [openwrt/openwrt](https://github.com/openwrt/openwrt) `openwrt-24.10` 稳定分支（commit `58584c6`） |
| 内核 | Linux 6.6.157 |
| 目标 | x86 / 64（BIOS + UEFI 双启动） |
| 根分区 | **1024 MB**（原 256MB 装不下，实测 rootfs 约 303MB） |
| 软件包 | 260 个 |
| 代理插件 | [vernesong/OpenClash](https://github.com/vernesong/OpenClash) `0.47.156` + MetaCubeX/mihomo 最新 release |
| DNS | `dnsmasq-full`（含 nftset；不装 `dnsmasq` / `dnsmasq-dhcpv6`） |
| 语言 | LuCI 简体中文（`zh_Hans`） |

## 预装插件

| 插件 | 版本 | 功能 | 来源 |
|---|---|---|---|
| `luci-app-openclash` | 0.47.156 | 代理客户端，内置 Mihomo 核心 | vernesong/OpenClash |
| `frpc` + `luci-app-frpc` | 0.51.3 | FRP 内网穿透客户端 | 官方 packages feed |
| `netdata` + `luci-app-netdata` | 1.33.1 | 实时性能监控（端口 19999） | 官方 feed + ImmortalWrt LuCI |
| `luci-app-statistics` | 24.10 | collectd/rrdtool 流量与系统统计 | 官方 luci feed |
| `ttyd` + `luci-app-ttyd` | 1.7.3 | 网页终端（端口 7681） | 官方 feed |
| `luci-app-timecontrol` | 3.2.4 | 家长控制（上网时段限制，基于 nftables） | sirpdboy |
| `luci-app-autoreboot` | — | 定时重启 | ImmortalWrt LuCI |
| `openlist` + `luci-app-openlist` | 4.1.10 | 网盘聚合挂载 | 官方 packages feed |

> 本固件**不含** Nikki、PassWall 等其它代理插件。OpenClash 与它们功能重叠，同时启用会抢占相同的 nftables / DNS 规则。

### 内置 Mihomo 内核

核心已固化进固件，**首次启动无需联网下载内核**：

```
/etc/openclash/core/clash_meta   59.2 MB
Mihomo Meta v1.19.32 linux amd64 with go1.26.8
Use tags: with_gvisor
```

CI 构建时会自动查询 MetaCubeX/mihomo 的最新 release 并拉取对应 amd64 资产，因此每次构建都用当时的最新内核。

## 如何触发构建

- **手动**：Actions → `Build OpenWrt` → `Run workflow`
- **自动**：推送修改 `.config` / `feeds.conf.add` / 工作流文件到 `main`

构建约 1.5~3.5 小时，完成后自动创建 GitHub Release（标签 `build-<运行号>`），镜像可单独下载。

## 如何下载与刷写

进入仓库 **Releases** 页面，选择最新的 `build-*` 版本：

| 文件 | 大小（参考） | 用途 |
|---|---|---|
| `*-squashfs-combined-efi.img.gz` | ~97 MB | **UEFI 启动首选**，带只读恢复分区 |
| `*-squashfs-combined.img.gz` | ~97 MB | **传统 BIOS / Legacy 启动首选** |
| `*-ext4-combined-efi.img.gz` | ~116 MB | ext4 根文件系统，UEFI |
| `*-ext4-combined.img.gz` | ~116 MB | ext4 根文件系统，BIOS |
| `*-squashfs-rootfs.img.gz` | ~91 MB | 仅根文件系统 |
| `*-ext4-rootfs.img.gz` | ~110 MB | ext4 仅根文件系统 |
| `*-rootfs.tar.gz` | ~109 MB | Docker / LXC 导入 |
| `*.manifest` | — | 软件包清单 |
| `sha256sums` | — | 校验和 |

刷写方式：`dd`、balenaEtcher 或 Rufus。解压后的 raw 镜像可直接导入 PVE / ESXi / unRAID。校验：

```bash
sha256sum -c sha256sums
```

## 默认信息

| 项目 | 值 |
|---|---|
| 管理地址 | `http://192.168.1.1` |
| 用户名 / 密码 | `root` / 无（首次登录后请立即设置） |
| LuCI 端口 | 80（https 443 可选） |
| SSH 端口 | 22 |
| Netdata | `http://<路由器IP>:19999` |
| ttyd | `http://<路由器IP>:7681` |

> 若 LAN 网段与上游路由器冲突（例如上游本身就是 `192.168.1.1`），需在首次启动前或通过串口/显示器改掉。VM 测试时可预先修改镜像内 `/etc/config/network`。

## 首次使用建议

1. 登录 LuCI，进入 **系统 → 管理权** 设置 root 密码
2. 进入 **网络 → 接口** 确认 WAN 获取到地址
3. 进入 **服务 → OpenClash**，导入订阅或上传配置，选择内核后启动
4. 需要内网穿透时配置 **服务 → frpc**

## 如何修改配置

编辑 `.config`（Kconfig 文本格式）后推送到 `main`：

```
CONFIG_PACKAGE_luci-app-xxx=y
```

常用项：

| 修改 | 写法 |
|---|---|
| 移除 OpenClash | `# CONFIG_PACKAGE_luci-app-openclash is not set` |
| 调整根分区 | `CONFIG_TARGET_ROOTFS_PARTSIZE=2048` |
| 增加插件 | 官方 feed 内的包直接 `CONFIG_PACKAGE_xxx=y` |
| 第三方插件 | 需先在工作流中 clone 到 `openwrt/package/` |

> 当前 `build_dir` 实测占用约 16 GB，构建机需预留 25 GB 以上磁盘。

## 本地复现

```bash
cat feeds.conf.add openwrt/feeds.conf.default > openwrt/feeds.conf
cp .config openwrt/.config
cd openwrt
./scripts/feeds update -a && ./scripts/feeds install -a
make defconfig && make -j$(nproc)
```

第三方包（autoreboot / netdata / timecontrol）需手工放入 `openwrt/package/luci-extra/`，并把其中的

```make
include ../../luci.mk
```

改为

```make
include $(TOPDIR)/feeds/luci/luci.mk
```

否则会因相对路径失效而报错。完整脚本见 `build_local.sh`。

产物位于 `openwrt/bin/targets/x86/64/`。

## 仓库结构

```
.
├── .config                          # 构建配置（CI 与本地共用）
├── feeds.conf.add                   # 附加 feed 配置
├── build_local.sh                   # 本地一键构建脚本
├── 特点说明.md                       # 固件特性说明
├── .github/workflows/
│   └── build-openwrt.yml            # CI 工作流
└── openwrt/                         # 本地源码树（已 gitignore，不入库）
```

## 免责声明

固件仅供学习研究，请遵守当地法律法规；刷机有风险，操作需谨慎。
