# frpc-manager

一个功能强大、界面美观的 frpc 管理脚本工具，支持添加、删除、编辑、查看、备份、恢复等操作。  
由 [zeyu8023](https://github.com/zeyu8023) 开发维护。

---

## 🚀 一键安装 & 使用

首次使用：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/zeyu8023/frpc-manager/main/bootstrap.sh)
```

首次运行将提示你设置：

- `frpc.ini` 配置文件路径（如 `/etc/frpc/frpc.ini`）
- frpc 容器名称（如 `frpc_client`）

之后只需输入：

```bash
frp
```

即可随时打开 frpc 管理控制台 ✅

---

## 🛠 功能列表

| 功能 | 描述 |
|------|------|
| ➕ 添加端口映射 | 输入名称、本地 IP、本地端口、远程端口 |
| ❌ 删除端口映射 | 选择已有规则并删除 |
| ✏️ 编辑端口映射 | 修改 IP、端口、远程端口 |
| 📋 查看当前映射 | 显示所有规则及端口信息 |
| 🔁 重启 frpc 容器 | 自动调用 `docker restart` |
| 🌐 查看/修改全局配置 | 支持 `serverAddr`、`auth.token` 等字段 |
| 📜 查看日志 | 查看 frpc 容器日志（tail） |
| ♻️ 恢复配置备份 | 自动备份每次修改，支持回滚 |
| ⚙️ 设置配置路径 | 可随时修改 `frpc.ini` 路径和容器名 |
| 🧠 本地缓存 | 所有配置保存在 `~/.frpc-manager` 中 |

---

## ⚙️ 自定义配置（可选）

你也可以手动编辑配置文件：

```bash
~/.frpc-manager/config.env
```

内容示例：

```env
FRPC_INI="/etc/frpc/frpc.ini"
FRPC_CONTAINER="frpc_client"
```

---

## 📁 项目结构

```
frpc-manager/
├── bootstrap.sh         # 一键入口脚本（用户 curl 执行）
├── frpc-manager.sh      # 主功能脚本（自动读取配置）
├── README.md            # 使用说明（你正在看）
```

---

## 📣 欢迎反馈

如果你有建议、问题或想法，欢迎提交 [Issue](https://github.com/zeyu8023/frpc-manager/issues) 或 PR！

---
