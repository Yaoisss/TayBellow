# Tay Bellow 部署与使用教程

Tay Bellow 是面向终端、编辑器、桌面、浏览器与聊天的开源 AI 编程代理。本文档是本仓库的安装、部署与使用教程。

## 1. 安装

### 1.1 Linux / macOS（推荐，无需预装 Node.js）

```bash
curl -fsSL https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen-standalone.sh | bash
```

### 1.2 Windows（PowerShell）

```powershell
irm https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen-standalone.ps1 | iex
```

> 安装完成后请重启终端，确保环境变量生效。

### 1.3 npm / Homebrew

```bash
npm install -g @qwen-code/qwen-code@latest   # 需要 Node.js 22+
brew install qwen-code                       # macOS / Linux
```

安装脚本的更多选项（`--method`、`--source` 等）见 [安装指南](./scripts/installation/INSTALLATION_GUIDE.md)。

### 1.4 用仓库脚本安装

仓库自带的管理脚本一条命令即可装好，并顺带生成守护进程 token（详见第 2 节）：

```bash
scripts/qwen-serve-ctl.sh install
```

## 2. 部署

### 2.1 服务器 / NAS：守护进程 + bash 脚本管理

`qwen serve` 是一个常驻的守护进程，客户端通过 HTTP + SSE（ACP）接入。仓库自带的
`scripts/qwen-serve-ctl.sh` 覆盖安装与整个管理回路：

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

更多模板与等价的手工命令见 [本地部署模板](./docs/users/qwen-serve-deploy-local.md)。

### 2.2 开机自启（systemd / launchd）

要让守护进程跨重启存活，用服务管理器：

- **Linux**：`~/.config/systemd/user/qwen-serve.service`，配合
  `loginctl enable-linger "$(whoami)"` 让用户级服务在退出登录后继续运行。
- **macOS**：`~/Library/LaunchAgents/com.qwenlm.qwen-serve.plist`。

完整 unit / plist 模板、token 的 `EnvironmentFile` 写法与轮换步骤见
[本地部署模板 · Linux systemd 用户单元](./docs/users/qwen-serve-deploy-local.md#linux-systemd-user-unit)
与 [macOS launchd 用户代理](./docs/users/qwen-serve-deploy-local.md#macos-launchd-user-agent)。

### 2.3 Docker 容器部署

守护进程是宿主机的 Node 进程，仓库自带的 `Dockerfile` 是**沙箱镜像**、不是守护进程镜像，
所以这里自己搭一个最小容器：

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
- 经代理访问时的 Host / `--allow-origin` 规则与 [3.7 节](#37-手机--远程访问)一致。

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

## 3. 使用

### 3.1 配置模型与密钥

在会话里运行 `/auth` 选择 provider 并填入 API Key；也可以直接编辑 `settings.json`。
细节见 [认证配置](./docs/users/configuration/auth.md) 与
[设置参考](./docs/users/configuration/settings.md)。

### 3.2 终端交互与常用 slash 命令

在项目目录里运行 `qwen` 进入会话：

```bash
cd /path/to/your-project
qwen
```

常用 slash 命令：

| 命令       | 作用                           |
| ---------- | ------------------------------ |
| `/auth`    | 配置模型 provider 与密钥       |
| `/help`    | 查看全部命令                   |
| `/context` | 查看上下文占用明细             |
| `/tools`   | 查看当前可用工具               |
| `/review`  | 对改动做代码审查               |
| `/bugfix`  | 按"先复现后修复"的流程处理 bug |
| `/loop`    | 定时或按自定节奏重复执行提示   |

完整命令表见 [命令参考](./docs/users/features/commands.md)，审批模式（含 YOLO）见
[审批模式](./docs/users/features/approval-mode.md)。

### 3.3 无头模式（脚本 / CI）

```bash
qwen -p "解释这个仓库的结构" --approval-mode yolo
qwen -p "生成变更日志" --output-format stream-json
```

适合放进脚本、CI 与批处理任务，见 [无头模式](./docs/users/features/headless.md)。

### 3.4 SDK

- TypeScript：[`packages/sdk-typescript`](./packages/sdk-typescript/README.md)
- Python：[`packages/sdk-python`](./packages/sdk-python/README.md)
- Java：[`packages/sdk-java/qwencode`](./packages/sdk-java/qwencode/README.md)

### 3.5 IDE 插件

- [VS Code](./docs/users/integration-vscode.md)
- [JetBrains](./docs/users/integration-jetbrains.md)
- [Zed](./docs/users/integration-zed.md)

### 3.6 IM 渠道

先把渠道配置写进 `settings.json`，再拉起渠道进程：

```bash
qwen channel start          # 启动已启用的渠道
```

- Telegram —— [配置步骤](./docs/users/features/channels/telegram.md)
- 钉钉 —— [配置步骤](./docs/users/features/channels/dingtalk.md)
- 微信 —— [配置步骤](./docs/users/features/channels/weixin.md)
- 飞书 —— [配置步骤](./docs/users/features/channels/feishu.md)

通用概念（会话范围、Sender Policy 等）见
[渠道总览](./docs/users/features/channels/overview.md)。

### 3.7 手机 / 远程访问

- **局域网**：`qwen serve --local-control` 会打印配对二维码，手机扫码即可用 Web Shell；
  参数细节见 [CLI flags](./docs/users/qwen-serve.md#cli-flags)。
- **公网（如 nps 内网穿透）**：守护进程要绑定非 loopback 地址并带上 token，否则默认
  loopback 绑定会以 `403 Invalid Host header` 拒绝转发进来的 Host：

  ```bash
  export QWEN_SERVER_TOKEN='<token>'
  qwen serve --hostname 0.0.0.0 --port 4170 --allow-origin '<nps入口:端口>'
  ```

  终端与语音这类 WebSocket 功能必须显式加 `--allow-origin`，值取手机浏览器地址栏里的
  origin。认证、TLS 与威胁模型见
  [守护进程用户指南 · 认证](./docs/users/qwen-serve.md#authentication)。

- **iPhone 全屏运行**：用 Safari 打开后「分享」→「添加到主屏幕」，即以无地址栏的独立
  窗口运行；详见
  [把 Web Shell 安装为应用](./docs/users/qwen-serve.md#install-the-web-shell-as-an-app)。
- **更多服务端能力**：沙箱（[沙箱](./docs/users/features/sandbox.md)）、Skills
  （[技能](./docs/users/features/skills.md)）、子代理
  （[子代理](./docs/users/features/sub-agents.md)）、MCP
  （[MCP](./docs/users/features/mcp.md)）、Hooks
  （[Hooks](./docs/users/features/hooks.md)）、记忆
  （[记忆](./docs/users/features/memory.md)）、Git 工作树
  （[Git 工作树](./docs/users/features/worktree.md)）。

### 3.8 升级与卸载

```bash
scripts/qwen-serve-ctl.sh install   # 重新安装到最新版
```

卸载 CLI 见 [卸载指南](./docs/users/support/Uninstall.md)，其他问题见
[故障排查](./docs/users/support/troubleshooting.md)。
