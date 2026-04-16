# NodeRS-AnyTLS 一键安装脚本 - 对接 Xboard

基于 [MoeclubM/NodeRS-AnyTLS](https://github.com/MoeclubM/NodeRS-AnyTLS)，一键部署 AnyTLS 节点并对接 Xboard 面板。

## 一键安装

```bash
bash <(curl -Ls https://raw.githubusercontent.com/Mike09811/xboard-anytls/main/install_anytls.sh)
```

安装时会要求输入：
- Xboard 面板地址
- 通信密钥 (server_token)
- 节点 ID
- TLS 证书方式（ACME / 自签名 / 已有证书）

## 管理命令

```bash
bash install_anytls.sh install    # 安装节点
bash install_anytls.sh update     # 更新程序
bash install_anytls.sh uninstall  # 卸载
bash install_anytls.sh status     # 查看状态
bash install_anytls.sh logs       # 查看日志
bash install_anytls.sh config     # 查看配置
bash install_anytls.sh restart 6  # 重启节点(ID=6)
```

不带参数运行显示交互式菜单。

## 服务管理

```bash
systemctl status noders-anytls-6     # 状态
systemctl restart noders-anytls-6    # 重启
journalctl -u noders-anytls-6 -f     # 日志
```

## 文件路径

| 文件 | 路径 |
|------|------|
| 二进制 | `/usr/local/bin/noders-anytls` |
| 配置目录 | `/etc/noders/anytls/nodes/` |
| 节点配置 | `/etc/noders/anytls/nodes/<node_id>.toml` |

## License

MIT
