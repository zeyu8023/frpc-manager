#!/bin/bash

REPO_URL="https://raw.githubusercontent.com/你的用户名/frpc-manager/main"
CACHE_DIR="$HOME/.frpc-manager"
SCRIPT="$CACHE_DIR/frpc-manager.sh"
CONFIG_FILE="$CACHE_DIR/config.env"

mkdir -p "$CACHE_DIR"

# === 下载主脚本 ===
if [[ ! -f "$SCRIPT" ]]; then
  echo "[➤] 正在下载 frpc 管理脚本..."
  curl -fsSL "$REPO_URL/frpc-manager.sh" -o "$SCRIPT" || {
    echo "[✘] 下载失败，请检查网络或仓库地址"
    exit 1
  }
  chmod +x "$SCRIPT"
  echo "[✔] 下载完成，已缓存至 $SCRIPT"
fi

# === 首次设置配置 ===
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo ""
  echo "🛠 首次使用，请设置 frpc.ini 路径和容器名："
  read -p "请输入 frpc.ini 路径（如 /etc/frpc/frpc.ini）: " FRPC_INI
  read -p "请输入 frpc 容器名（如 frpc_client）: " FRPC_CONTAINER

  echo "FRPC_INI=\"$FRPC_INI\"" > "$CONFIG_FILE"
  echo "FRPC_CONTAINER=\"$FRPC_CONTAINER\"" >> "$CONFIG_FILE"
  echo "[✔] 配置已保存：$CONFIG_FILE"
fi

# === 设置 frp 命令 ===
if ! command -v frp >/dev/null; then
  if [[ -w /usr/local/bin ]]; then
    ln -sf "$SCRIPT" /usr/local/bin/frp
    echo "[✔] 已创建全局命令：frp"
  else
    SHELL_RC="$HOME/.bashrc"
    [[ $SHELL == *zsh ]] && SHELL_RC="$HOME/.zshrc"
    echo "alias frp=\"$SCRIPT\"" >> "$SHELL_RC"
    echo "[✔] 已添加 alias 到 $SHELL_RC，请重新打开终端或执行：source $SHELL_RC"
  fi
fi

# === 执行脚本 ===
bash "$SCRIPT"
