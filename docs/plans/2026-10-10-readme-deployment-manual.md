# README 中文部署与使用手册 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把仓库根目录 `README.md` 全量重写为中文的部署与使用手册（开篇 + 8 章）。

**Architecture:** 单文件改动。README 承载全部主线路径（照着抄能跑通）；超过约 20 行的模板/清单用相对链接指向 `docs/` 既有页，不复制其正文。不新增文件、不改代码。

**Tech Stack:** Markdown（GitHub 渲染）、Prettier（仓库格式门禁）、bash（链接与脱敏扫描）。

**设计文档:** `docs/design/2026-10-10-readme-deployment-manual.md`

## 约定：内容块记法

本计划里"要写进 README 的内容"用哨兵注释标出：

    <!-- README 内容开始 -->
    …最终 markdown，原样复制到 README.md…
    <!-- README 内容结束 -->

哨兵之间就是**最终文本**，不要另外加围栏、不要改写。按任务顺序把它们依次拼进
`README.md`。

## Global Constraints

- 只改 `README.md`；不新增或修改任何其他文件。
- 正文、标题、说明、排障全中文；**不出现英文句子或英文段落**。仅以下保留英文：命令、路径、代码块、产品与协议名（npm、Docker、PWA、GitHub）、沿用已久的术语（token、headless、standalone、Web Shell、slash 命令）。
- 脱敏：地址与凭据一律占位符 —— `<NAS-IP>`、`<nps入口:端口>`、`<token>`、`~/path/to/project`；**不得**出现真实内网/公网地址或真实 token。
- 仓库内链接一律相对路径且必须真实存在；命令必须与仓库实现一致（`scripts/qwen-serve-ctl.sh` 已实测）。
- 保留：license 与 Node 两枚徽章、演示图、评测配置表与版本分数表及趋势图、生态列表（压缩后放参考章）。
- 删除：npm/downloads/trendshift 徽章、多语言链接行、Claude Code 对比表（改写成要点）、独立 Privacy 章节（并入参考章）。
- 完成门槛：`npx prettier --check README.md` 通过。

## File Structure

- **Modify:** `README.md`（唯一交付物，全量重写）

引用但不修改的既有页（链接清单，全部已验证存在）：

| 用途       | 相对路径                                                                                                                                                                                                                                                                                                                                                                   |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 快速开始   | `./docs/users/quickstart.md`、`./docs/users/overview.md`                                                                                                                                                                                                                                                                                                                   |
| 认证与配置 | `./docs/users/configuration/auth.md`、`./docs/users/configuration/settings.md`、`./docs/users/configuration/model-providers.md`                                                                                                                                                                                                                                            |
| 守护进程   | `./docs/users/qwen-serve.md`、`./docs/users/qwen-serve-deploy-local.md`                                                                                                                                                                                                                                                                                                    |
| 运行与部署 | `./docs/developers/development/deployment.md`                                                                                                                                                                                                                                                                                                                              |
| 能力       | `./docs/users/features/sandbox.md`、`./docs/users/features/skills.md`、`./docs/users/features/sub-agents.md`、`./docs/users/features/mcp.md`、`./docs/users/features/headless.md`、`./docs/users/features/commands.md`、`./docs/users/features/approval-mode.md`、`./docs/users/features/hooks.md`、`./docs/users/features/memory.md`、`./docs/users/features/worktree.md` |
| 渠道       | `./docs/users/features/channels/overview.md`、`./docs/users/features/channels/telegram.md`、`./docs/users/features/channels/dingtalk.md`、`./docs/users/features/channels/weixin.md`、`./docs/users/features/channels/feishu.md`                                                                                                                                           |
| 编辑器插件 | `./docs/users/integration-vscode.md`、`./docs/users/integration-jetbrains.md`、`./docs/users/integration-zed.md`                                                                                                                                                                                                                                                           |
| 支持       | `./docs/users/support/Uninstall.md`、`./docs/users/support/tos-privacy.md`、`./docs/users/support/troubleshooting.md`                                                                                                                                                                                                                                                      |
| SDK        | `./packages/sdk-typescript/README.md`、`./packages/sdk-python/README.md`、`./packages/sdk-java/qwencode/README.md`                                                                                                                                                                                                                                                         |
| 仓库       | `./CONTRIBUTING.md`、`./AGENTS.md`、`./AI_GUIDE.md`、`./LICENSE`、`./.github/assets/qwen-code-avg-score-trend.svg`                                                                                                                                                                                                                                                         |

官方文档站仅保留三个稳定入口：`https://qwenlm.github.io/qwen-code-docs/en/users/overview`、`https://qwenlm.github.io/qwen-code-docs/en/users/configuration/auth/`、`https://qwenlm.github.io/qwen-code-docs/en/users/configuration/settings/`。

关键锚点（本仓库，已核对存在）：

- `./docs/users/qwen-serve.md#authentication`、`#https--tls-for-mobile---cross-device-access`、`#install-the-web-shell-as-an-app`、`#cli-flags`
- `./docs/users/qwen-serve-deploy-local.md#linux-systemd-user-unit`、`#macos-launchd-user-agent`、`#token-rotation`

---

### Task 1: 开篇骨架（标题、定位、徽章、能力一览、目录）

**Files:**

- Modify: `README.md`（本任务整体覆盖全文）

**Interfaces:**

- Produces: README 的标题层与锚点集合。后续任务在此骨架下追加章节；`## 目录` 的锚点必须与各章标题一一对应。

- [ ] **Step 1: 整体覆盖 README.md**

原 `## Why Tay Bellow?` / `## Installation` / `## Quick Start` / `## How to Use Tay Bellow` / `## Capabilities` / 评测 / `## Ecosystem` / `## Privacy` / `## Contributing` / `## Acknowledgments` 各章节在本任务中一并废弃；评测数据仍可从 `git show HEAD:README.md` 取回，Task 8 会用到。目录锚点在后续任务落章后才有效，最终由 Task 9 复核。

写入内容：

<!-- README 内容开始 -->

<div align="center">

[![License](https://img.shields.io/github/license/QwenLM/qwen-code.svg)](./LICENSE)
[![Node.js Version](https://img.shields.io/badge/node-%3E%3D22.0.0-brightgreen.svg)](https://nodejs.org/)

**终端、编辑器、桌面、浏览器、聊天里的开源 AI 编程代理。**

</div>

![Tay Bellow 在终端、桌面应用、浏览器、编辑器与聊天中的形态](https://img.alicdn.com/imgextra/i3/O1CN01l5GyhGuOPGC3XHtt_!!6000000005884-2-tps-1742-903.png)

> 本文档是中文的部署与使用手册。本仓库为个人自用分支：把 Tay Bellow 部署在家里一台
> 主机上跑 `qwen serve` 守护进程，经内网穿透供手机与其它设备访问。

## 这是什么 · 能力一览

- **开箱即用的 Agentic 能力** —— 自动记忆（Auto-Memory）、自动 Skills、子代理
  （SubAgents）、Agent Teams、MCP、动态工作流（Workflows），零配置起步。
- **多协议接入** —— 支持 OpenAI、Anthropic、Gemini、Qwen 等 API，也能接本地模型
  （Ollama / vLLM），运行时可切换。
- **多端形态** —— 终端 CLI、桌面应用、Web Shell、编辑器插件（VS Code / JetBrains /
  Zed）、IM 渠道（Telegram / 钉钉 / 微信 / 飞书）。
- **开源模型与框架** —— 框架与模型都开源，不锁定供应商。
- **可编程** —— 无头模式（headless）、TypeScript / Python / Java SDK、ACP 守护进程协议，
  方便脚本与自研工具接入。
- **多客户端共享一个代理** —— `qwen serve` 守护进程让多个客户端共享同一份工作区与会话状态。

## 目录

- [1. 快速开始](#1-快速开始)
- [2. 部署](#2-部署)
- [3. 手机 / 远程访问](#3-手机--远程访问)
- [4. 日常使用](#4-日常使用)
- [5. 渠道集成](#5-渠道集成)
- [6. 运维与排障](#6-运维与排障)
- [7. 评测](#7-评测)
- [8. 参考](#8-参考)

<!-- README 内容结束 -->

- [ ] **Step 2: 验证结构与脱敏**

Run:

```bash
grep -n '^#\{1,2\} ' README.md | head -12
grep -nE '192\.168\.|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' README.md
```

Expected: 第一条显示一级标题与各章标题；第二条无输出（无真实地址）。

- [ ] **Step 3: 提交**

```bash
git add README.md
git commit -m "docs(readme): rebuild the README into a Chinese manual skeleton"
```

---

### Task 2: 第 1 章 快速开始

**Files:**

- Modify: `README.md`（追加 `## 1. 快速开始`）

**Interfaces:**

- Consumes: Task 1 的 `## 目录` 锚点 `#1-快速开始`。
- Produces: 小节 `### 1.1 安装`、`### 1.2 配置模型与密钥`、`### 1.3 第一次对话`。

- [ ] **Step 1: 追加第 1 章**

<!-- README 内容开始 -->

## 1. 快速开始

### 1.1 安装

**Linux / macOS（推荐，无需预装 Node.js）：**

```bash
curl -fsSL https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen-standalone.sh | bash
```

**Windows（PowerShell）：**

```powershell
irm https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen-standalone.ps1 | iex
```

> 安装后请重开终端，让环境变量生效。

其他安装方式：`npm install -g @qwen-code/qwen-code@latest`（需要 Node.js 22+）、
`brew install qwen-code`（macOS / Linux）。也可以用
[6.3 节](#63-升级与卸载)的 `scripts/qwen-serve-ctl.sh install` 一条命令装好，并顺带
生成守护进程 token。

### 1.2 配置模型与密钥

在会话里运行 `/auth` 选择 provider 并填入 API Key；也可以直接编辑 `settings.json`。
细节见 [认证配置](./docs/users/configuration/auth.md) 与
[设置参考](./docs/users/configuration/settings.md)。

### 1.3 第一次对话

```bash
cd /path/to/your-project
qwen
```

然后在会话里试试：

```text
解释这个仓库的结构，告诉我该从哪里读起。
```

<!-- README 内容结束 -->

- [ ] **Step 2: 验证链接与命令**

Run:

```bash
grep -oE '\]\(\./[^)#]+' README.md | sed 's/^](//' | sort -u | while read -r p; do [ -e "$p" ] || echo "MISSING: $p"; done
sed -n '/^## 1\./,/^## 2\./p' README.md | grep -cE 'curl -fsSL|npm install -g|brew install'
```

Expected: 第一条无输出；第二条计数为 3。

- [ ] **Step 3: 提交**

```bash
git add README.md
git commit -m "docs(readme): add the quick start chapter"
```

---

### Task 3: 第 2 章 部署（四条路径）

**Files:**

- Modify: `README.md`（追加 `## 2. 部署`）

**Interfaces:**

- Consumes: `scripts/qwen-serve-ctl.sh`（已实现 `install`、`start`、`stop`、`restart`、`status`、`logs`、`token`；配置文件 `~/.qwen-serve-ctl.conf`，状态文件 `~/.qwen-serve.pid`、`~/.qwen-serve.log`，token 文件 `~/.qwen-serve-token`）。
- Produces: 小节 `### 2.1`–`### 2.4`，供第 3、6 章引用。

- [ ] **Step 1: 追加 2.1 与 2.2**

<!-- README 内容开始 -->

## 2. 部署

### 2.1 服务器 / NAS 直接部署（守护进程 + bash 脚本管理）

仓库自带管理脚本 `scripts/qwen-serve-ctl.sh`，覆盖安装与整个管理回路：

| 命令      | 作用                                                                                |
| --------- | ----------------------------------------------------------------------------------- |
| `install` | 安装 qwen CLI（已有则跳过）+ 按需生成 token 文件（`~/.qwen-serve-token`，600 权限） |
| `start`   | 后台启动 `qwen serve`（nohup），等待 `/health` 最多 15 秒                           |
| `stop`    | 停止（SIGTERM，10 秒不退再 SIGKILL）                                                |
| `restart` | 重启                                                                                |
| `status`  | 进程与健康状态（退出码 0 运行 / 1 不健康 / 3 停止）                                 |
| `logs`    | 查看最近 200 行日志                                                                 |
| `token`   | 轮换 token（`restart` 后生效）                                                      |

```bash
scripts/qwen-serve-ctl.sh install
scripts/qwen-serve-ctl.sh start
scripts/qwen-serve-ctl.sh status
```

守护进程的可调参数写在 `~/.qwen-serve-ctl.conf`（bash 语法，每次命令都会读取）：

```bash
QWEN_HOST=127.0.0.1                 # 改成 0.0.0.0 才暴露到 loopback 之外（此时必须带 token）
QWEN_PORT=4170
QWEN_WORKSPACES=("$HOME/project-a" "$HOME/project-b")   # 每项变成一个 --workspace
QWEN_EXTRA_ARGS="--allow-origin http://example.com:4170" # 额外的 `qwen serve` 参数，空格分隔
```

不设置 `QWEN_WORKSPACES` 时，主工作区就是执行 `start` 时所在的目录。token 只注入守护
进程自己的环境，不会写进 shell 配置文件。这条路径是纯 `nohup`：**不会**在崩溃或重启后
自动拉起，需要自愈就用下一节的服务管理器方案。

细节与等价的手工命令见 [本地部署模板](./docs/users/qwen-serve-deploy-local.md)。

### 2.2 开机自启（systemd / launchd）

要让守护进程跨重启存活，用服务管理器：

- **Linux**：`~/.config/systemd/user/qwen-serve.service`，配合
  `loginctl enable-linger "$(whoami)"` 让用户级服务在退出登录后继续运行。
- **macOS**：`~/Library/LaunchAgents/com.qwenlm.qwen-serve.plist`。

完整 unit / plist 模板、token 的 `EnvironmentFile` 写法与轮换步骤见
[本地部署模板 · Linux systemd 用户单元](./docs/users/qwen-serve-deploy-local.md#linux-systemd-user-unit)
与 [macOS launchd 用户代理](./docs/users/qwen-serve-deploy-local.md#macos-launchd-user-agent)。

<!-- README 内容结束 -->

- [ ] **Step 2: 追加 2.3（Docker 容器部署）**

<!-- README 内容开始 -->

### 2.3 Docker 容器部署

守护进程是宿主机的 Node 进程，仓库自带的 `Dockerfile` 是**沙箱镜像**、不是守护进程镜像，
所以这里自己搭一个最小容器（`docker compose` 文件内联如下，约 20 行）：

```dockerfile
# Dockerfile
FROM node:22-slim
RUN npm install -g @qwen-code/qwen-code
WORKDIR /workspaces/project-a
CMD ["qwen", "serve", "--hostname", "0.0.0.0", "--port", "4170", "--workspace", "/workspaces/project-a"]
```

```yaml
# docker-compose.yml
services:
  qwen-serve:
    build: .
    environment:
      QWEN_SERVER_TOKEN: ${QWEN_SERVER_TOKEN:?请在 .env 里设置}
    ports:
      - '4170:4170'
    volumes:
      - ~/project-a:/workspaces/project-a
      - qwen-home:/root/.qwen
    restart: unless-stopped
volumes:
  qwen-home: {}
```

```bash
export QWEN_SERVER_TOKEN="$(openssl rand -hex 32)"
docker compose up -d --build
docker compose logs -f qwen-serve
```

注意：

- `--hostname 0.0.0.0` 属于非 loopback 绑定，**必须**带 token（上面的 compose 已强制）。
- 工作区目录要挂载进容器；`/root/.qwen` 持久化后会话与配置不会随容器销毁。
- 需要用沙箱工具时，把宿主机的 `/var/run/docker.sock` 挂进容器（等于把宿主 docker 控制权
  交给容器，谨慎）。
- 经代理访问时的 Host / `--allow-origin` 规则与 [3.2 节](#32-公网nps-内网穿透)一致。

<!-- README 内容结束 -->

- [ ] **Step 3: 追加 2.4（从源码构建运行）**

<!-- README 内容开始 -->

### 2.4 从源码构建运行

改代码后自测用仓库源码路径：

```bash
corepack pnpm install --frozen-lockfile   # 首次安装依赖（会触发一次构建）
npm run build                             # 构建全部包
npm run bundle                            # 打成单文件 dist/cli.js
npm run dev                               # 用 tsx 直接跑源码，改 core / cli 即时生效
```

完整说明见 [运行与部署](./docs/developers/development/deployment.md)，仓库结构与二次开发
指引见 [`AGENTS.md`](./AGENTS.md)。

<!-- README 内容结束 -->

- [ ] **Step 4: 验证第 2 章**

Run:

```bash
sed -n '/^## 2\./,/^## 3\./p' README.md | grep -cE 'qwen-serve-ctl\.sh|docker compose|npm run build'
grep -oE '\]\(\./[^)#]+' README.md | sed 's/^](//' | sort -u | while read -r p; do [ -e "$p" ] || echo "MISSING: $p"; done
```

Expected: 第一条计数 ≥ 6；第二条无输出。

- [ ] **Step 5: 提交**

```bash
git add README.md
git commit -m "docs(readme): add the deployment chapter"
```

---

### Task 4: 第 3 章 手机 / 远程访问

**Files:**

- Modify: `README.md`（追加 `## 3. 手机 / 远程访问`）

**Interfaces:**

- Consumes: Task 3 的 `QWEN_HOST` 说明；`docs/users/qwen-serve.md` 的锚点 `#authentication`、`#https--tls-for-mobile---cross-device-access`、`#install-the-web-shell-as-an-app`、`#cli-flags`。
- Produces: 小节 `### 3.1 局域网：Local Control 配对`、`### 3.2 公网：nps 内网穿透`、`### 3.3 iPhone 添加到主屏全屏运行`；Task 6 的排障条目引用 `#32-公网nps-内网穿透`。

- [ ] **Step 1: 追加 3.1 与 3.2**

<!-- README 内容开始 -->

## 3. 手机 / 远程访问

### 3.1 局域网：Local Control 配对

在同一局域网内，最省事的方式是让守护进程开一个带配对 token 的 LAN 监听器，手机扫码
即可接入：

```bash
qwen serve --local-control
```

启动后终端会打印二维码；Web Shell 会话头部的**二维码按钮**也能随时重新取出配对 URL
（token 在 URL 的 `#` 片段里，不走网络、不进访问日志）。该监听器使用守护进程自己签发、
可随时吊销的配对 token，与 `--token` 的运行时 token 相互独立（运行时 token 在 LAN
监听器上按设计被拒绝）。参数细节见 [CLI flags](./docs/users/qwen-serve.md#cli-flags)。

### 3.2 公网：nps 内网穿透

把家里的守护进程经 nps 暴露给手机时，容易撞上两条防线：

1. **Host 白名单（DNS rebinding 防线）**：默认 loopback 绑定只接受由守护进程端口构成的
   `localhost` / `127.0.0.1` / `[::1]` 等 Host，nps 转发进来的公网 Host 不在白名单，结果
   是**每个请求**（连 Web Shell 页面本身）都返回 `403 {"error":"Invalid Host header"}`，
   而且 `--allow-origin` 覆盖不了这道门。
2. **Origin（CORS）白名单**：`Origin` 与守护进程看到的 `Host` 不同源时返回 `403`；
   WebSocket（终端、语音）另有一道门，都需要显式放行。

最省事的做法是让守护进程绑定非 loopback 地址 —— 非 loopback 绑定会整体跳过 Host 门，
改用 token 把关：

```bash
export QWEN_SERVER_TOKEN='<token>'
qwen serve --hostname 0.0.0.0 --port 4170 --allow-origin '<nps入口:端口>'
```

`--allow-origin` 的值取手机浏览器地址栏里的 origin（协议 + 主机 + 端口，例如
`http://<nps入口:端口>`），终端与语音这类 WebSocket 功能必须显式加。用
`scripts/qwen-serve-ctl.sh` 管理时，把这些参数写进 2.1 节的 `~/.qwen-serve-ctl.conf`
（`QWEN_HOST` 与 `QWEN_EXTRA_ARGS`）即可。认证、TLS 与威胁模型的完整说明见
[守护进程用户指南 · 认证](./docs/users/qwen-serve.md#authentication)。

> 公网暴露时务必权衡：bearer token 拥有守护进程的全部权限（包含执行代码）。建议在 nps
> 入口配置 TLS，或用 `--tls-cert` / `--tls-key` 让守护进程直接跑 HTTPS。

<!-- README 内容结束 -->

- [ ] **Step 2: 追加 3.3（iPhone 全屏 App）**

<!-- README 内容开始 -->

### 3.3 iPhone 添加到主屏全屏运行

Web Shell 自带 PWA 元数据（`/manifest.webmanifest` 声明 `display: standalone`，
`/sw.js` 由守护进程以 `Service-Worker-Allowed: /` 提供），因此可以当成 App 用：

1. 在 iPhone 上用 **Safari** 打开守护进程地址（必须是 Safari，Chrome 等不支持全屏独立窗口）。
2. 点底部「分享」→「添加到主屏幕」。
3. 从主屏图标启动，即为**无地址栏、无工具栏**的独立全屏窗口。

注意：

- 普通 HTTP 的局域网地址**不会**启用 Service Worker（离线缓存等能力需要受信任的 HTTPS）；
  全屏独立窗口本身不依赖它。
- 安装后的启动地址固定为服务器根路径，**URL 片段里的 token 不会带进去**，首次打开需要
  重新输入一次；[3.2 节](#32-公网nps-内网穿透)的 token 同样适用。
- 语音输入等需要安全上下文的 API 要走 HTTPS（`--tls-cert` / `--tls-key`）。

完整说明（含 mkcert 签发与信任流程）见
[守护进程用户指南 · HTTPS / TLS](./docs/users/qwen-serve.md#https--tls-for-mobile---cross-device-access)
与 [把 Web Shell 安装为应用](./docs/users/qwen-serve.md#install-the-web-shell-as-an-app)。

<!-- README 内容结束 -->

- [ ] **Step 3: 验证第 3 章**

Run:

```bash
sed -n '/^## 3\./,/^## 4\./p' README.md | grep -cE 'Invalid Host header|--allow-origin|--local-control|添加到主屏幕'
grep -oE '\]\(\./[^)#]+' README.md | sed 's/^](//' | sort -u | while read -r p; do [ -e "$p" ] || echo "MISSING: $p"; done
```

Expected: 第一条计数 ≥ 4；第二条无输出。

- [ ] **Step 4: 提交**

```bash
git add README.md
git commit -m "docs(readme): add the phone and remote access chapter"
```

---

### Task 5: 第 4 章 日常使用

**Files:**

- Modify: `README.md`（追加 `## 4. 日常使用`）

**Interfaces:**

- Produces: 小节 `### 4.1 终端交互与常用 slash 命令`、`### 4.2 无头模式（脚本 / CI）`、`### 4.3 SDK`、`### 4.4 编辑器插件`、`### 4.5 沙箱与扩展能力`。

- [ ] **Step 1: 追加第 4 章**

<!-- README 内容开始 -->

## 4. 日常使用

### 4.1 终端交互与常用 slash 命令

在项目目录里运行 `qwen` 进入会话。常用 slash 命令：

| 命令       | 作用                             |
| ---------- | -------------------------------- |
| `/auth`    | 配置模型 provider 与密钥         |
| `/help`    | 查看全部命令                     |
| `/context` | 查看上下文占用明细               |
| `/tools`   | 查看当前可用工具                 |
| `/review`  | 对改动做代码审查                 |
| `/bugfix`  | 按"先复现后修复"的流程处理 bug   |
| `/loop`    | 定时或按自定节奏重复执行某个提示 |

完整命令表见 [命令参考](./docs/users/features/commands.md)，审批模式（含 YOLO）见
[审批模式](./docs/users/features/approval-mode.md)。

### 4.2 无头模式（脚本 / CI）

```bash
qwen -p "解释这个仓库的结构" --approval-mode yolo
qwen -p "生成变更日志" --output-format stream-json
```

适合放进脚本、CI 与批处理任务，见 [无头模式](./docs/users/features/headless.md)。

### 4.3 SDK

- TypeScript：[`packages/sdk-typescript`](./packages/sdk-typescript/README.md)
- Python：[`packages/sdk-python`](./packages/sdk-python/README.md)
- Java：[`packages/sdk-java/qwencode`](./packages/sdk-java/qwencode/README.md)

### 4.4 编辑器插件

- [VS Code](./docs/users/integration-vscode.md)
- [JetBrains](./docs/users/integration-jetbrains.md)
- [Zed](./docs/users/integration-zed.md)

### 4.5 沙箱与扩展能力

- **沙箱**：用容器或 macOS Seatbelt 隔离有副作用的工具调用，见
  [沙箱](./docs/users/features/sandbox.md)。
- **Skills**：内置与自定义技能，见 [技能](./docs/users/features/skills.md)。
- **子代理与 Agent Teams**：把可并行的任务拆给子代理，见
  [子代理](./docs/users/features/sub-agents.md)。
- **MCP**：接入外部工具与数据源，见 [MCP](./docs/users/features/mcp.md)。
- **Hooks / 记忆 / 工作树**：见 [Hooks](./docs/users/features/hooks.md)、
  [记忆](./docs/users/features/memory.md)、[Git 工作树](./docs/users/features/worktree.md)。

<!-- README 内容结束 -->

- [ ] **Step 2: 验证第 4 章**

Run:

```bash
sed -n '/^## 4\./,/^## 5\./p' README.md | grep -cE '/auth|/review|qwen -p'
grep -oE '\]\(\./[^)#]+' README.md | sed 's/^](//' | sort -u | while read -r p; do [ -e "$p" ] || echo "MISSING: $p"; done
```

Expected: 第一条计数 ≥ 3；第二条无输出。

- [ ] **Step 3: 提交**

```bash
git add README.md
git commit -m "docs(readme): add the daily usage chapter"
```

---

### Task 6: 第 5 章 渠道集成

**Files:**

- Modify: `README.md`（追加 `## 5. 渠道集成`）

**Interfaces:**

- Consumes: `docs/users/features/channels/` 下的渠道页。
- Produces: 四个渠道小节，每个 ≤ 6 行，细节全部外链。

- [ ] **Step 1: 追加第 5 章**

<!-- README 内容开始 -->

## 5. 渠道集成

渠道让 Tay Bellow 在 IM 里接收任务。共同前提：先把渠道配置写进 `settings.json`，再让
守护进程或 CLI 拉起渠道进程。

```bash
qwen channel start          # 启动 settings.json 里已启用的渠道
```

工作原理、会话范围、Sender Policy 等通用概念见
[渠道总览](./docs/users/features/channels/overview.md)。

### 5.1 Telegram

在 @BotFather 创建机器人拿到 token，把 Telegram 渠道配置写进 `settings.json`，再运行
`qwen channel start`。步骤见 [Telegram](./docs/users/features/channels/telegram.md)。

### 5.2 钉钉

在钉钉开放平台创建机器人应用，配置回调地址与密钥，见
[钉钉](./docs/users/features/channels/dingtalk.md)。

### 5.3 微信

在微信侧准备应用凭据并配置回调，见
[微信](./docs/users/features/channels/weixin.md)。

### 5.4 飞书

在飞书开放平台创建自建应用、开启事件订阅并配置回调，见
[飞书](./docs/users/features/channels/feishu.md)。

<!-- README 内容结束 -->

- [ ] **Step 2: 验证第 5 章**

Run:

```bash
sed -n '/^## 5\./,/^## 6\./p' README.md | grep -c 'qwen channel start'
grep -oE '\]\(\./[^)#]+' README.md | sed 's/^](//' | sort -u | while read -r p; do [ -e "$p" ] || echo "MISSING: $p"; done
```

Expected: 第一条计数 ≥ 1；第二条无输出。

- [ ] **Step 3: 提交**

```bash
git add README.md
git commit -m "docs(readme): add the channels chapter"
```

---

### Task 7: 第 6 章 运维与排障

**Files:**

- Modify: `README.md`（追加 `## 6. 运维与排障`）

**Interfaces:**

- Consumes: Task 3 的脚本命令表、Task 4 的 3.2 节、`docs/users/support/Uninstall.md`、`docs/users/support/troubleshooting.md`、`docs/users/qwen-serve-deploy-local.md#token-rotation`。
- Produces: 小节 `### 6.1 状态与日志`、`### 6.2 token 轮换`、`### 6.3 升级与卸载`、`### 6.4 常见故障`。

- [ ] **Step 1: 追加第 6 章**

<!-- README 内容开始 -->

## 6. 运维与排障

### 6.1 状态与日志

```bash
scripts/qwen-serve-ctl.sh status    # 进程 + /health：退出码 0 运行 / 1 不健康 / 3 停止
scripts/qwen-serve-ctl.sh logs      # 跟踪日志
curl -H "Authorization: Bearer <token>" http://127.0.0.1:4170/capabilities   # 端到端验证 token
```

日志默认在 `~/.qwen-serve.log`，PID 文件在 `~/.qwen-serve.pid`。

### 6.2 token 轮换

```bash
scripts/qwen-serve-ctl.sh token     # 生成新 token
scripts/qwen-serve-ctl.sh restart   # 让新 token 生效
```

用 systemd 时别忘了同步 `~/.qwen-serve-token-env`，见
[Token rotation](./docs/users/qwen-serve-deploy-local.md#token-rotation)。

### 6.3 升级与卸载

```bash
scripts/qwen-serve-ctl.sh install   # 重新安装到最新版
```

卸载 CLI 见 [卸载指南](./docs/users/support/Uninstall.md)。

### 6.4 常见故障

| 现象                                                    | 原因与处理                                                                                                                                                                                                                |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `403 {"error":"Invalid Host header"}`                   | 守护进程仍是 loopback 绑定，代理转发来的 Host 不在白名单。解决办法见 [3.2 节](#32-公网nps-内网穿透)：改绑 `0.0.0.0`（非 loopback 会跳过 Host 门，必须带 token），或让代理由原样转发 Host。`--allow-origin` 治不了这一条。 |
| `401`                                                   | `Authorization: Bearer` 与守护进程配置的 token 不一致。用 `curl` 打 `/capabilities` 复核；注意非 loopback 绑定下 `/health` 也要求 token。                                                                                 |
| 手机浏览器 XHR 返回 `403 Request denied by CORS policy` | `Origin` 与守护进程看到的 `Host` 不同源。给守护进程加 `--allow-origin <手机浏览器的 origin>`（终端 / 语音的 WebSocket 也需要）。                                                                                          |
| 守护进程起不来 / 端口被占                               | 换 `QWEN_PORT`，或先 `scripts/qwen-serve-ctl.sh stop` 清掉旧进程；启动失败时脚本会打印日志尾部。                                                                                                                          |
| 手机连不上，但本机 `curl` 正常                          | 检查 nps 入口与转发目标是否指向守护进程实际端口，以及守护进程是否绑到了可达接口。                                                                                                                                         |
| 二维码 / 配对 URL 过期                                  | 配对 token 是临时的：在 Web Shell 头部重新打开二维码按钮取新 URL，或改用手输 token。                                                                                                                                      |

其他问题见 [故障排查](./docs/users/support/troubleshooting.md)。

<!-- README 内容结束 -->

- [ ] **Step 2: 验证第 6 章**

Run:

```bash
sed -n '/^## 6\./,/^## 7\./p' README.md | grep -cE 'Invalid Host header|401|CORS'
grep -oE '\]\(\./[^)#]+' README.md | sed 's/^](//' | sort -u | while read -r p; do [ -e "$p" ] || echo "MISSING: $p"; done
```

Expected: 第一条计数 ≥ 3；第二条无输出。

- [ ] **Step 3: 提交**

```bash
git add README.md
git commit -m "docs(readme): add the operations and troubleshooting chapter"
```

---

### Task 8: 第 7 章 评测 与 第 8 章 参考

**Files:**

- Modify: `README.md`（追加 `## 7. 评测`、`## 8. 参考`）

**Interfaces:**

- Consumes: `git show HEAD:README.md` 中的评测数据（数值必须一致）；`./.github/assets/qwen-code-avg-score-trend.svg`。
- Produces: 文档收尾。

- [ ] **Step 1: 追加第 7 章（评测）**

先 `git show HEAD:README.md` 核对下面表格的数值，确认一致后写入。

<!-- README 内容开始 -->

## 7. 评测

在 SWE-bench Verified（500 例）上每个版本跑 3 次，模型 `Qwen 3.7 Max`。

| 配置              | 值                                                                                                  |
| ----------------- | --------------------------------------------------------------------------------------------------- |
| 数据集            | `princeton-nlp/SWE-bench_Verified`，500 例                                                          |
| 运行次数          | 每个版本 3 次，共 1,500 个任务；共 7 个版本                                                         |
| 模型              | `Qwen 3.7 Max`                                                                                      |
| 采样              | `temperature=1`、`top_p=0.95`                                                                       |
| 思考 / 推理       | `interleaved_thinking=true`、`thinking_type=adaptive`、`reasoning_effort=high`                      |
| 上下文 / 输出上限 | `context_1m=true`、`model_context_length=1,000,000`、`max_tokens=64,000`、`model_max_tokens=65,535` |
| Harness 上限      | `max_iterations=500`、`runtime_timeout_sec=7,200`、`agent_timeout_multiplier=3.0`                   |

| 版本   |   平均分   | Pass Rate | pass@3 | pass^3 |
| ------ | :--------: | --------: | -----: | -----: |
| 0.0.14 | **77.80%** |     84.6% |  84.6% |  69.2% |
| 0.1.0  | **76.73%** |     84.6% |  84.6% |  68.0% |
| 0.5.0  | **76.60%** |     83.0% |  83.0% |  68.4% |
| 0.10.0 | **76.47%** |     84.4% |  84.4% |  67.4% |
| 0.15.0 | **77.67%** |     84.6% |  84.6% |  68.6% |
| 0.19.0 | **76.40%** |     85.0% |  85.0% |  65.8% |
| 0.22.0 | **77.33%** |     84.4% |  84.4% |  68.0% |

![各版本平均分趋势](./.github/assets/qwen-code-avg-score-trend.svg)

<!-- README 内容结束 -->

- [ ] **Step 2: 追加第 8 章（参考）**

<!-- README 内容开始 -->

## 8. 参考

### 文档地图

- 用户文档总览：[`docs/users/overview.md`](./docs/users/overview.md)、[快速上手](./docs/users/quickstart.md)
- 认证与模型：[认证配置](./docs/users/configuration/auth.md)、[模型 provider](./docs/users/configuration/model-providers.md)、[设置参考](./docs/users/configuration/settings.md)
- 守护进程：[用户指南](./docs/users/qwen-serve.md)、[本地部署模板](./docs/users/qwen-serve-deploy-local.md)
- 命令与能力：[命令参考](./docs/users/features/commands.md)、[无头模式](./docs/users/features/headless.md)、[沙箱](./docs/users/features/sandbox.md)、[MCP](./docs/users/features/mcp.md)
- 仓库结构：[`AI_GUIDE.md`](./AI_GUIDE.md)、[`AGENTS.md`](./AGENTS.md)
- 官方文档站：[用户文档总览](https://qwenlm.github.io/qwen-code-docs/en/users/overview)、[认证](https://qwenlm.github.io/qwen-code-docs/en/users/configuration/auth/)、[设置](https://qwenlm.github.io/qwen-code-docs/en/users/configuration/settings/)

### 生态

- **Tay Bellow Desktop** —— 官方桌面应用（macOS / Windows / Linux）
- [**AionUi**](https://github.com/iOfficeAI/AionUi) —— 面向命令行 AI 工具的图形界面
- [**Gemini CLI Desktop**](https://github.com/Piebald-AI/gemini-cli-desktop) —— 跨平台桌面 / Web / 移动 UI
- [**Tay Bellow Claw**](https://github.com/openclaw/acpx) —— 让其它代理经 ACP 把编码任务委派给 Tay Bellow
- [**Aliyun Model Studio CLI**](https://github.com/modelstudioai/cli) —— 阿里云百炼官方 CLI

### 许可与致谢

隐私与条款见 [`docs/users/support/tos-privacy.md`](./docs/users/support/tos-privacy.md)，
贡献指南见 [`CONTRIBUTING.md`](./CONTRIBUTING.md)，许可见 [`LICENSE`](./LICENSE)。

本项目最初基于 [Google Gemini CLI](https://github.com/google-gemini/gemini-cli) v0.8.2；自
Tay Bellow v0.1 起停止与上游同步，独立发展为多协议、多平台的代理框架，并对 Qwen 系列
模型做深度集成。感谢 Gemini CLI 团队的出色工作。

<!-- README 内容结束 -->

- [ ] **Step 3: 验证第 7、8 章**

Run:

```bash
sed -n '/^## 7\./,$p' README.md | grep -cE '77\.33%|0\.22\.0'
test -e .github/assets/qwen-code-avg-score-trend.svg && echo "趋势图存在"
grep -oE '\]\(\./[^)#]+' README.md | sed 's/^](//' | sort -u | while read -r p; do [ -e "$p" ] || echo "MISSING: $p"; done
```

Expected: 第一条计数 ≥ 2；趋势图存在；第二条无输出。

- [ ] **Step 4: 提交**

```bash
git add README.md
git commit -m "docs(readme): add the evaluation and reference chapters"
```

---

### Task 9: 全局验收（链接、锚点、格式、语言、脱敏、通读）

**Files:**

- Modify: `README.md`（仅修验收发现的问题）

**Interfaces:**

- Consumes: Tasks 1–8 的全部内容。

- [ ] **Step 1: 本地链接全量校验**

Run:

```bash
grep -oE '\]\(\./[^)#]+' README.md | sed 's/^](//' | sort -u | while read -r p; do [ -e "$p" ] || echo "MISSING: $p"; done
```

Expected: 无输出。有输出就逐个修正路径后重跑。

- [ ] **Step 2: 目录锚点校验**

Run:

```bash
grep -oE '\]\(#[^)]+\)' README.md | sed 's/^](#//; s/)$//' | sort -u
grep -nE '^#{2,3} ' README.md
```

Expected: 逐条人工比对 —— 每个 `#锚点` 都能在标题清单里找到对应标题（GitHub 中文锚点即标题去标点、空格转 `-`）。不匹配就改锚点或改标题。

- [ ] **Step 3: 格式门禁**

Run:

```bash
npx prettier --check README.md
```

Expected: `All matched files use Prettier code style!`（不通过就 `npx prettier --write README.md` 后重跑）。

- [ ] **Step 4: 英文与脱敏扫描**

Run:

````bash
awk '/^```/{c=!c;next} !c && /[A-Za-z]/ && !/[\x{4e00}-\x{9fff}]/ && length($0)>25 {print NR": "$0}' README.md
grep -nE '192\.168\.|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|token=[A-Za-z0-9_-]{20,}' README.md
````

Expected: 第一条只剩徽章 / 图片 / 外链 / 表格行这类"整行非中文但属预期"的行，逐条确认无英文句子；第二条无输出（无真实地址或真实 token）。

- [ ] **Step 5: 通读自检**

从头到尾通读一遍 README，确认：8 章齐全、命令可复制、无 TODO 残留、无与 `docs/` 结论矛盾的表述；发现的问题当场修掉。

- [ ] **Step 6: 提交**

```bash
git add README.md
git commit -m "docs(readme): finalize the Chinese deployment manual"
```

## Self-Review

- **设计覆盖**：设计文档的 8 章结构 ↔ Task 1（开篇）+ Task 2–8（各章）一一对应；徽章精简、Docker 内联、评测保留配置表与分数表及趋势图、对比表改要点、生态入参考、脱敏口径落在 Global Constraints 与 Task 9 的扫描里。
- **占位符**：无 TBD/TODO；`<NAS-IP>`、`<token>` 一类是设计要求的脱敏占位符，不是未填内容。
- **命名一致性**：`scripts/qwen-serve-ctl.sh` 子命令（`install`/`start`/`stop`/`restart`/`status`/`logs`/`token`）在 Task 3、7 中一致；文件名 `~/.qwen-serve-ctl.conf`、`~/.qwen-serve-token`、`~/.qwen-serve.pid`、`~/.qwen-serve.log` 与实现一致。
