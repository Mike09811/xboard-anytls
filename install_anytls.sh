#!/bin/bash
# AnyTLS 一键安装脚本 - 对接 Xboard 面板
# 用法: bash install_anytls.sh

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
CYAN='\033[0;36m'; PLAIN='\033[0m'

DIR="/opt/anytls"; BIN="$DIR/anytls-server"; CONF="$DIR/config.json"
SVC="anytls"; SVCF="/etc/systemd/system/${SVC}.service"
REPO="anytls/anytls-go"

info()   { echo -e "${GREEN}[INFO]${PLAIN} $1"; }
warn()   { echo -e "${YELLOW}[WARN]${PLAIN} $1"; }
err()    { echo -e "${RED}[ERROR]${PLAIN} $1"; }
header() { echo -e "\n${CYAN}========== $1 ==========${PLAIN}\n"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then err "请使用 root 运行"; exit 1; fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then source /etc/os-release; OS=$ID
    elif [[ -f /etc/redhat-release ]]; then OS="centos"
    else err "不支持的系统"; exit 1; fi
    info "系统: ${OS}"
}

get_arch() {
    ARCH=$(uname -m)
    case ${ARCH} in
        x86_64|amd64)  ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) err "不支持的架构: ${ARCH}"; exit 1 ;;
    esac
    info "架构: ${ARCH}"
}

install_deps() {
    export DEBIAN_FRONTEND=noninteractive
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        info "更新软件源..."
        apt-get update -y 2>&1 | tail -3
        info "安装依赖..."
        apt-get install -y curl wget jq unzip 2>&1 | tail -3
    else
        info "安装依赖..."
        yum install -y curl wget jq unzip 2>&1 | tail -3
    fi
    info "依赖就绪"
}

get_latest_version() {
    LATEST_VER=$(curl -s --connect-timeout 5 "https://api.github.com/repos/${REPO}/releases/latest" \
        | jq -r '.tag_name' 2>/dev/null)
    if [[ -z "$LATEST_VER" || "$LATEST_VER" == "null" ]]; then
        LATEST_VER=$(curl -sI --connect-timeout 5 "https://github.com/${REPO}/releases/latest" \
            | grep -i "^location:" | sed 's/.*tag\///' | tr -d '\r\n ')
    fi
    if [[ -z "$LATEST_VER" || "$LATEST_VER" == "null" ]]; then
        LATEST_VER=$(curl -s --connect-timeout 5 "https://github.com/${REPO}/releases" \
            | grep -oP '(?<=/releases/tag/)[^"]+' | head -1)
    fi
    if [[ -z "$LATEST_VER" || "$LATEST_VER" == "null" ]]; then
        err "无法获取最新版本号"; exit 1
    fi
    info "最新版本: ${LATEST_VER}"
}

download_anytls() {
    local ver_num="${LATEST_VER#v}"
    local fn="anytls_${ver_num}_linux_${ARCH}.zip"
    local url="https://github.com/${REPO}/releases/download/${LATEST_VER}/${fn}"
    info "下载 AnyTLS ${LATEST_VER}..."
    mkdir -p "${DIR}"
    if ! curl -L --progress-bar -o "/tmp/${fn}" "${url}"; then
        err "下载失败"; exit 1
    fi
    unzip -o "/tmp/${fn}" -d "${DIR}/" >/dev/null 2>&1
    rm -f "/tmp/${fn}"
    if [[ ! -f "${BIN}" ]]; then err "二进制文件未找到"; exit 1; fi
    chmod +x "${BIN}"
    info "下载完成"
}

gen_config() {
    local port="$1" password="$2" api_host="$3" api_key="$4" node_id="$5"
    cat > "${CONF}" << CEOF
{
    "port": "${port}",
    "password": "${password}",
    "api_host": "${api_host}",
    "api_key": "${api_key}",
    "node_id": ${node_id}
}
CEOF
    info "配置已保存: ${CONF}"
}

create_service() {
    local port="$1" password="$2"
    cat > "${SVCF}" << SEOF
[Unit]
Description=AnyTLS Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=${BIN} -l 0.0.0.0:${port} -p ${password}
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
SEOF
    systemctl daemon-reload
    systemctl enable ${SVC} >/dev/null 2>&1
    info "Systemd 服务已创建"
}

start_svc() {
    systemctl restart ${SVC}; sleep 2
    if systemctl is-active --quiet ${SVC}; then info "AnyTLS 启动成功"
    else err "启动失败，查看: journalctl -u ${SVC} -f"; exit 1; fi
}

stop_svc() {
    if systemctl is-active --quiet ${SVC} 2>/dev/null; then
        systemctl stop ${SVC}; info "服务已停止"
    fi
}

setup_fw() {
    local p="$1"
    if command -v ufw &>/dev/null; then
        ufw allow "${p}/tcp" >/dev/null 2>&1; info "UFW 放行 ${p}"
    elif command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --add-port="${p}/tcp" >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1; info "Firewalld 放行 ${p}"
    else warn "未检测到防火墙，请手动放行端口 ${p}"; fi
}

get_ip() {
    curl -s4 ip.sb 2>/dev/null || curl -s4 ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP"
}

show_xboard() {
    local port="$1" pwd="$2" api_host="$3" api_key="$4" node_id="$5"
    local ip=$(get_ip)
    header "Xboard 面板节点配置"
    echo -e "  ${YELLOW}服务器 IP:${PLAIN}    ${ip}"
    echo -e "  ${YELLOW}连接端口:${PLAIN}     ${port}"
    echo -e "  ${YELLOW}密码:${PLAIN}         ${pwd}"
    echo -e "  ${YELLOW}面板地址:${PLAIN}     ${api_host}"
    echo -e "  ${YELLOW}通信密钥:${PLAIN}     ${api_key}"
    echo -e "  ${YELLOW}节点 ID:${PLAIN}      ${node_id}"
    echo ""
    echo -e "  ${GREEN}Xboard 面板添加节点时填写:${PLAIN}"
    echo -e "  ${CYAN}节点地址: ${ip}${PLAIN}"
    echo -e "  ${CYAN}端口:     ${port}${PLAIN}"
    echo -e "  ${CYAN}密码:     ${pwd}${PLAIN}"
    echo ""
}

show_status() {
    header "AnyTLS 服务状态"
    systemctl status ${SVC} --no-pager 2>/dev/null || warn "服务未运行"
}

show_conf() {
    header "当前配置"
    if [[ -f "${CONF}" ]]; then cat "${CONF}"; else warn "配置不存在"; fi
    echo ""
}

do_install() {
    header "AnyTLS 一键安装 - 对接 Xboard"
    check_root; check_os; get_arch; install_deps; get_latest_version

    echo -e "\n${CYAN}=== 基础配置 ===${PLAIN}\n"

    read -rp "$(echo -e "${GREEN}监听端口 [默认 8443]: ${PLAIN}")" IN_PORT
    local PORT="${IN_PORT:-8443}"

    local DEF_PWD=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 16)
    read -rp "$(echo -e "${GREEN}连接密码 [默认随机: ${DEF_PWD}]: ${PLAIN}")" IN_PWD
    local PASSWD="${IN_PWD:-${DEF_PWD}}"

    echo -e "\n${CYAN}=== Xboard 面板对接 ===${PLAIN}\n"

    read -rp "$(echo -e "${GREEN}Xboard 面板地址 (如 https://xxx.com): ${PLAIN}")" API_HOST
    while [[ -z "$API_HOST" ]]; do
        err "面板地址不能为空"
        read -rp "$(echo -e "${GREEN}Xboard 面板地址: ${PLAIN}")" API_HOST
    done

    read -rp "$(echo -e "${GREEN}Xboard 通信密钥 (API Key): ${PLAIN}")" API_KEY
    while [[ -z "$API_KEY" ]]; do
        err "通信密钥不能为空"
        read -rp "$(echo -e "${GREEN}Xboard 通信密钥: ${PLAIN}")" API_KEY
    done

    read -rp "$(echo -e "${GREEN}Xboard 节点 ID: ${PLAIN}")" NODE_ID
    while [[ -z "$NODE_ID" ]]; do
        err "节点 ID 不能为空"
        read -rp "$(echo -e "${GREEN}Xboard 节点 ID: ${PLAIN}")" NODE_ID
    done

    echo ""
    info "开始安装..."
    stop_svc || true
    download_anytls
    gen_config "${PORT}" "${PASSWD}" "${API_HOST}" "${API_KEY}" "${NODE_ID}"
    create_service "${PORT}" "${PASSWD}"
    setup_fw "${PORT}"
    start_svc

    cat > "${DIR}/install_info" << IEOF
PORT=${PORT}
PASSWORD=${PASSWD}
API_HOST=${API_HOST}
API_KEY=${API_KEY}
NODE_ID=${NODE_ID}
VERSION=${LATEST_VER}
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')
IEOF

    show_xboard "${PORT}" "${PASSWD}" "${API_HOST}" "${API_KEY}" "${NODE_ID}"
    info "安装完成!"
    info "管理: bash $0 {start|stop|restart|status|config|xboard|update|uninstall}"
}

do_update() {
    header "更新 AnyTLS"
    check_root; check_os; get_arch; install_deps; get_latest_version
    stop_svc || true
    download_anytls
    [[ -f "${DIR}/install_info" ]] && sed -i "s/^VERSION=.*/VERSION=${LATEST_VER}/" "${DIR}/install_info"
    start_svc
    info "更新完成: ${LATEST_VER}"
}

do_uninstall() {
    header "卸载 AnyTLS"
    check_root
    read -rp "$(echo -e "${RED}确认卸载? [y/N]: ${PLAIN}")" confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { info "取消"; exit 0; }
    stop_svc || true
    systemctl disable ${SVC} >/dev/null 2>&1 || true
    rm -f "${SVCF}"; systemctl daemon-reload; rm -rf "${DIR}"
    info "AnyTLS 已完全卸载"
}

show_menu() {
    header "AnyTLS 管理脚本 - Xboard 对接版"
    echo -e "  ${GREEN}1.${PLAIN} 安装 AnyTLS"
    echo -e "  ${GREEN}2.${PLAIN} 更新 AnyTLS"
    echo -e "  ${GREEN}3.${PLAIN} 卸载 AnyTLS"
    echo -e "  ${GREEN}4.${PLAIN} 启动服务"
    echo -e "  ${GREEN}5.${PLAIN} 停止服务"
    echo -e "  ${GREEN}6.${PLAIN} 重启服务"
    echo -e "  ${GREEN}7.${PLAIN} 查看状态"
    echo -e "  ${GREEN}8.${PLAIN} 查看配置"
    echo -e "  ${GREEN}9.${PLAIN} 查看 Xboard 对接信息"
    echo -e "  ${GREEN}0.${PLAIN} 退出"
    echo ""
    read -rp "$(echo -e "${GREEN}请选择 [0-9]: ${PLAIN}")" choice
    case "$choice" in
        1) do_install ;;
        2) do_update ;;
        3) do_uninstall ;;
        4) check_root; systemctl start ${SVC}; info "已启动" ;;
        5) check_root; systemctl stop ${SVC}; info "已停止" ;;
        6) check_root; systemctl restart ${SVC}; info "已重启" ;;
        7) show_status ;;
        8) show_conf ;;
        9)
            if [[ -f "${DIR}/install_info" ]]; then
                source "${DIR}/install_info"
                show_xboard "${PORT}" "${PASSWORD}" "${API_HOST}" "${API_KEY}" "${NODE_ID}"
            else warn "未找到安装信息"; fi
            ;;
        0) exit 0 ;;
        *) err "无效选择" ;;
    esac
}

case "${1:-}" in
    install)   do_install ;;
    update)    do_update ;;
    uninstall) do_uninstall ;;
    start)     check_root; systemctl start ${SVC}; info "已启动" ;;
    stop)      check_root; systemctl stop ${SVC}; info "已停止" ;;
    restart)   check_root; systemctl restart ${SVC}; info "已重启" ;;
    status)    show_status ;;
    config)    show_conf ;;
    xboard)
        if [[ -f "${DIR}/install_info" ]]; then
            source "${DIR}/install_info"
            show_xboard "${PORT}" "${PASSWORD}" "${API_HOST}" "${API_KEY}" "${NODE_ID}"
        else warn "未找到安装信息"; fi
        ;;
    *)         show_menu ;;
esac
