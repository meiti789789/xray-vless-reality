#!/bin/bash

# 等待1秒, 避免curl下载脚本的打印与脚本本身的显示冲突, 吃掉了提示用户按回车继续的信息
sleep 1

echo -e "                    _ ___                    \n ___ ___ __ __ ___ _| |  _|___ __ __   _ ___ \n|-_ |_  |  |  |-_ | _ |   |- _|  |  |_| |_  |\n|___|___|  _  |___|___|_|_|___|  _  |___|___|\n        |_____|               |_____|        "
red='\e[91m'
green='\e[92m'
yellow='\e[93m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'

error() {
    echo -e "\n$red 输入错误! $none\n"
}

warn() {
    echo -e "\n$yellow $1 $none\n"
}

pause() {
    read -rsp "$(echo -e "按 $green Enter 回车键 $none 继续....或按 $red Ctrl + C $none 取消.")" -d $'\n'
    echo
}

# 确保有 curl 和 wget
apt-get -y install curl wget -qq

# 说明
echo
echo -e "$yellow此脚本仅兼容于Debian 10+系统. 如果你的系统不符合,请Ctrl+C退出脚本$none"
echo -e "可以去 ${cyan}https://github.com/crazypeace/xray-vless-reality${none} 查看脚本整体思路和关键命令, 以便针对你自己的系统做出调整."
echo -e "有问题加群 ${cyan}https://t.me/+q5WPfGjtwukyZjhl${none}"
echo -e "本脚本支持带参数执行, 省略交互过程, 详见GitHub."
echo "----------------------------------------------------------------"

# 本机 IP
InFaces=($(ls /sys/class/net/ | grep -E '^(eth|ens|eno|esp|enp|venet|vif)'))

for i in "${InFaces[@]}"; do  # 从网口循环获取IP
    # 增加超时时间, 以免在某些网络环境下请求IPv6等待太久
    Public_IPv4=$(curl -4s --interface "$i" -m 2 https://www.cloudflare.com/cdn-cgi/trace | grep -oP "ip=\K.*$")
    Public_IPv6=$(curl -6s --interface "$i" -m 2 https://www.cloudflare.com/cdn-cgi/trace | grep -oP "ip=\K.*$")

    if [[ -n "$Public_IPv4" ]]; then  # 检查是否获取到IP地址
        IPv4="$Public_IPv4"
    fi
    if [[ -n "$Public_IPv6" ]]; then  # 检查是否获取到IP地址
        IPv6="$Public_IPv6"
    fi
done

# 通过IP, host, 时区, 生成UUID. 重装脚本不改变, 不改变节点信息, 方便个人使用
uuidSeed=${IPv4}${IPv6}$(cat /proc/sys/kernel/hostname)$(timedatectl | awk '/Time zone/ {print $3}')
default_uuid=$(curl -sL https://www.uuidtools.com/api/generate/v3/namespace/ns:dns/name/${uuidSeed} | grep -oP '[^-]{8}-[^-]{4}-[^-]{4}-[^-]{4}-[^-]{12}')

# 如果你想使用纯随机的UUID
# default_uuid=$(cat /proc/sys/kernel/random/uuid)

# ----------------------------------------------------------------
# 检测是否定义了任意一个环境变量
# 若定义了至少一个, 则忽略命令行参数, 完全以环境变量为准
# ----------------------------------------------------------------
_use_env_vars=0
if [[ -n "${_MYIP_}" || -n "${_MYPORT_}" || -n "${_MYDOMAIN_}" || -n "${_MYUUID_}" ]]; then
    _use_env_vars=1
fi

if [[ $_use_env_vars -eq 1 ]]; then
    # ---- 环境变量模式 ----
    echo -e "$cyan[环境变量模式] 检测到环境变量, 忽略命令行参数.$none"
    echo "----------------------------------------------------------------"

    # _MYIP_: 根据IP判断 netstack, 并设置 ip
    if [[ -n "${_MYIP_}" ]]; then
        ip="${_MYIP_}"
        # 简单判断是否含有 ":" 来区分 IPv6 / IPv4
        if [[ "${ip}" == *:* ]]; then
            netstack=6
        else
            netstack=4
        fi
    else
        # 未定义 _MYIP_, 沿用自动探测逻辑
        if [[ -n "$IPv4" ]]; then
            netstack=4
            ip=${IPv4}
        elif [[ -n "$IPv6" ]]; then
            netstack=6
            ip=${IPv6}
        else
            warn "没有获取到公共IP"
        fi
    fi

    # _MYPORT_: 端口, 默认 443
    if [[ -n "${_MYPORT_}" ]]; then
        port="${_MYPORT_}"
    else
        port=443
    fi

    # _MYDOMAIN_: 域名, 默认 learn.microsoft.com
    if [[ -n "${_MYDOMAIN_}" ]]; then
        domain="${_MYDOMAIN_}"
    else
        domain="learn.microsoft.com"
    fi

    # _MYUUID_: UUID, 默认使用种子生成的 UUID
    if [[ -n "${_MYUUID_}" ]]; then
        uuid="${_MYUUID_}"
    else
        uuid="${default_uuid}"
    fi

    echo -e "$yellow netstack  = ${cyan}${netstack}${none}"
    echo -e "$yellow 本机IP    = ${cyan}${ip}${none}"
    echo -e "$yellow 端口 (Port)= ${cyan}${port}${none}"
    echo -e "$yellow 用户ID (User ID / UUID) = $cyan${uuid}${none}"
    echo -e "$yellow SNI       = ${cyan}${domain}${none}"
    echo "----------------------------------------------------------------"

elif [ $# -ge 1 ]; then
    # ---- 命令行参数模式 ----
    # 第1个参数是搭在ipv4还是ipv6上
    case ${1} in
    4)
        netstack=4
        ip=${IPv4}
        ;;
    6)
        netstack=6
        ip=${IPv6}
        ;;
    *) # initial
        if [[ -n "$IPv4" ]]; then  # 检查是否获取到IP地址
            netstack=4
            ip=${IPv4}
        elif [[ -n "$IPv6" ]]; then  # 检查是否获取到IP地址
            netstack=6
            ip=${IPv6}
        else
            warn "没有获取到公共IP"
        fi
        ;;
    esac

    # 第2个参数是port
    port=${2}
    if [[ -z $port ]]; then
      port=443
    fi

    # 第3个参数是域名
    domain=${3}
    if [[ -z $domain ]]; then
      domain="learn.microsoft.com"
    fi

    # 第4个参数是UUID
    uuid=${4}
    if [[ -z $uuid ]]; then
        uuid=${default_uuid}
    fi

    echo -e "$yellow netstack = ${cyan}${netstack}${none}"
    echo -e "$yellow 本机IP = ${cyan}${ip}${none}"
    echo -e "$yellow 端口 (Port) = ${cyan}${port}${none}"
    echo -e "$yellow 用户ID (User ID / UUID) = $cyan${uuid}${none}"
    echo -e "$yellow SNI = ${cyan}${domain}${none}"
    echo "----------------------------------------------------------------"
fi

pause

# 准备工作
apt update
apt install -y curl wget sudo jq qrencode net-tools lsof cron

# Xray官方脚本 安装最新版本
echo
echo -e "${yellow}Xray官方脚本安装 v25.10.15 版本$none"
echo "----------------------------------------------------------------"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version v25.10.15

# 更新 geodata
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install-geodata

# 如果脚本带参数执行的, 要在安装了xray之后再生成默认私钥公钥shortID
if [[ -n $uuid ]]; then
  reality_key_seed=$(echo -n ${uuid} | md5sum | head -c 32 | base64 -w 0 | tr '+/' '-_' | tr -d '=')
  tmp_key=$(echo -n ${reality_key_seed} | xargs xray x25519 -i)
  private_key=$(echo ${tmp_key} | awk '{print $2}')
  public_key=$(echo ${tmp_key} | awk '{print $4}')
  shortid=$(echo -n ${uuid} | sha1sum | head -c 16)

  echo
  echo "私钥公钥要在安装xray之后才可以生成"
  echo -e "$yellow 私钥 (PrivateKey) = ${cyan}${private_key}${none}"
  echo -e "$yellow 公钥 (PublicKey) = ${cyan}${public_key}${none}"
  echo -e "$yellow ShortId = ${cyan}${shortid}${none}"
  echo "----------------------------------------------------------------"
fi

# 打开BBR
echo
echo -e "$yellow打开BBR$none"
echo "----------------------------------------------------------------"
sudo touch /etc/sysctl.d/99-bbr.conf
sudo sed -i '/^net\.core\.default_qdisc/d' /etc/sysctl.d/99-bbr.conf
sudo sed -i '/^net\.ipv4\.tcp_congestion_control/d' /etc/sysctl.d/99-bbr.conf
echo 'net.core.default_qdisc=fq' | sudo tee -a /etc/sysctl.d/99-bbr.conf
echo 'net.ipv4.tcp_congestion_control=bbr' | sudo tee -a /etc/sysctl.d/99-bbr.conf
echo 'tcp_bbr' | sudo tee /etc/modules-load.d/bbr.conf
sudo sysctl --system

# 配置 VLESS_Reality 模式
echo
echo -e "$yellow配置 VLESS_Reality 模式$none"
echo "----------------------------------------------------------------"

# 网络栈
if [[ -z $netstack ]]; then
  echo
  echo -e "如果你的小鸡是${magenta}双栈(同时有IPv4和IPv6的IP)${none}，请选择你把Xray搭在哪个'网口'上"
  echo "如果你不懂这段话是什么意思, 请直接回车"
  read -p "$(echo -e "Input ${cyan}4${none} for IPv4, ${cyan}6${none} for IPv6:") " netstack

  if [[ $netstack == "4" ]]; then
    ip=${IPv4}
  elif [[ $netstack == "6" ]]; then
    ip=${IPv6}
  else
    if [[ -n "$IPv4" ]]; then
      ip=${IPv4}
      netstack=4
    elif [[ -n "$IPv6" ]]; then
      ip=${IPv6}
      netstack=6
    else
      warn "没有获取到公共IP"
    fi
  fi
fi

# 端口
if [[ -z $port ]]; then
  default_port=443
  while :; do
    read -p "$(echo -e "请输入端口 [${magenta}1-65535${none}] Input port (默认Default ${cyan}${default_port}$none):")" port
    [ -z "$port" ] && port=$default_port
    case $port in
    [1-9] | [1-9][0-9] | [1-9][0-9][0-9] | [1-9][0-9][0-9][0-9] | [1-5][0-9][0-9][0-9][0-9] | 6[0-4][0-9][0-9][0-9] | 65[0-4][0-9][0-9] | 655[0-3][0-5])
      echo
      echo
      echo -e "$yellow 端口 (Port) = ${cyan}${port}${none}"
      echo "----------------------------------------------------------------"
      echo
      break
      ;;
    *)
      error
      ;;
    esac
  done
fi

# Xray UUID
if [[ -z $uuid ]]; then
  while :; do
    echo -e "请输入 "$yellow"UUID"$none" "
    read -p "$(echo -e "(默认ID: ${cyan}${default_uuid}$none):")" uuid
    [ -z "$uuid" ] && uuid=$default_uuid
    case $(echo -n $uuid | sed -E 's/[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}//g') in
    "")
        echo
        echo
        echo -e "$yellow UUID = $cyan$uuid$none"
        echo "----------------------------------------------------------------"
        echo
        break
        ;;
    *)
        error
        ;;
    esac
  done
fi

# x25519公私钥
if [[ -z $private_key ]]; then
  reality_key_seed=$(echo -n ${uuid} | md5sum | head -c 32 | base64 -w 0 | tr '+/' '-_' | tr -d '=')
  tmp_key=$(echo -n ${reality_key_seed} | xargs xray x25519 -i)
  default_private_key=$(echo ${tmp_key} | awk '{print $2}')
  default_public_key=$(echo ${tmp_key} | awk '{print $4}')

  echo -e "请输入 "$yellow"x25519 Private Key"$none" x25519私钥 :"
  read -p "$(echo -e "(默认私钥 Private Key: ${cyan}${default_private_key}$none):")" private_key
  if [[ -z "$private_key" ]]; then
    private_key=$default_private_key
    public_key=$default_public_key
  else
    tmp_key=$(echo -n ${private_key} | xargs xray x25519 -i)
    private_key=$(echo ${tmp_key} | awk '{print $2}')
    public_key=$(echo ${tmp_key} | awk '{print $4}')
  fi

  echo
  echo
  echo -e "$yellow 私钥 (PrivateKey) = ${cyan}${private_key}$none"
  echo -e "$yellow 公钥 (PublicKey) = ${cyan}${public_key}$none"
  echo "----------------------------------------------------------------"
  echo
fi

# ShortID
if [[ -z $shortid ]]; then
  default_shortid=$(echo -n ${uuid} | sha1sum | head -c 16)
  while :; do
    echo -e "请输入 "$yellow"ShortID"$none" :"
    read -p "$(echo -e "(默认ShortID: ${cyan}${default_shortid}$none):")" shortid
    [ -z "$shortid" ] && shortid=$default_shortid
    if [[ ${#shortid} -gt 16 ]]; then
      error
      continue
    elif [[ $(( ${#shortid} % 2 )) -ne 0 ]]; then
      error
      continue
    else
      echo
      echo
      echo -e "$yellow ShortID = ${cyan}${shortid}$none"
      echo "----------------------------------------------------------------"
      echo
      break
    fi
  done
fi

# 目标网站
if [[ -z $domain ]]; then
  echo -e "请输入一个 ${magenta}合适的域名${none} Input the domain"
  read -p "(例如: learn.microsoft.com): " domain
  [ -z "$domain" ] && domain="learn.microsoft.com"

  echo
  echo
  echo -e "$yellow SNI = ${cyan}$domain$none"
  echo "----------------------------------------------------------------"
  echo
fi

# ===========================
# 写入自带流量统计功能的 config.json
# ===========================
echo
echo -e "$yellow 配置 /usr/local/etc/xray/config.json $none"
echo "----------------------------------------------------------------"
cat > /usr/local/etc/xray/config.json <<-EOF
{ // VLESS + Reality
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
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
      "port": ${port},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
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
          "dest": "${domain}:443",
          "xver": 0,
          "serverNames": ["${domain}"],
          "privateKey": "${private_key}",
          "shortIds": ["${shortid}"]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
        "protocol": "freedom",
        "settings": {
            "domainStrategy": "UseIPv4"
        },
        "tag": "force-ipv4"
    },
    {
        "protocol": "freedom",
        "settings": {
            "domainStrategy": "UseIPv6"
        },
        "tag": "force-ipv6"
    },
    {
        "protocol": "socks",
        "settings": {
            "servers": [{
                "address": "127.0.0.1",
                "port": 40000
            }]
         },
        "tag": "socks5-warp"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "dns": {
    "servers": [
      "8.8.8.8",
      "1.1.1.1",
      "2001:4860:4860::8888",
      "2606:4700:4700::1111",
      "localhost"
    ]
  },
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
EOF

# 重启 Xray
echo
echo -e "$yellow重启 Xray$none"
echo "----------------------------------------------------------------"
service xray restart


# ==========================================
# 新增功能区：配置 Telegram 机器人和定时清空流量任务
# ==========================================
echo
echo -e "$yellow【可选功能】配置 Telegram 流量查询与控制机器人$none"
echo "----------------------------------------------------------------"
read -p "请输入你的 Telegram Bot Token (不需要机器人请直接回车跳过): " TG_TOKEN
if [[ -n "$TG_TOKEN" ]]; then
    read -p "请输入你的 Telegram Chat ID (防滥用, 必填纯数字): " TG_CHAT_ID
    if [[ -n "$TG_CHAT_ID" ]]; then
        echo -e "$green正在部署 Telegram 机器人并配置环境...$none"
        # 安装 python 和 requests 库 (兼容 Debian 12 强制环境)
        apt-get install -y python3 python3-requests

        # 生成 Python 脚本 (使用定界符，防止bash干扰里面的变量)
        cat > /root/tg_xray_bot.py <<-'EOF'
import subprocess
import requests
import time
import datetime

# --- 由脚本自动替换参数 ---
BOT_TOKEN = 'YOUR_BOT_TOKEN_HERE'
ALLOWED_CHAT_ID = YOUR_CHAT_ID_HERE

REPLY_KEYBOARD = {
    "keyboard": [
        [{"text": "📊 网络用量"}, {"text": "🖥️ 系统状态"}],
        [{"text": "🔄 重启 Xray"}, {"text": "🌀 重启 VPS"}]
    ],
    "resize_keyboard": True,
    "is_persistent": True
}

def execute_cmd(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.STDOUT).strip()
    except Exception as e:
        return f"获取失败"

def get_traffic():
    cmd_down = "/usr/local/bin/xray api statsquery --server=127.0.0.1:10085 -pattern 'user>>>user@reality>>>traffic>>>downlink' | grep 'value' | awk '{print $2}'"
    cmd_up = "/usr/local/bin/xray api statsquery --server=127.0.0.1:10085 -pattern 'user>>>user@reality>>>traffic>>>uplink' | grep 'value' | awk '{print $2}'"
    
    try:
        down_bytes = int(execute_cmd(cmd_down) or 0)
        up_bytes = int(execute_cmd(cmd_up) or 0)
    except:
        down_bytes = up_bytes = 0

    down_gb = down_bytes / (1024**3)
    up_gb = up_bytes / (1024**3)
    return round(down_gb, 2), round(up_gb, 2)

def get_next_reset_date():
    today = datetime.date.today()
    if today.day >= 18:
        if today.month == 12:
            next_reset = datetime.date(today.year + 1, 1, 18)
        else:
            next_reset = datetime.date(today.year, today.month + 1, 18)
    else:
        next_reset = datetime.date(today.year, today.month, 18)
    return next_reset.strftime("%Y-%m-%d")

def send_message(chat_id, text):
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    payload = {
        'chat_id': chat_id,
        'text': text,
        'parse_mode': 'Markdown',
        'reply_markup': REPLY_KEYBOARD
    }
    try:
        requests.post(url, json=payload, timeout=10)
    except Exception as e:
        pass

def main():
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/getUpdates"
    offset = None

    print("Bot is running...")
    while True:
        try:
            res = requests.get(url, params={'timeout': 100, 'offset': offset}, timeout=110)
            data = res.json()
            
            if data.get('ok'):
                for update in data['result']:
                    offset = update['update_id'] + 1
                    message = update.get('message', {})
                    text = message.get('text', '')
                    chat_id = message.get('chat', {}).get('id')

                    if chat_id != ALLOWED_CHAT_ID:
                        continue

                    if text in ['/start', '/menu']:
                        send_message(chat_id, "👋 欢迎使用服务器管理助手，请选择下方菜单操作：")

                    elif text == "📊 网络用量" or text == "/stats":
                        down, up = get_traffic()
                        total = round(down + up, 2)
                        next_date = get_next_reset_date()
                        reply_text = (
                            f"📊 **当前网络用量**\n"
                            f"📥 下载: {down} GB\n"
                            f"📤 上传: {up} GB\n"
                            f"🌐 总计: {total} GB\n\n"
                            f"🔄 下次重置: {next_date}"
                        )
                        send_message(chat_id, reply_text)

                    elif text == "🖥️ 系统状态":
                        uptime = execute_cmd("uptime -p | sed 's/up //'")
                        mem_usage = execute_cmd("free -m | awk 'NR==2{printf \"%.2f%%\", $3*100/$2 }'")
                        cpu_load = execute_cmd("top -bn1 | grep load | awk '{printf \"%.2f\", $(NF-2)}'")
                        reply_text = (
                            f"🖥️ **系统运行状态**\n"
                            f"⏱️ 运行时长: {uptime}\n"
                            f"🧠 内存使用: {mem_usage}\n"
                            f"⚙️ CPU 负载: {cpu_load}"
                        )
                        send_message(chat_id, reply_text)

                    elif text == "🔄 重启 Xray":
                        send_message(chat_id, "⏳ 正在重启 Xray 服务...")
                        execute_cmd("systemctl restart xray")
                        status = execute_cmd("systemctl is-active xray")
                        if status == "active":
                            send_message(chat_id, "✅ Xray 重启成功并已运行！\n*注意：重启后当前周期的流量统计已清零。*")
                        else:
                            send_message(chat_id, f"❌ Xray 重启失败，当前状态: {status}")

                    elif text == "🌀 重启 VPS":
                        send_message(chat_id, "⚠️ **正在向服务器发送重启指令...**\n\nVPS 即将断开连接并开始重启，大约需要 1-2 分钟。请在重启完成后重新呼出菜单。")
                        time.sleep(1)
                        execute_cmd("reboot")

        except Exception as e:
            time.sleep(5)

if __name__ == '__main__':
    main()
EOF

        # 替换对应的 Token 和 Chat ID
        sed -i "s/YOUR_BOT_TOKEN_HERE/${TG_TOKEN}/g" /root/tg_xray_bot.py
        sed -i "s/YOUR_CHAT_ID_HERE/${TG_CHAT_ID}/g" /root/tg_xray_bot.py

        # 生成 Systemd 服务配置
        cat > /etc/systemd/system/xray-tg-bot.service <<-EOF
[Unit]
Description=Telegram Bot for Xray Traffic Stats
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /root/tg_xray_bot.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable xray-tg-bot
        systemctl restart xray-tg-bot
        echo -e "$green✅ Telegram 机器人服务已后台启动！你可以去 TG 发送 /start 了。$none"

        # 配置每月18号自动清理流量的Cron
        echo -e "$green正在配置每月18号流量自动重置任务...$none"
        systemctl enable cron >/dev/null 2>&1
        systemctl start cron >/dev/null 2>&1
        # 追加进 crontab (如果不存在的话)
        (crontab -l 2>/dev/null | grep -v "xray api statsquery"; echo "0 0 18 * * /usr/local/bin/xray api statsquery --server=127.0.0.1:10085 -pattern 'user>>>user@reality>>>traffic>>>downlink' --reset > /dev/null 2>&1") | crontab -
        (crontab -l 2>/dev/null | grep -v "xray api statsquery"; echo "0 0 18 * * /usr/local/bin/xray api statsquery --server=127.0.0.1:10085 -pattern 'user>>>user@reality>>>traffic>>>uplink' --reset > /dev/null 2>&1") | crontab -
        echo -e "$green✅ 每月18号凌晨自动清零流量已设置完毕。$none"
    fi
fi
# ==========================================


# 指纹FingerPrint
fingerprint="random"

# SpiderX
spiderx=""

echo
echo "---------- Xray 配置信息 -------------"
echo -e "$green ---提示..这是 VLESS Reality 服务器配置--- $none"
echo -e "$yellow 地址 (Address) = $cyan${ip}$none"
echo -e "$yellow 端口 (Port) = ${cyan}${port}${none}"
echo -e "$yellow 用户ID (User ID / UUID) = $cyan${uuid}$none"
echo -e "$yellow 流控 (Flow) = ${cyan}xtls-rprx-vision${none}"
echo -e "$yellow 加密 (Encryption) = ${cyan}none${none}"
echo -e "$yellow 传输协议 (Network) = ${cyan}tcp$none"
echo -e "$yellow 伪装类型 (header type) = ${cyan}none$none"
echo -e "$yellow 底层传输安全 (TLS) = ${cyan}reality$none"
echo -e "$yellow SNI = ${cyan}${domain}$none"
echo -e "$yellow 指纹 (Fingerprint) = ${cyan}${fingerprint}$none"
echo -e "$yellow 公钥 (PublicKey) = ${cyan}${public_key}$none"
echo -e "$yellow ShortId = ${cyan}${shortid}$none"
echo -e "$yellow SpiderX = ${cyan}${spiderx}$none"
echo
echo "---------- VLESS Reality URL ----------"
if [[ $netstack == "6" ]]; then
  ip=[$ip]
fi
vless_reality_url="vless://${uuid}@${ip}:${port}?flow=xtls-rprx-vision&encryption=none&type=tcp&security=reality&sni=${domain}&fp=${fingerprint}&pbk=${public_key}&sid=${shortid}&spx=${spiderx}&#VLESS_R_${ip}"
echo -e "${cyan}${vless_reality_url}${none}"
echo
sleep 3
echo "以下两个二维码完全一样的内容"
qrencode -t UTF8 $vless_reality_url
qrencode -t ANSI $vless_reality_url
echo
echo "---------- END -------------"
echo "以上节点信息保存在 ~/_vless_reality_url_ 中"

# 节点信息保存到文件中
echo $vless_reality_url > ~/_vless_reality_url_
echo "以下两个二维码完全一样的内容" >> ~/_vless_reality_url_
qrencode -t UTF8 $vless_reality_url >> ~/_vless_reality_url_
qrencode -t ANSI $vless_reality_url >> ~/_vless_reality_url_

# 如果是 IPv6 小鸡，用 WARP 创建 IPv4 出站
if [[ $netstack == "6" ]]; then
    echo
    echo -e "$yellow这是一个 IPv6 小鸡，用 WARP 创建 IPv4 出站$none"
    echo "Telegram电报是直接访问IPv4地址的, 需要IPv4出站的能力"
    echo "----------------------------------------------------------------"
    pause

    # 安装 WARP IPv4
    curl -LO https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh
    yes "" | bash menu.sh 4

    # 重启 Xray
    echo
    echo -e "$yellow重启 Xray$none"
    echo "----------------------------------------------------------------"
    service xray restart

# 如果是 IPv4 小鸡，用 WARP 创建 IPv6 出站
elif  [[ $netstack == "4" ]]; then
    echo
    echo -e "$yellow这是一个 IPv4 小鸡，用 WARP 创建 IPv6 出站$none"
    echo -e "有些热门小鸡用原生的IPv4出站访问Google需要通过人机验证, 可以通过修改config.json指定google流量走WARP的IPv6出站解决"
    echo -e "群组: ${cyan} https://t.me/+q5WPfGjtwukyZjhl ${none}"
    echo -e "教程: ${cyan} https://zelikk.blogspot.com/2022/03/racknerd-v2ray-cloudflare-warp--ipv6-google-domainstrategy-outboundtag-routing.html ${none}"
    echo -e "视频: ${cyan} https://youtu.be/Yvvm4IlouEk ${none}"
    echo "----------------------------------------------------------------"
    pause

    # 安装 WARP IPv6
    curl -LO https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh
    yes "" | bash menu.sh 6

    # 重启 Xray
    echo
    echo -e "$yellow重启 Xray$none"
    echo "----------------------------------------------------------------"
    service xray restart

fi

echo
echo "节点信息保存在 ~/_vless_reality_url_ 中"
