# README 重写为部署与使用手册

状态：设计已确认（2026-10-10），待转实施计划。

## 背景

仓库根目录的 `README.md` 目前沿用上游 qwen-code 的门面结构：徽章、
Why Tay Bellow、安装、Quick Start、接口对照表、SWE-bench 评测、Ecosystem、
Privacy、Acknowledgments。它回答的是"这个开源项目是什么"，而不是
"这台机器上怎么把它跑起来、怎么用"。

本仓库是个人自用分支（远端为家庭内网 GitLab/Gitea），实际使用形态是：家里
一台主机跑 `qwen serve` 守护进程，经 nps 内网穿透让手机访问，Web Shell 添加
到 iPhone 主屏全屏运行。近期已经落地了两块配套资产：

- `scripts/qwen-serve-ctl.sh`：安装 + 守护进程管理一条龙（install / start /
  stop / restart / status / logs / token）。
- `docs/users/qwen-serve-deploy-local.md`：本地部署模板（systemd /
  launchd / tmux / nohup），已加入上述脚本的使用章节。
- `docs/developers/development/deployment.md`：通用运行/部署说明，已加入脚本
  的入口。

README 需要与这些资产对齐，成为一篇可直接照做的中文手册。

## 目标

把 `README.md` 彻底重写为**中文的部署与使用手册**，覆盖三条部署路径
（服务器/NAS、Docker、源码构建）、远程访问（nps + 手机）、日常使用、渠道
集成、运维排障，并保留精简的评测小节。

## 非目标

- 不修改 `docs/` 下任何既有页面，也不新增 docs 页面。
- 不改动任何代码、脚本或构建产物（纯文档改动）。
- 不重跑评测、不更新评测数据；仅搬运现有数据快照。
- 不翻译命令、路径、标识符、产品名（`qwen serve`、`/auth`、`QWEN_SERVER_TOKEN`
  等保持英文原样）。

## 已确认的决策

| 决策点             | 结论                                                                                                     |
| ------------------ | -------------------------------------------------------------------------------------------------------- |
| 重写程度           | 彻底重写为部署使用手册，只保留一段简短项目简介                                                           |
| 语言               | 全中文；技术术语与命令保持英文                                                                           |
| 覆盖场景           | 服务器/NAS 直接部署、nps 穿透 + 手机访问、Docker 容器、源码构建运行（四条都要）                          |
| 内容深度           | 全量手册：部署 + 日常使用 + 渠道集成 + 运维排障                                                          |
| 组织形态           | README 承载全部主线；超过约 20 行的模板/清单链到 `docs/` 既有页                                          |
| 顶部徽章           | 只留 license + Node 版本两枚；去掉 npm/downloads（指向上游包）、trendshift、多语言链接行；保留一张演示图 |
| Docker 步骤        | 全文内联在 README（约 15~20 行），**不**新建 docs 页面                                                   |
| 评测               | 保留精简配置表 + 原版本分数表 + 趋势图，作为一个小节                                                     |
| Claude Code 对比表 | 删除表格，改写为要点列表收进"能力一览"                                                                   |
| 生态列表           | 保留，压缩后收进"参考"章                                                                                 |
| 脱敏               | 一律占位符：`<NAS-IP>`、`<nps入口:端口>`、`<token>`、`~/path/to/project`；不出现真实公网地址与 token     |

## 目标结构

```
# Tay Bellow 部署与使用手册
  一行定位 + 个人自用分支说明 + 演示图

## 这是什么 · 能力一览（要点）
  删掉 Claude Code 对比表，改写为 6~8 条要点（Agentic 开箱即用、多协议、
  多端形态、开源模型与框架等）

## 目录                        ← 锚点导航

## 1. 快速开始
   1.1 安装（standalone / npm / brew / ctl 脚本 install）
   1.2 配置模型与密钥（/auth、settings）
   1.3 第一次对话（终端）

## 2. 部署
   2.1 服务器 / NAS：守护进程 + bash 脚本管理 → scripts/qwen-serve-ctl.sh
   2.2 开机自启：systemd / launchd     → 摘要 + 链 docs/users/qwen-serve-deploy-local.md
   2.3 Docker 容器部署（compose 内联）→ 注意事项：workspace 挂载、token、
       非 loopback 绑定与 Host/--allow-origin、沙箱需挂 docker.sock
   2.4 从源码构建运行（dev / build / bundle）→ 摘要 + 链 docs/developers/development/deployment.md

## 3. 手机 / 远程访问
   3.1 局域网：Local Control 二维码配对
   3.2 公网：nps 内网穿透（Host 白名单 / --allow-origin / token）
   3.3 iPhone 添加到主屏全屏运行（PWA standalone）

## 4. 日常使用
   4.1 终端交互与常用 slash 命令（精简表 → 官方文档）
   4.2 Headless / 脚本 / CI
   4.3 SDK（TypeScript / Python / Java）
   4.4 IDE 插件（VS Code / JetBrains / Zed）
   4.5 沙箱 · Skills · Workflows · SubAgents · MCP（每项 2~3 行 + 链接）

## 5. 渠道集成
   Telegram / 钉钉 / 微信 / 飞书：逐个给出"创建应用 → 填配置 →
   qwen channel start"的最小步骤，细节链 docs/users/features/channels/

## 6. 运维与排障
   6.1 升级 / 卸载
   6.2 token 轮换、日志、状态检查
   6.3 常见故障：Invalid Host header、401、端口占用、手机连不上

## 7. 评测
   精简配置表 + 版本分数表 + 趋势图

## 8. 参考
   文档地图（docs/ 索引 + 官方文档站）· 生态工具 · 许可与致谢
```

## 验收标准

1. 上述 8 个一级章节齐全，目录锚点全部可达。
2. 全文无真实内网/公网地址、无真实 token，占位符口径统一。
3. 本地 `docs/` 与 `scripts/` 相对链接逐个校验存在。
4. README 中出现的本地命令与实际实现一致（`scripts/qwen-serve-ctl.sh` 的
   install/start/stop/restart/status/logs/token 已在实现时实测）。
5. `npx prettier --check README.md` 通过。
6. 无 TODO / 占位未填 / 自相矛盾的段落。

## 验证方案

- `npx prettier --check README.md`。
- 链接核对：脚本批量检查本地相对链接（文件存在性），外链只保留官方文档站与
  仓库内已知页面。
- 通读自检两遍：结构完整性、命令可复制性、术语不翻译、脱敏无遗漏。

## 风险

- **链接漂移**：README 大量指向 `docs/` 既有页与官方文档站；官方文档站的结构
  不由本仓库控制，若上游改动会导致外链失效（缓解：外链只保留少量稳定入口，
  细节尽量指向本仓库 `docs/`）。
- **与 docs/ 重复**：Docker 步骤内联、渠道步骤在 README 里给了最小操作集，
  与 `docs/` 存在少量重叠；以 README 为"最短可跑通路径"，深度内容以 `docs/`
  为准，避免两边长期同步的负担。
- **中文锚点**：GitHub 对中文标题的锚点支持良好，但仍需在提交前逐一点击验证。
