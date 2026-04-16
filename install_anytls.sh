#!/bin/bash
# NodeRS-AnyTLS 一键安装脚本 - 对接 Xboard 面板
# 基于 MoeclubM/NodeRS-AnyTLS
# 用法: bash install_anytls.sh

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
CYAN='\033[0;36m'; PLAIN='\033[0m'

INSTALL_URL="https://raw.githubusercontent.com/MoeclubM/NodeRS-AnyTLS/main/scripts/install.sh"
UPGRADE_URL="https://raw.githubusercontent.com/MoeclubM/NodeRS-AnyTLS/main/scripts/upgrade.sh"

info()   { echo -e "${GREEN}[INFO]${PLAIN} $1"; }
warn()   { echo -e "${YELLOW}[WARN]${PLAIN} $1"; }
err()    { echo -e "${RED}[ERROR]${PLAIN} $1"; }
header() { echo -e "\n${CYAN}========== $1 ==========${PLAIN}\n"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then err "请使用 root 运行"; exit 1; fi
}

get_ip() {
    curl -s4 ip.sb 2>/dev/null || curl -s4 ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP"
}

do_install() {
    header "NodeRS-AnyTLS 安装 - 对接 Xboard"
    check_root

    echo -e "\n${CYAN}=== Xboard 面板信息 ===${PLAIN}\n"

    read -rp "$(echo -e "${GREEN}Xboard 面板地址 (如 https://xxx.com): ${PLAIN}")" PANEL_URL
    while [[ -z "$PANEL_URL" ]]; do
        err "面板地址不能为空"
        read -rp "$(echo -e "${GREEN}Xboard 面板地址: ${PLAIN}")" PANEL_URL
    done

    read -rp "$(echo -e "${GREEN}Xboard 通信密钥 (server_token): ${PLAIN}")" PANEL_TOKEN
    while [[ -z "$PANEL_TOKEN" ]]; do
        err "通信密钥不能为空"
        read -rp "$(echo -e "${GREEN}Xboard 通信密钥: ${PLAIN}")" PANEL_TOKEN
    done

    read -rp "$(echo -e "${GREEN}节点 ID: ${PLAIN}")" NODE_ID
    while [[ -z "$NODE_ID" ]]; do
        err "节点 ID 不能为空"
        read -rp "$(echo -e "${GREEN}节点 ID: ${PLAIN}")" NODE_ID
    done

    echo ""
    echo -e "${CYAN}=== TLS 证书配置 ===${PLAIN}\n"
    echo -e "  ${GREEN}1.${PLAIN} 自动 ACME (需域名指向本机)"
    echo -e "  ${GREEN}2.${PLAIN} 自签名证书 (无需域名)"
    echo -e "  ${GREEN}3.${PLAIN} 使用已有证书文件"
    echo ""
    read -rp "$(echo -e "${GREEN}选择 TLS 方式 [默认 2]: ${PLAIN}")" TLS_MODE
    TLS_MODE="${TLS_MODE:-2}"

    EXTRA_ARGS=""
    case "$TLS_MODE" in
        1)
            read -rp "$(echo -e "${GREEN}域名 (如 node.example.com): ${PLAIN}")" DOMAIN
            if [[ -n "$DOMAIN" ]]; then EXTRA_ARGS="--server-name ${DOMAIN}"; fi
            ;;
        2)
            read -rp "$(echo -e "${GREEN}SNI 域名 [默认 go.microsoft.com]: ${PLAIN}")" SNI
            SNI="${SNI:-go.microsoft.com}"
            EXTRA_ARGS="--server-name ${SNI} --self-signed"
            ;;
        3)
            read -rp "$(echo -e "${GREEN}证书路径: ${PLAIN}")" CERT_F
            read -rp "$(echo -e "${GREEN}私钥路径: ${PLAIN}")" KEY_F
            EXTRA_ARGS="--cert-file ${CERT_F} --key-file ${KEY_F}"
            ;;
    esac

    echo ""
    info "开始安装 NodeRS-AnyTLS..."
    info "面板: ${PANEL_URL}"
    info "节点 ID: ${NODE_ID}"
    echo ""

    curl -fsSL "${INSTALL_URL}" | bash -s -- \
        --panel-url "${PANEL_URL}" \
        --panel-token "${PANEL_TOKEN}" \
        --node-id "${NODE_ID}" \
        ${EXTRA_ARGS}

    if [[ $? -eq 0 ]]; then
        echo ""
        info "安装完成!"
        local ip=$(get_ip)
        header "安装信息"
        echo -e "  ${YELLOW}服务器 IP:${PLAIN}    ${ip}"
        echo -e "  ${YELLOW}面板地址:${PLAIN}     ${PANEL_URL}"
        echo -e "  ${YELLOW}节点 ID:${PLAIN}      ${NODE_ID}"
        echo -e "  ${YELLOW}服务名称:${PLAIN}     noders-anytls-${NODE_ID}"
        echo ""
        echo -e "  ${GREEN}管理命令:${PLAIN}"
        echo -e "  ${CYAN}systemctl status noders-anytls-${NODE_ID}${PLAIN}"
        echo -e "  ${CYAN}journalctl -u noders-anytls-${NODE_ID} -f${PLAIN}"
        echo ""
    else
        err "安装失败，请检查上方日志"
    fi
}

do_update() {
    header "更新 NodeRS-AnyTLS"
    check_root
    info "正在更新..."
    curl -fsSL "${UPGRADE_URL}" | bash -s --
}

do_uninstall() {
    header "卸载 NodeRS-AnyTLS"
    check_root
    echo -e "  ${GREEN}1.${PLAIN} 卸载指定节点"
    echo -e "  ${GREEN}2.${PLAIN} 卸载全部"
    echo ""
    read -rp "$(echo -e "${GREEN}选择 [1/2]: ${PLAIN}")" UM
    case "$UM" in
        1)
            read -rp "$(echo -e "${GREEN}节点 ID: ${PLAIN}")" NID
            curl -fsSL "${INSTALL_URL}" | bash -s -- --uninstall --node-id "${NID}"
            ;;
        2)
            read -rp "$(echo -e "${RED}确认卸载全部? [y/N]: ${PLAIN}")" confirm
            [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { info "取消"; exit 0; }
            curl -fsSL "${INSTALL_URL}" | bash -s -- --uninstall --all
            ;;
        *) err "无效选择" ;;
    esac
}

do_status() {
    header "节点状态"
    read -rp "$(echo -e "${GREEN}节点 ID [默认 1]: ${PLAIN}")" NID
    NID="${NID:-1}"
    systemctl status "noders-anytls-${NID}" --no-pager -l 2>/dev/null || warn "服务未找到"
}

do_logs() {
    header "节点日志"
    read -rp "$(echo -e "${GREEN}节点 ID [默认 1]: ${PLAIN}")" NID
    NID="${NID:-1}"
    journalctl -u "noders-anytls-${NID}" -n 50 --no-pager
}

do_config() {
    header "节点配置"
    read -rp "$(echo -e "${GREEN}节点 ID [默认 1]: ${PLAIN}")" NID
    NID="${NID:-1}"
    local conf="/etc/noders/anytls/nodes/${NID}.toml"
    if [[ -f "$conf" ]]; then cat "$conf"; else warn "配置不存在: $conf"; fi
    echo ""
}

show_menu() {
    header "NodeRS-AnyTLS 管理 - Xboard 对接"
    echo -e "  ${GREEN}1.${PLAIN} 安装节点"
    echo -e "  ${GREEN}2.${PLAIN} 更新程序"
    echo -e "  ${GREEN}3.${PLAIN} 卸载"
    echo -e "  ${GREEN}4.${PLAIN} 查看状态"
    echo -e "  ${GREEN}5.${PLAIN} 查看日志"
    echo -e "  ${GREEN}6.${PLAIN} 查看配置"
    echo -e "  ${GREEN}7.${PLAIN} 重启节点"
    echo -e "  ${GREEN}0.${PLAIN} 退出"
    echo ""
    read -rp "$(echo -e "${GREEN}请选择 [0-7]: ${PLAIN}")" choice
    case "$choice" in
        1) do_install ;;
        2) do_update ;;
        3) do_uninstall ;;
        4) do_status ;;
        5) do_logs ;;
        6) do_config ;;
        7)
            check_root
            read -rp "$(echo -e "${GREEN}节点 ID [默认 1]: ${PLAIN}")" NID
            NID="${NID:-1}"
            systemctl restart "noders-anytls-${NID}"
            info "已重启 noders-anytls-${NID}"
            ;;
        0) exit 0 ;;
        *) err "无效选择" ;;
    esac
}

case "${1:-}" in
    install)   do_install ;;
    update)    do_update ;;
    uninstall) do_uninstall ;;
    status)    do_status ;;
    logs)      do_logs ;;
    config)    do_config ;;
    restart)
        check_root
        NID="${2:-1}"
        systemctl restart "noders-anytls-${NID}"
        info "已重启 noders-anytls-${NID}"
        ;;
    *)         show_menu ;;
esac
