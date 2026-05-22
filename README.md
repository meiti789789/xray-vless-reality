# xray-vless-reality (定制版)
Xray, VLESS_Reality模式 极简一键脚本 + Telegram 全自动服务器管理台

基于 crazypeace (https://github.com/crazypeace/xray-vless-reality) 的极简脚本深度定制，保留了原版轻量，并大幅增强了实用功能和交互体验。

---

## 核心定制与增强功能

**无感流量统计 & TG 控制台**
- **自动注入 API 与 Stats**：自动配置 config.json，在本地 10085 端口安全开启 Xray 流量统计，客户端自动标记为 "email": "user@reality"。
- **内置 Telegram 机器人**：安装时可选配置 TG Bot。部署后自动注册为守护进程（Systemd），随时随地在聊天界面管理服务器。
- **精准定时重置**：自动植入 Linux 定时任务（Cron），每月 18 号凌晨自动清零周期流量（如需修改，自行修改install.sh里面的Cron），TG 面板同步显示下次重置日期。
- **完美兼容 Debian 12**：采用 apt-get install python3-requests 替代 pip，完美绕过 PEP 668 环境限制，确保 100% 安装顺畅。
- **前置交互优化**：将所有提问（端口设置、TG 参数、WARP 安装）全部提前，告别守在电脑前等下一步，真正实现一次回车，后台搞定。
- **随机端口策略**：默认不再采用单一的 443 端口，改为每次随机生成高位端口，进一步降低特征风险（也可手动指定 443）。

---

## Telegram 机器人面板说明

配置成功后，向你的机器人发送 /start 或 /menu 即可呼出底部快捷菜单键盘：

- **网络用量** —— 实时查询 Xray 当前周期的下载/上传流量及总计（点击只统计不重置，系统会在每月18号自动重置）。
- **系统状态** —— 实时获取服务器的运行时长、内存使用率和 CPU 负载。
- **重启 Xray** —— 远程一键执行 systemctl restart xray，快速排查节点卡顿。
- **重启 VPS** —— 远程向服务器发送 reboot 指令，安全方便，无需登录 SSH。

---

## 一键安装 / 卸载命令

本脚本已将安装与彻底卸载集成在一个主菜单中，复制以下命令并在 SSH 终端运行即可：

```bash
apt update && apt install -y curl && bash <(curl -L [https://raw.githubusercontent.com/meiti789789/xray-vless-reality/main/install.sh](https://raw.githubusercontent.com/meiti789789/xray-vless-reality/main/install.sh))
```

卸载说明：重新运行上述命令，并在弹出的菜单中选择 2 (完全卸载)，脚本会自动将 Xray 主程序、配置文件、TG 机器人服务、Python 脚本以及 Cron 定时任务彻底清理干净，不留痕迹。

具体手搓步骤 (原理解析)
脚本中很大部分都是在校验用户的输入。如果你不放心开源脚本，完全可以照着下面的步骤自己配置。

1.打开 BBR
```bash
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control = bbr" >>/etc/sysctl.conf
echo "net.core.default_qdisc = fq" >>/etc/sysctl.conf
sysctl -p >/dev/null 2>&1
```
2. 安装 Xray
```bash
bash -c "$(curl -L [https://github.com/XTLS/Xray-install/raw/main/install-release.sh](https://github.com/XTLS/Xray-install/raw/main/install-release.sh))" @ install
```
3. 生成 x25519 公钥和私钥
```bash
xray x25519
```
4. 生成 UUID
```bash
xray uuid
```
5. 选一个你喜欢的伪装网站 (SNI)
比如：learn.microsoft.com

6. 配置 /usr/local/etc/xray/config.json
这是包含了流量统计模块的完整配置：
```bash
JSON
{ // VLESS + Reality + Stats
  "log": {
    "loglevel": "warning"
  },
  "api": {
    "services": ["StatsService"],
    "tag": "api"
  },
  "stats": {},
  "policy": {
    "levels": {
      "0": {
        "statsUserUplink": true,
        "statsUserDownlink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true
    }
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
    },
    {
      "listen": "0.0.0.0",
      "port": 443,    // 你可以修改为你随机生成的端口
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "你的UUID",    // ***改这里***
            "flow": "xtls-rprx-vision",
            "email": "user@reality"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "你喜欢的网站:443",    // ***如 learn.microsoft.com:443
          "xver": 0,
          "serverNames": ["你喜欢的网站"],    // ***如 learn.microsoft.com
          "privateKey": "你的私钥",    // ***改这里***
          "shortIds": [""]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "inboundTag": ["api"],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "block"
      }
    ]
  }
}
```
客户端参数配置
脚本最后会输出 VLESS 链接，方便你直接导入翻墙客户端。
如果你是手搓自建，请特别注意的是：客户端用的是公钥 (Public Key)，和服务端用的私钥 (Private Key) 不一样！

如果你要手动拼接 VLESS 链接，格式如下：
vless://${xray_id}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${domain}&fp=${fingerprint}&pbk=${public_key}&type=tcp#VLESS_R_${ip}

脚本支持带参数静默运行
支持跳过交互界面，直接通过环境变量或参数传参安装。

Bash
bash <(curl -L [https://raw.githubusercontent.com/meiti789789/xray-vless-reality/main/install.sh](https://raw.githubusercontent.com/meiti789789/xray-vless-reality/main/install.sh)) <netstack> [port] [domain] [UUID]
netstack： 6 表示 IPv6 入站；4 表示 IPv4 入站。

port： 端口 (不写的话, 自动生成随机高位端口)

domain： 伪装域名 (不写的话, 默认 learn.microsoft.com)

UUID： 你的 UUID (不写的话, 根据设备指纹自动生成固定 UUID)


## 鸣谢
核心代码逻辑归功于原作者 crazypeace。对于喜欢 V2rayN PAC 模式的朋友，欢迎使用原作者支持 Reality 的 v2rayN-3.29-VLESS (https://github.com/crazypeace/v2rayN-3.29-VLESS)。

欢迎对本仓库点亮 STAR！
