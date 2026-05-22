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
apt update && apt install -y curl && bash <(curl -L https://raw.githubusercontent.com/meiti789789/xray-vless-reality/main/install.sh)
