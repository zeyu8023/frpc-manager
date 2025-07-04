#!/bin/bash

# === 加载配置 ===
CONFIG_FILE="$HOME/.frpc-manager/config.env"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

FRPC_INI="${FRPC_INI:-/etc/frpc/frpc.ini}"
FRPC_CONTAINER="${FRPC_CONTAINER:-frpc}"
BACKUP_DIR="$(dirname "$FRPC_INI")/backups"
LOG_LINES=50

# === 色彩定义 ===
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"

# === 工具函数 ===
print_success() { echo -e "${GREEN}[✔] $1${RESET}"; }
print_error()   { echo -e "${RED}[✘] $1${RESET}"; }
print_info()    { echo -e "${BLUE}[➤] $1${RESET}"; }

# === 配置备份 ===
backup_config() {
  mkdir -p "$BACKUP_DIR"
  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  cp "$FRPC_INI" "$BACKUP_DIR/frpc.ini.bak.$TIMESTAMP"
  print_info "已备份配置为：$BACKUP_DIR/frpc.ini.bak.$TIMESTAMP"
}

# === 恢复备份 ===
restore_backup() {
  echo -e "\n${YELLOW}♻️ 可用备份列表：${RESET}"
  ls -1t "$BACKUP_DIR"/frpc.ini.bak.* 2>/dev/null | nl
  echo ""
  read -p "请输入要恢复的编号（或回车取消）: " CHOICE
  [[ -z "$CHOICE" ]] && echo "已取消恢复。" && return

  FILE=$(ls -1t "$BACKUP_DIR"/frpc.ini.bak.* 2>/dev/null | sed -n "${CHOICE}p")
  if [[ -f "$FILE" ]]; then
    cp "$FILE" "$FRPC_INI"
    print_success "已恢复备份：$FILE"
  else
    print_error "无效编号，未找到对应备份文件"
  fi
}

# === 添加规则 ===
add_rule() {
  echo -e "\n${YELLOW}➕ 添加新映射规则${RESET}"
  read -p "请输入映射名称: " NAME
  read -p "请输入本地 IP（默认 192.168.31.2）: " LOCAL_IP
  read -p "请输入本地端口: " LOCAL_PORT
  read -p "请输入远程端口: " REMOTE_PORT
  LOCAL_IP=${LOCAL_IP:-192.168.31.2}

  if grep -q "name *= *\"$NAME\"" "$FRPC_INI"; then
    print_error "名称 [$NAME] 已存在"
    return
  fi

  backup_config

  echo -e "\n[[proxies]]" >> "$FRPC_INI"
  echo "name = \"$NAME\"" >> "$FRPC_INI"
  echo "type = \"tcp\"" >> "$FRPC_INI"
  echo "localIP = \"$LOCAL_IP\"" >> "$FRPC_INI"
  echo "localPort = $LOCAL_PORT" >> "$FRPC_INI"
  echo "remotePort = $REMOTE_PORT" >> "$FRPC_INI"

  print_success "添加成功：$NAME ($LOCAL_IP:$LOCAL_PORT → $REMOTE_PORT)"
}

# === 删除规则 ===
delete_rule() {
  echo -e "\n${YELLOW}❌ 删除映射规则${RESET}"
  read -p "请输入要删除的映射名称: " NAME

  if ! grep -q "name *= *\"$NAME\"" "$FRPC_INI"; then
    print_error "未找到 [$NAME]"
    return
  fi

  backup_config

  TMP=$(mktemp)
  SKIP=0
  BLOCK=()

  while IFS= read -r line; do
    if [[ $line =~ \[\[proxies\]\] ]]; then
      BLOCK=()
      BLOCK+=("$line")
      SKIP=0
      continue
    fi

    if [[ ${#BLOCK[@]} -gt 0 ]]; then
      BLOCK+=("$line")
      if [[ $line =~ name\ *=\ *\"$NAME\" ]]; then
        SKIP=1
      fi
      if [[ ${#BLOCK[@]} -ge 5 ]]; then
        if [[ $SKIP -eq 0 ]]; then
          printf "%s\n" "${BLOCK[@]}" >> "$TMP"
        fi
        BLOCK=()
        SKIP=0
      fi
    else
      echo "$line" >> "$TMP"
    fi
  done < "$FRPC_INI"

  mv "$TMP" "$FRPC_INI"
  print_success "已删除 [$NAME]"
}

# === 编辑规则 ===
edit_rule() {
  echo -e "\n${YELLOW}✏️ 编辑映射规则${RESET}"
  mapfile -t RULE_NAMES < <(grep 'name *= *"' "$FRPC_INI" | sed 's/.*name *= *"\(.*\)"/\1/')
  if [[ ${#RULE_NAMES[@]} -eq 0 ]]; then
    print_error "未找到任何映射规则"
    return
  fi

  echo "可编辑的规则："
  for i in "${!RULE_NAMES[@]}"; do
    printf "  %d. %s\n" $((i+1)) "${RULE_NAMES[$i]}"
  done

  read -p "请输入要编辑的编号（或回车取消）: " CHOICE
  [[ -z "$CHOICE" ]] && echo "已取消。" && return
  if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || (( CHOICE < 1 || CHOICE > ${#RULE_NAMES[@]} )); then
    print_error "无效编号"
    return
  fi

  NAME="${RULE_NAMES[$((CHOICE-1))]}"
  START=$(grep -n "name *= *\"$NAME\"" "$FRPC_INI" | cut -d: -f1)
  [[ -z "$START" ]] && print_error "未找到规则 [$NAME]" && return
  START=$((START - 1))

  ORIG_BLOCK=$(sed -n "${START},$((START+5))p" "$FRPC_INI")
  OLD_IP=$(echo "$ORIG_BLOCK" | grep 'localIP' | cut -d= -f2 | tr -d ' "')
  OLD_LPORT=$(echo "$ORIG_BLOCK" | grep 'localPort' | cut -d= -f2 | tr -d ' ')
  OLD_RPORT=$(echo "$ORIG_BLOCK" | grep 'remotePort' | cut -d= -f2 | tr -d ' ')

  echo "当前配置：$NAME | $OLD_IP:$OLD_LPORT → $OLD_RPORT"
  read -p "新本地 IP（回车保留 $OLD_IP）: " NEW_IP
  read -p "新本地端口（回车保留 $OLD_LPORT）: " NEW_LPORT
  read -p "新远程端口（回车保留 $OLD_RPORT）: " NEW_RPORT

  NEW_IP=${NEW_IP:-$OLD_IP}
  NEW_LPORT=${NEW_LPORT:-$OLD_LPORT}
  NEW_RPORT=${NEW_RPORT:-$OLD_RPORT}

  backup_config

  TMP=$(mktemp)
  awk -v name="$NAME" -v ip="$NEW_IP" -v lport="$NEW_LPORT" -v rport="$NEW_RPORT" '
    BEGIN {skip=0}
    /^\[\[proxies\]\]/ {block=1; print; next}
    block && /name *= *"[^"]+"/ {
      if ($0 ~ name) {
        skip=1
        print
        getline; print "type = \"tcp\""
        print "localIP = \"" ip "\""
        print "localPort = " lport
        print "remotePort = " rport
        block=0
        next
      }
    }
    skip && /^[^[]/ {next}
    {print}
  ' "$FRPC_INI" > "$TMP"

  mv "$TMP" "$FRPC_INI"
  print_success "已更新 [$NAME] 映射配置"
}

# === 映射列表 ===
list_rules() {
  echo -e "\n${YELLOW}📋 当前映射规则（名称 | 本地 → 远程）：${RESET}"
  awk '
    /^\[\[proxies\]\]/ {i=0}
    /name *= *"/ {gsub(/"/, "", $3); name=$3; i++}
    /localIP *= *"/ {gsub(/"/, "", $3); ip=$3; i++}
    /localPort *=/ {port=$3; i++}
    /remotePort *=/ {rport=$3; i++}
    i==4 {printf "- %s | %s:%s → %s\n", name, ip, port, rport; i=0}
  ' "$FRPC_INI"
}

# === 重启容器 ===
restart_frpc() {
  print_info "正在重启 frpc 容器 [$FRPC_CONTAINER]..."
  if docker restart "$FRPC_CONTAINER" >/dev/null 2>&1; then
    print_success "容器已重启"
  else
    print_error "容器 [$FRPC_CONTAINER] 不存在或重启失败"
  fi
}

# === 查看全局配置 ===
view_global_config() {
  echo -e "\n${YELLOW}🌐 当前全局配置：${RESET}"
  grep -E '^(serverAddr|serverPort|auth\.)' "$FRPC_INI"
}

# === 修改全局配置 ===
edit_global_config() {
  echo -e "\n${YELLOW}✏️ 修改全局配置${RESET}"

  declare -A CONFIG_KEYS=(
    ["serverAddr"]="服务器地址"
    ["serverPort"]="服务器端口"
    ["auth.method"]="认证方式"
    ["auth.token"]="认证令牌"
  )

  backup_config

  for KEY in "${!CONFIG_KEYS[@]}"; do
    CURRENT=$(grep -E "^$KEY" "$FRPC_INI" | cut -d= -f2- | sed 's/^ *"*\(.*\)"* *$/\1/')
    read -p "${CONFIG_KEYS[$KEY]}（当前：$CURRENT）: " NEWVAL
    [[ -z "$NEWVAL" ]] && continue

    if grep -q "^$KEY" "$FRPC_INI"; then
      sed -i "s|^$KEY *=.*|$KEY = \"${NEWVAL}\"|" "$FRPC_INI"
    else
      sed -i "1i$KEY = \"${NEWVAL}\"" "$FRPC_INI"
    fi
  done

  print_success "全局配置已更新"
}

# === 查看日志 ===
view_logs() {
  echo -e "\n${YELLOW}📜 frpc 容器日志（最近 $LOG_LINES 行）：${RESET}"
  docker logs --tail $LOG_LINES "$FRPC_CONTAINER" 2>&1 | less
}

# === 设置配置路径和容器名 ===
set_config() {
  echo -e "\n${YELLOW}⚙️ 设置 frpc.ini 路径和容器名${RESET}"
  read -p "请输入 frpc.ini 路径（当前：$FRPC_INI）: " NEW_INI
  read -p "请输入 frpc 容器名（当前：$FRPC_CONTAINER）: " NEW_CONTAINER

  [[ -n "$NEW_INI" ]] && FRPC_INI="$NEW_INI"
  [[ -n "$NEW_CONTAINER" ]] && FRPC_CONTAINER="$NEW_CONTAINER"

  echo "FRPC_INI=\"$FRPC_INI\"" > "$CONFIG_FILE"
  echo "FRPC_CONTAINER=\"$FRPC_CONTAINER\"" >> "$CONFIG_FILE"

  print_success "配置已保存：$CONFIG_FILE"
}

menu() {
  echo -e "\n${YELLOW}========== frpc 管理脚本 - by Xiaoyu ==========${RESET}"
  echo "1. 添加端口映射"
  echo "2. 删除端口映射"
  echo "3. 编辑端口映射"
  echo "4. 查看当前映射"
  echo "5. 重启 frpc 容器"
  echo "6. 查看全局配置"
  echo "7. 修改全局配置"
  echo "8. 查看 frpc 日志"
  echo "9. 恢复配置备份"
  echo "10. 设置 frpc.ini 路径和容器名"
  echo "0. 退出"
  echo -e "${YELLOW}===============================================${RESET}"
  read -p "请选择操作： " CHOICE

  case $CHOICE in
    1) add_rule && restart_frpc ;;
    2) delete_rule && restart_frpc ;;
    3) edit_rule && restart_frpc ;;
    4) list_rules ;;
    5) restart_frpc ;;
    6) view_global_config ;;
    7) edit_global_config ;;
    8) view_logs ;;
    9) restore_backup ;;
    10) set_config ;;
    0) exit 0 ;;
    *) print_error "无效选项，请重新输入" ;;
  esac
}

while true; do
  menu
done
