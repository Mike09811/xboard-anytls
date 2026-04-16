# AnyTLS 一键安装脚本 - 对接 Xboard

一键部署 AnyTLS 服务端，自动对接 Xboard 面板。

## 支持系统

- Ubuntu 18.04+
- Debian 10+
- CentOS 7+
- Rocky Linux / Alma Linux

## 一键安装

```bash
bash <(curl -Ls https://raw.githubusercontent.com/Mike09811/xboard-anytls/main/install_anytls.sh)
```

## 管理命令

```bash
bash install_anytls.sh install    # 安装
bash install_anytls.sh update     # 更新
bash install_anytls.sh uninstall  # 卸载
bash install_anytls.sh start      # 启动
bash install_anytls.sh stop       # 停止
bash install_anytls.sh restart    # 重启
bash install_anytls.sh status     # 查看状态
bash install_anytls.sh config     # 查看配置
bash install_anytls.sh xboard     # 查看 Xboard 对接信息
```

不带参数运行显示交互式菜单：

```bash
bash install_anytls.sh
```

## Xboard 面板对接

安装完成后脚本会自动输出对接信息：

- 节点地址（服务器 IP）
- 连接端口
- 连接密码

在 Xboard 面板添加节点时填入对应字段即可。随时查看：

```bash
bash install_anytls.sh xboard
```

## 文件路径

| 文件 | 路径 |
|------|------|
| 二进制文件 | `/opt/anytls/anytls-server` |
| 配置文件 | `/opt/anytls/config.json` |
| 安装信息 | `/opt/anytls/install_info` |
| Systemd 服务 | `/etc/systemd/system/anytls.service` |

## 查看日志

```bash
journalctl -u anytls -f
```

## License

MIT
