# 工作区浏览器：新建文件夹

[English](2026-09-24-workspace-browser-create-folder.md) | [简体中文](2026-09-24-workspace-browser-create-folder.zh-CN.md)

状态：已实现（2026-09-24）

## 问题

在 Web Shell 的「新建任务 → 选择工作区」流程中，文件夹浏览器（浏览模式下的
`AddWorkspaceDialog`）只能选择 daemon 宿主上已存在的目录。`POST /workspaces`
注册路径时会做 `realpathSync` + `stat` 校验，目录不存在即返回 `invalid_path`，
而产品中没有任何入口可以创建目录。想在一个全新项目文件夹里开始任务的用户，
必须先到 Qwen Code 之外把目录建出来。

## 目标

- 允许用户在浏览时创建单个新文件夹，随后自动进入并将其注册为工作区。
- 宿主文件系统写入面必须窄于 `POST /workspaces` 已暴露的面。
- 同时支持本机 daemon 与位置切换器中选择的远程 daemon。
- Web Shell 新于所连 daemon 时优雅降级。

## 非目标

- 不做递归 `mkdir -p`：手滑打错路径不能在宿主机上种出一棵多层目录树。
- 浏览器中不提供重命名/删除/移动。
- 不改动 TUI 与 headless 表面（终端用户可以直接 `mkdir`）。

## 方案

沿现有分层做一条纵切，完全镜像
`workspace-path-suggestions` / `remote-workspace-path-suggestions` /
`addWorkspaceToDaemon` 的既有模式：

1. **Daemon 路由** — `POST /workspace-directory-create`
   （`packages/cli/src/serve/routes/workspace-management.ts`），`mutate()` 门控。
   Body `{ path }`：非空、绝对路径、≤ `MAX_WORKSPACE_PATH_LENGTH`。语义：解析后
   目标的父目录必须存在且为目录；叶子必须不存在（`409 path_exists`）；创建是
   一次非递归 `mkdir`。成功返回
   `201 { kind: 'workspace-directory-created', path }`（归一化后的绝对路径）。
   失败：`400 invalid_path`（校验失败、父缺失、父不是目录）、`409 path_exists`、
   `500 directory_create_failed`。
2. **远程代理** — 同文件的 `POST /remote-workspace-directory-create`，复制
   `/remote-workspaces` 代理的形态：把 `{ path }` 转发给
   `<daemon>/workspace-directory-create`，以目标 daemon 的 `X-Daemon-Token`
   凭据作为 bearer，`redirect: 'error'`、代理超时 + 字节上限、
   `res.on('close')` 中止。目标解释过的失败（如 `409 path_exists`）原样透传，
   不降级成 `remote_unreachable`。
3. **SDK** — `DaemonClient.workspaceDirectoryCreate(path)`
   （`packages/sdk-typescript/src/daemon/DaemonClient.ts`），紧邻
   `workspaceDirectoryPicker` 的 `jsonRequest` `rest` 模式 POST。
4. **Web Shell action** — `daemon/workspace/actions.ts` 中的
   `createWorkspaceDirectory(path)`（`daemon/workspace/types.ts` 新增
   `DaemonWorkspaceDirectoryCreateResult`），以及
   `config/remote-workspace-add.ts` 中的 `createDirectoryOnDaemon(origin,
path)`，复用 `remoteProxyHeaders` 与 401 凭据恢复流程。
5. **对话框 UI** — `AddWorkspaceDialog` 在「上一级」按钮旁新增
   `FolderPlusIcon` 图标按钮；仅在浏览模式、非 `ssh://` 路径、且提供
   `createFolderSupported` 与 `onCreateFolder` 时可见。点击展开内联行
   （名称输入 + 创建/取消）。父目录是当前正在列出的目录：路径以分隔符结尾
   表示输入路径本身就是父目录，否则最后一段是进行中的过滤词，创建时剥掉
   （与 `GET /workspace-path-suggestions` 一致）。成功后对话框进入新目录
   （`path = created + sep`），建议列表随之刷新。Escape 关闭内联行而非整个
   对话框（扩展了 window 捕获阶段处理器）。客户端名称校验拒绝空名、路径
   分隔符与 `.`/`..`。
6. **Capability** — `workspace_directory_create` 在 `SERVE_CAPABILITY_REGISTRY`
   （`packages/cli/serve/capabilities.ts`）中注册为无条件（基线）tag。本路由
   随该版本起的每个 daemon 无条件发布，无需 toggle 接线；更老的 daemon 不广播
   该 tag，Web Shell 即隐藏入口。

## 设计决策与理由

- **父必须存在、叶子必须不存在、单层 mkdir。** 任何已认证客户端本就能注册
  任意绝对目录（`POST /workspaces` 会 stat 它），信任面没有扩大——但把创建
  限制在已存在的一层之内，可以防止打错的路径静默建出深层目录，409 也让
  双击无害。浏览列表正是让父目录可见的东西，要求父存在在实践上没有成本。
- **走代理路由而不是跨域 fetch。** 浏览器无法直连远程 daemon（CSP）；该流程
  中所有远程表面都经由页面源 daemon 的代理。创建代理复制注册代理，因为二者
  都是写操作，凭据与取消语义相同。
- **基线 capability tag，而非 toggle。** 该路由是版本门控，不是配置门控。
  条件 tag 会在 `server.ts`/`serve-features.ts` 里为一个恒真的值增加 toggle
  接线；`capabilities.ts` 中的 Map 结构是为真正可能为关的 toggle 准备的。
- **内联行而非二级对话框。** 创建动作发生在用户刚查看的目录上下文里，内联行
  把焦点和状态留在同一表面。Escape 在 window 捕获阶段拦截，因为 Radix 在
  document 捕获阶段的 Escape 会关闭对话框。

## Ownership 分类

两条新路由都是 **process-global**：它们作用于任何工作区解析之前的 daemon 宿主
文件系统，与 `GET /workspace-path-suggestions`、`POST /workspace-directory-picker`
完全一致。它们不落在任何已解析运行时内，`mutate()` 门控与
`/workspace-directory-picker` 相同。

## 约束

- 路径遵守 `MAX_WORKSPACE_PATH_LENGTH`（与注册共享）。
- Windows 上输入路径可含 `/` 与 `\`；`resolve()` 在父目录检查前归一化，响应
  返回归一化后的路径。
- 保留的 Conversations 根目录在此不做特判：在其下建目录无害，后续注册仍会
  走既有的 `conversation_workspace_reserved` 检查。

## 验证计划

- 路由单测（`workspace-management.test.ts`）：创建成功、尾分隔符归一化、
  缺失/空/相对路径、父缺失、父是文件、叶子已存在（409）、ENAMETOOLONG →
  500 `directory_create_failed`、`mutate()` 门控、代理转发与目标凭据、代理
  透传目标解释的 409。
- Web Shell 测试：`AddWorkspaceDialog.test.tsx`（入口可见性、创建并进入、
  过滤段剥离、非法名称、daemon 失败、Escape 行为）、
  `remote-workspace-add.test.ts`（代理头、返回创建路径、缺路径拒绝、401
  恢复）；App 接线由对话框级 props 覆盖。
- 手动：`npm run build && npm run bundle`、`qwen serve`，打开 Web Shell，
  新建任务 → 选择工作区 → 新建文件夹 → 创建 → 注册。

## 验收标准

1. 浏览模式 + 支持能力的 daemon 下，可以在对话框中新建文件夹并自动进入。
2. daemon 不支持（无 `workspace_directory_create`）时入口隐藏，原流程不变。
3. 创建要求父目录存在，否则可见报错；叶子已存在时可见冲突报错。
4. 位置切换器选择远程 daemon 时同一流程可用，并经代理完成认证。

## 遗留问题

无。
