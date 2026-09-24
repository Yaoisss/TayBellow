# AI_GUIDE — 代码分布与二次开发指南

> 本文档面向 **AI 辅助开发**：当你（AI 助手）在本仓库执行二次开发任务时，先读本文建立全局地图，
> 再深入目标模块。它回答三个问题：**代码在哪里、每个模块管什么、做某类改动该去哪**。
>
> - 编码规范、命令细节、核心模块门禁等强制规则见根目录 [AGENTS.md](./AGENTS.md)（必读）。
> - 英文架构详解见 [docs/developers/architecture.md](./docs/developers/architecture.md)。
> - 本文档基于 `v0.24.3`（2026-09-24）撰写。仓库结构若与本文不符，**以实际代码为准**，并建议更新本文。

## 1. 仓库总览

| 项          | 值                                                                           |
| ----------- | ---------------------------------------------------------------------------- |
| 仓库        | `@qwen-code/qwen-code`（Qwen Code CLI，monorepo）                            |
| 包管理      | pnpm workspaces（`pnpm-workspace.yaml`），脚本统一走 `npm run`               |
| 语言/运行时 | TypeScript（ESM、strict），Node.js >= 22                                     |
| 测试        | vitest（单测与源码同置，`file.test.ts`）；集成测试在 `integration-tests/`    |
| UI 技术     | 交互 TUI 基于 Ink / OpenTUI（React）；Web 端为 React（`packages/web-shell`） |

**两种执行模型**（详见 architecture.md）：

1. **直接执行**：交互 TUI / headless CLI 直接构建并运行 agent runtime。
2. **ACP 执行**：`qwen --acp` 把 agent 挂在 ACP（Agent Client Protocol）传输之后，
   由 `qwen serve`（HTTP + SSE daemon）通过共享 ACP bridge 驱动，支撑 Web Shell、IDE、
   消息渠道等多个客户端。

依赖主干：**UI 表面 → 宿主进程（cli / sdk / serve / acp-bridge）→ core 运行时 → 外部系统（模型 Provider、MCP、工作区文件系统）**。

## 2. 根目录文件夹分布

| 路径                 | 职责                                                                                                                                               |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `packages/`          | 全部 npm workspace 包（CLI、core、SDK、各端壳与集成），见第 3 节                                                                                   |
| `integrations/`      | 独立的扩展集成包：`external-context`（Provider 绑定外部上下文）、`external-context-mem0`（Mem0 兼容实现）                                          |
| `integration-tests/` | E2E / 集成测试（CLI、interactive、SDK、sandbox、terminal-bench 等场景）                                                                            |
| `scripts/`           | 构建、打包、发布、校验与仓库维护自动化（`build.js`、`start.js`、`dev.js`、`check-*.js` 等）                                                        |
| `docs/`              | 文档：`users/`（用户文档）、`developers/`（开发者文档 + daemon/tools 子文档）、`design/`（设计文档，中英双语）、`plans/`（实施计划）、`e2e-tests/` |
| `docs-site/`         | 文档站点                                                                                                                                           |
| `patches/`           | `patch-package` 第三方补丁（`postinstall` 时应用）                                                                                                 |
| `eslint-rules/`      | 仓库自定义 ESLint 规则                                                                                                                             |
| `.github/`           | CI 工作流与 PR/issue 模板                                                                                                                          |

根目录关键配置文件：`package.json`（workspace 与脚本）、`pnpm-workspace.yaml`、`pnpm-lock.yaml`、
`tsconfig.json`、`eslint.config.js`（+ `eslint.legacy-*.mjs` 允许清单）、`esbuild.config.js`（bundle）、
`vitest.config.ts`、`Makefile`、`Dockerfile`、`.prettierrc.json`、`.nvmrc`。

根目录文档：`README.md`、`AGENTS.md`（开发规范，AI 必读）、`CLAUDE.md`、`CONTRIBUTING.md`、`SECURITY.md`、`CHANGELOG.md`。

## 3. packages 包级分布地图

### 3.1 核心链路（改动的绝大多数落点）

| 包                        | npm 名                      | 职责                                                                                                                                                                                   |
| ------------------------- | --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `packages/core`           | `@qwen-code/qwen-code-core` | UI 无关的 agent 编排核心：模型请求、上下文构建、工具注册与执行、权限、会话、记忆、遥测（内部模块见第 4 节）                                                                            |
| `packages/cli`            | `@qwen-code/qwen-code`      | `qwen` 可执行入口：参数解析、配置装配、Ink TUI、headless 输出、ACP 入口、`qwen serve` daemon（内部模块见第 5 节）                                                                      |
| `packages/acp-bridge`     | `@qwen-code/acp-bridge`     | 共享 ACP bridge 核心：`createHttpAcpBridge` 工厂、`BridgeClient`、`EventBus`/`AcpChannel`、权限中介（PermissionMediator）、进程 spawn 与文件系统注入缝，被 serve/channels/IDE/TUI 复用 |
| `packages/sdk-typescript` | `@qwen-code/sdk`            | TypeScript SDK：`query()` 进程客户端 + `qwen serve` 的 HTTP/SSE 客户端与会话事件投影                                                                                                   |
| `packages/web-shell`      | `@qwen-code/web-shell`      | 浏览器 UI 与 daemon 的 React 适配层（providers/hooks + 组件库，构建于 SDK 之上）                                                                                                       |
| `packages/web-templates`  | `@qwen-code/web-templates`  | 打包为可嵌入 JS/CSS 字符串的 Web 模板                                                                                                                                                  |

### 3.2 客户端与设备表面

| 包                              | 职责                                                        |
| ------------------------------- | ----------------------------------------------------------- |
| `packages/desktop-shell`        | 桌面应用壳（Tauri 2；`src-tauri/` Rust + Web Shell 运行时） |
| `packages/mobile-shell`         | Android WebView 壳                                          |
| `packages/vscode-ide-companion` | VS Code 扩展（IDE 集成面板）                                |
| `packages/chrome-extension`     | Chrome 扩展桥（AI 驱动浏览器交互）                          |
| `packages/zed-extension`        | Zed 编辑器扩展（`extension.toml`，Rust）                    |
| `packages/live-host`            | macOS 原生音频与全局快捷键宿主（Live 语音）                 |
| `packages/audio-capture`        | 语音输入的原生麦克风采集后端                                |
| `packages/qwen-live`            | 独立 Live 语音 daemon：实时语音控制面，编排 Qwen Code 会话  |

### 3.3 工具型与 SDK 扩展

| 包                     | 职责                                                                                 |
| ---------------------- | ------------------------------------------------------------------------------------ |
| `packages/cua-driver`  | Computer Use 驱动（`rust/` + `typescript/` + `python/` 多语言实现，经 MCP 边界暴露） |
| `packages/mobile-mcp`  | 移动设备 MCP（支持相对坐标）                                                         |
| `packages/node-repl`   | 独立 MCP server：会话持久 Node.js REPL（`node_repl`），独立于 core                   |
| `packages/browser-use` | Browser Use SDK（供 Node REPL 使用）                                                 |
| `packages/sdk-python`  | Python SDK（`pyproject.toml`，pytest + mypy + ruff）                                 |
| `packages/sdk-java`    | Java SDK（`client/`、`qwencode/`、`runtime-broker/` 三个模块）                       |

### 3.4 消息渠道（`packages/channels/`）

`channels/base`（`@qwen-code/channel-base`）是渠道共享基础设施；其余为各平台适配器，
新渠道应继承 base 并参考 `plugin-example`：

`telegram`、`weixin`（微信）、`wecom`（企业微信）、`dingtalk`（钉钉）、`dws`（钉钉 Workspace）、
`feishu`（飞书/Lark）、`qqbot`（QQ 机器人）、`github`（轮询）、`gitlab`（轮询）、`plugin-example`（示例插件）。

渠道插件开发指南：[docs/developers/channel-plugins.md](./docs/developers/channel-plugins.md)。

## 4. `packages/core/src` 内部模块分布

core 是 agent 运行时，**不决定展示与传输**。目录按职责分组：

### 4.1 agent 主循环与模型层

| 目录/文件               | 职责                                                                                                                                                            |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `core/`                 | agent 主循环：`client.ts`（对话循环）、`coreToolScheduler.ts`（工具调用调度）、`contentGenerator.ts`、`geminiChat.ts`、`llm-chat.ts`/`llm-request.ts`、消息缓冲 |
| `qwen/`                 | Qwen 专属：`qwenOAuth2.ts`（OAuth 认证）、`qwenContentGenerator.ts`、共享 token 管理                                                                            |
| `providers/`、`models/` | 模型 Provider 集成与模型定义/能力（新增模型、reasoning 配置在此）                                                                                               |
| `prompts/`              | 系统提示词与上下文组装                                                                                                                                          |
| `code-mode/`            | code-mode（脚本化批量工具调用）相关                                                                                                                             |

### 4.2 工具与扩展面

| 目录/文件                                      | 职责                                                                                                                                                                                                                                                                                                                                                          |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tools/`                                       | 全部内置工具实现（`read-file`、`write-file`、`edit`、`grep`、`glob`、`ls`、`shell`、`web-fetch`、`web-search`、`todoWrite`、`task-*`/`team-*`、`enter/exit-worktree`、`skill`、`cron-*`、`monitor`、`loop-wakeup`、`send-message`、`askUserQuestion`、`enter/exitPlanMode`…）+ 工具注册表 `tool-registry.ts` 与 MCP 客户端（`mcp-client*.ts`、`mcp-tool.ts`） |
| `mcp/`                                         | MCP server 管理、资源与发现                                                                                                                                                                                                                                                                                                                                   |
| `skills/`                                      | skill 加载与执行                                                                                                                                                                                                                                                                                                                                              |
| `subagents/`、`agents/`、`subagent-runtime.ts` | 子代理定义与运行时（fork、后台代理）                                                                                                                                                                                                                                                                                                                          |
| `extension/`                                   | 扩展系统（加载扩展提供的命令/工具/MCP）                                                                                                                                                                                                                                                                                                                       |
| `hooks/`                                       | hooks 系统（生命周期钩子）                                                                                                                                                                                                                                                                                                                                    |

### 4.3 服务与基础设施

| 目录/文件                                 | 职责                                                                                                                                                                                                                                                                         |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `services/`                               | 会话与执行基础设施：`sessionService.ts`、`shellExecutionService.ts`、`gitWorktreeService.ts`、`cronScheduler.ts`、`fileHistoryService.ts`、`chatRecordingService.ts`、`loopDetectionService.ts`、`tokenUsageService.ts`、`ssh-workspace*.ts`、`execution-environment*.ts` 等 |
| `config/`                                 | 配置解析与 settings 模型（settings schema 由 `scripts/generate-settings-schema.ts` 生成）                                                                                                                                                                                    |
| `permissions/`                            | 权限策略与校验                                                                                                                                                                                                                                                               |
| `confirmation-bus/`                       | 工具确认（approval）总线                                                                                                                                                                                                                                                     |
| `sandbox/`                                | 沙箱执行（docker/podman、macOS seatbelt、Linux 内核沙箱）                                                                                                                                                                                                                    |
| `memory/`                                 | 记忆（auto memory）系统                                                                                                                                                                                                                                                      |
| `telemetry/`                              | OpenTelemetry 埋点与 span                                                                                                                                                                                                                                                    |
| `lsp/`                                    | LSP 集成                                                                                                                                                                                                                                                                     |
| `ide/`                                    | IDE companion 连接（vscode/neovim 上下文）                                                                                                                                                                                                                                   |
| `ipc/`、`output/`、`resources/`、`utils/` | 进程间通信、输出流、资源、通用工具                                                                                                                                                                                                                                           |
| `goals/`                                  | Goal（长期目标）运行时                                                                                                                                                                                                                                                       |
| `followup/`                               | 后续建议与推测执行（speculation、overlayFs）                                                                                                                                                                                                                                 |
| `omni/`                                   | 多模态媒体管理：上传/下载、ffmpeg、媒体存储与 GC、识别、媒体记忆召回                                                                                                                                                                                                         |
| `managed-runtime/`                        | 托管会话记录（managed session records）                                                                                                                                                                                                                                      |
| `index.ts`                                | 包公共出口（注意：cli 生产代码应从**定义模块的子路径**导入，而非包根 barrel，见第 6 节）                                                                                                                                                                                     |

## 5. `packages/cli/src` 内部模块分布

cli 拥有 `qwen` 可执行入口，并根据参数选择运行模式：

| 目录/文件                                                               | 职责                                                                                                                                                                                                                                    |
| ----------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cli.ts`、`startup/`                                                    | 入口与启动流程（参数解析、配置装配、模式分发）                                                                                                                                                                                          |
| `ui/`                                                                   | 交互 TUI（React + Ink；`opentui/` 为并行 OpenTUI 渲染器）：`App.tsx`、`components/`、`contexts/`、`themes/`、`hooks/`、`state/`、`commands/`、`voice/` 等                                                                               |
| `nonInteractive.ts`、`nonInteractive/`                                  | headless（非交互）执行模式                                                                                                                                                                                                              |
| `serve/`                                                                | `qwen serve` daemon：`server/`、`routes/`（全部 REST 路由，按 `workspace-*`/`session-*` 等命名）、`workspace-registry.ts`（多工作区注册）、`channel-worker-*`（渠道工作进程管理）、`acp-http/`、`auth/`、`sandbox.*`、`live/`、`voice/` |
| `commands/`                                                             | 内置命令实现（`auth`、`board`、`channel`、`extensions`、`mcp`、`review`、`sandbox`、`serve`、`sessions`、`update`、`hooks`）                                                                                                            |
| `services/`                                                             | 命令加载体系：`CommandService.ts`、`BuiltinCommandLoader.ts`、`FileCommandLoader.ts`（markdown 自定义命令）、`SkillCommandLoader.ts`、`McpPromptLoader.ts`；另有语音服务                                                                |
| `acp-integration/`                                                      | `qwen --acp` 模式接入                                                                                                                                                                                                                   |
| `config/`                                                               | CLI 侧配置装配（合并 CLI 参数/环境变量/用户与工作区设置）                                                                                                                                                                               |
| `core/`                                                                 | `auth.ts`、`initializer.ts`、`theme.ts`                                                                                                                                                                                                 |
| `runtime/`                                                              | 运行期辅助：渠道投递 IPC、定时任务执行、workspace memory 辅助                                                                                                                                                                           |
| `external-agents/`                                                      | 外部 agent 适配（codex / claude-code 子代理）                                                                                                                                                                                           |
| `peerMessaging/`、`remoteInput/`                                        | 跨会话消息（peer messaging）与远程输入                                                                                                                                                                                                  |
| `i18n/`                                                                 | 国际化文案（`npm run check-i18n` 校验）                                                                                                                                                                                                 |
| `dualOutput/`、`export/`、`hooks/`、`agent-view/`、`patches/`、`utils/` | 双输出桥、会话导出、CLI hooks、代理视图、补丁、工具函数                                                                                                                                                                                 |

## 6. 依赖方向与边界规则

```
UI 表面（TUI / Web Shell / IDE / channels）
        │
宿主层（cli 直接执行 ｜ sdk-typescript / qwen serve / acp-bridge 经 ACP 子进程）
        │
core 运行时 ── 模型 Provider / MCP / 工作区文件系统
```

强制规则（完整版见 [AGENTS.md](./AGENTS.md)，违者 CI 会挂）：

1. **跨包只能走公共导出**，禁止相对路径进入其他包的源码树。
2. **cli 生产代码导入 core 必须从定义模块的子路径**（如
   `@qwen-code/qwen-code-core/utils/debugLogger.js`），不要从包根 barrel 导入——
   barrel 会在测试中拉起整个 core。历史遗留文件见 `eslint.legacy-core-barrel-imports.mjs` 允许清单，只减不增。
3. **core 是架构骨干，受两级门禁**：外部 PR 触碰 `packages/core/src/**`、`*/auth|providers|models|config|tools|services/**`
   的大规模 `refactor`（500+ 生产行）会被硬拒；小改动必须 100% 确定、能点名所有下游消费者，否则升级给维护者。
4. 命名：`packages/core`、`packages/cli` 的 `.ts` 用 **kebab-case**，React 组件用 **PascalCase.tsx**；
   测试与源码同置为 `file.test.ts`。
5. 平台专属逻辑放 adapter（IDE/渠道/壳），共享 agent 行为放 core，传输行为放 acp-bridge/SDK/daemon。
6. Web Shell 开发遵循 AGENTS.md 中"Web Shell UI development"一节（复用 `components/ui` 原语、
   portal 根、CSS 隔离、React 18/19 双兼容）。

## 7. 常见二次开发场景速查

接到任务后先对号入座，再读对应目录的相邻实现做参照：

| 任务类型               | 改动落点                                                     | 参照/配套                                                                                                                                                                              |
| ---------------------- | ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 新增/修改内置工具      | `packages/core/src/tools/`（新文件 + 同置 `.test.ts`）       | 注册进 `tool-registry.ts`；工具开发指南 `docs/developers/tools/`                                                                                                                       |
| 修改 TUI 界面/交互     | `packages/cli/src/ui/`                                       | Ink 为主渲染器；改动后留意 `opentui/` 渲染器对齐（有 parity 测试）                                                                                                                     |
| 新增 slash 命令        | `packages/cli/src/commands/` + `ui/commands/`（如需 UI）     | 经 `services/` 的 loader 体系接入                                                                                                                                                      |
| 新增消息渠道           | `packages/channels/<platform>/`                              | 继承 `channels/base`，参考 `plugin-example`；指南 `docs/developers/channel-plugins.md`                                                                                                 |
| 新增 daemon REST 路由  | `packages/cli/src/serve/routes/`                             | 命名遵循 `workspace-*`/`session-*` 惯例；协议见 `docs/developers/qwen-serve-protocol.md` 与 `daemon-rest-api.openapi.json`；先给路由做 ownership 分类（见 AGENTS.md Code Review 一节） |
| 新增配置/settings 项   | `packages/core/src/config/`                                  | 运行 `npm run generate:settings-schema` 更新 schema；用户文档 `docs/users/configuration/`                                                                                              |
| 模型 Provider / 新模型 | `packages/core/src/providers/` + `models/`                   | 认证相关在 `core/src/qwen/`（Qwen OAuth）                                                                                                                                              |
| MCP 集成               | `packages/core/src/mcp/` + `tools/mcp-client*`               | 传输池、发现、会话元数据热加载都在此                                                                                                                                                   |
| Web Shell 功能         | `packages/web-shell/src`（client 组件 + daemon 适配）        | 复用 `components/ui` 原语，勿重复造轮子                                                                                                                                                |
| SDK 能力               | `packages/sdk-typescript/src`（或 `sdk-python`、`sdk-java`） | 对应集成测试在 `integration-tests/sdk-typescript/` 等                                                                                                                                  |
| 子代理 / 外部 agent    | `packages/core/src/subagents/`、`cli/src/external-agents/`   | fork/后台代理设计见 `docs/design/`                                                                                                                                                     |
| 行为变更               | 先写设计文档                                                 | `docs/design/`（英文 + `.zh-CN.md` 双语，要求见 `docs/design/README.md`）；用户可感知行为需写 E2E 计划到 `.qwen/e2e-tests/`                                                            |

## 8. 构建与验证命令

```bash
# 安装（必须用 corepack pnpm + frozen lockfile；CI 同款）
corepack pnpm install --frozen-lockfile

# 构建 / 本地开发（tsx 直跑源码，改 core/cli 即时生效）
npm run build
npm run dev

# 单测：必须在对应包目录内运行，优先跑单个文件
cd packages/core && npx vitest run src/path/to/file.test.ts
cd packages/cli && npx vitest run src/path/to/file.test.ts

# 静态检查
npm run lint          # ESLint
npm run typecheck     # TypeScript
npm run format        # Prettier

# 集成测试（先构建 + bundle）
npm run build && npm run bundle
npm run test:integration:cli:sandbox:none
npm run test:integration:interactive:sandbox:none
```

**Gotcha（来自 AGENTS.md，踩过坑的）**：

- `npm run test -- --filter=...` **不会**过滤，会跑全量；`npx vitest` 也不要在仓库根目录跑（各包 vitest 配置独立）。
- 新 clone / 新 worktree 的包测试依赖 workspace 包的 `dist/` 产物；缺了先在仓库根 `npm run build`。
  worktree 可用 `node scripts/setup-worktree.js` 共享安装（跳过 prepare 构建，之后仍需 `npm run build`）。
- 依赖变更必须编辑 manifest 后用 `corepack pnpm` 安装并提交 `pnpm-lock.yaml`，否则 CI `--frozen-lockfile` 直接失败。
- CLI 测试中被 `vi.mock()` 消费的 mock 要用 `vi.hoisted()`。

**声明完成前的最低验证**：改动涉及的包 `npm run build && npm run typecheck` + 相关单测文件全绿；
提交信息遵循 Conventional Commits（如 `feat(cli): Add --json flag`）。

## 9. 深入文档索引

| 文档                                                                                                   | 内容                                                           |
| ------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------- |
| [AGENTS.md](./AGENTS.md)                                                                               | 开发原则、命令全集、代码规范、review 规则（AI 每次任务前应读） |
| [docs/developers/architecture.md](./docs/developers/architecture.md)                                   | 架构总览：运行时边界、两种执行流、扩展点（英文）               |
| [docs/developers/daemon/00-index.md](./docs/developers/daemon/00-index.md)                             | `qwen serve` daemon 内部：进程拓扑、信任边界、事件回放         |
| [docs/developers/qwen-serve-protocol.md](./docs/developers/qwen-serve-protocol.md)                     | serve 的 HTTP/SSE 协议参考                                     |
| [docs/developers/channel-plugins.md](./docs/developers/channel-plugins.md)                             | 渠道插件开发指南与运行模式                                     |
| [docs/developers/tools/introduction.md](./docs/developers/tools/introduction.md)                       | 工具开发指南                                                   |
| [docs/developers/development/integration-tests.md](./docs/developers/development/integration-tests.md) | 集成测试指南                                                   |
| [docs/design/README.md](./docs/design/README.md)                                                       | 设计文档撰写要求（中英双语）                                   |
| [packages/acp-bridge/README.md](./packages/acp-bridge/README.md)                                       | ACP bridge 公共入口                                            |
| [packages/sdk-typescript/README.md](./packages/sdk-typescript/README.md)                               | TypeScript SDK 用法                                            |
| [docs/users/](./docs/users/overview.md)                                                                | 用户文档（quickstart、configuration、features）                |
