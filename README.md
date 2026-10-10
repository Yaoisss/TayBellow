<div align="center">

[![npm version](https://img.shields.io/npm/v/@qwen-code/qwen-code.svg)](https://www.npmjs.com/package/@qwen-code/qwen-code)
[![License](https://img.shields.io/github/license/QwenLM/qwen-code.svg)](./LICENSE)
[![Node.js Version](https://img.shields.io/badge/node-%3E%3D22.0.0-brightgreen.svg)](https://nodejs.org/)
[![Downloads](https://img.shields.io/npm/dm/@qwen-code/qwen-code.svg)](https://www.npmjs.com/package/@qwen-code/qwen-code)

<a href="https://trendshift.io/repositories/15287" target="_blank"><img src="https://trendshift.io/api/badge/repositories/15287" alt="QwenLM%2Fqwen-code | Trendshift" style="width: 250px; height: 55px;" width="250" height="55"/></a>

**面向终端、编辑器、桌面、浏览器与聊天的开源 AI 编程代理。**

<a href="https://qwenlm.github.io/qwen-code-docs/zh/users/overview">中文</a> |
<a href="https://qwenlm.github.io/qwen-code-docs/de/users/overview">Deutsch</a> |
<a href="https://qwenlm.github.io/qwen-code-docs/fr/users/overview">français</a> |
<a href="https://qwenlm.github.io/qwen-code-docs/ja/users/overview">日本語</a> |
<a href="https://qwenlm.github.io/qwen-code-docs/ru/users/overview">Русский</a> |
<a href="https://qwenlm.github.io/qwen-code-docs/pt-BR/users/overview">Português (Brasil)</a> |
<a href="https://qwenlm.github.io/qwen-code-docs/ko/users/overview">한국어</a>

</div>

![Tay Bellow 在终端、桌面应用、浏览器、编辑器与聊天中的形态，以及 VS Code、Zed、JetBrains、Telegram、钉钉、微信与飞书的集成](https://img.alicdn.com/imgextra/i3/O1CN01l5GyhGuOPGC3XHtt_!!6000000005884-2-tps-1742-903.png)

## 为什么选择 Tay Bellow？

- **开箱即用的 Agentic 能力** —— 自动记忆（Auto-Memory）、自动 Skills、子代理（SubAgents）、Agent Teams 与 MCP；动态工作流，零配置。
- **彻底开源** —— 框架与 Qwen 模型均开源，二者协同演进，没有供应商锁定。
- **多协议** —— 支持 OpenAI、Anthropic、Gemini 与 Qwen API，可接任意第三方 provider 或本地模型（Ollama / vLLM），运行时可切换。
- **不止于终端** —— IDE 插件、桌面应用、Web UI、SDK，以及聊天集成（Telegram / 钉钉 / 微信 / 飞书）。

> [!TIP]
> Tay Bellow 正在用自己迭代自己 —— 用自己的代理与模型提 issue、提 PR、审代码、跑测试。社区驱动，AI 驱动。

## 安装

**Linux / macOS：**

```bash
curl -fsSL https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen-standalone.sh | bash
```

**Windows：**

```powershell
irm https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen-standalone.ps1 | iex
```

> 安装完成后请重启终端，确保环境变量生效。

<details>
<summary>NPM / Homebrew</summary>

**NPM**（需要 [Node.js 22+](https://nodejs.org/)）：

```bash
npm install -g @qwen-code/qwen-code@latest
```

**Homebrew**（macOS / Linux）：

```bash
brew install qwen-code
```

</details>

## 快速开始

在项目目录打开终端，启动 Tay Bellow：

```bash
cd /path/to/your-project
qwen
```

进入会话后运行 `/auth` 配置 provider 与 API key，然后试试：

```text
Explain this repository and show me where to start.
```

详细设置见[认证指南](https://qwenlm.github.io/qwen-code-docs/en/users/configuration/auth/)与[设置参考](https://qwenlm.github.io/qwen-code-docs/en/users/configuration/settings/)。

<details>
<summary>查看终端界面</summary>

![Tay Bellow 终端界面](https://img.alicdn.com/imgextra/i2/O1CN01K0nwj41RM1Il8kB0t_!!6000000002096-2-tps-1544-1060.png)

</details>

## 如何使用 Tay Bellow

按你的工作方式选择入口：

| 界面       | 上手方式                                                                                                                                                                                                                                                                                                                                                                                       |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **终端**   | 在项目目录运行 `qwen` —— 见[快速开始](#快速开始)。                                                                                                                                                                                                                                                                                                                                             |
| **桌面**   | 从 [Tay Bellow Desktop](https://github.com/QwenLM/qwen-code/releases/tag/desktop-latest) 下载 macOS、Windows 与 Linux 版本。                                                                                                                                                                                                                                                                   |
| **Web**    | 运行 `qwen serve --open` 在浏览器中打开 [Web UI](https://qwenlm.github.io/qwen-code-docs/en/users/qwen-serve/)。_（实验性）_                                                                                                                                                                                                                                                                   |
| **编辑器** | 配置 [VS Code](https://qwenlm.github.io/qwen-code-docs/en/users/integration-vscode/)、[Zed](https://qwenlm.github.io/qwen-code-docs/en/users/integration-zed/) 或 [JetBrains](https://qwenlm.github.io/qwen-code-docs/en/users/integration-jetbrains/)。                                                                                                                                       |
| **聊天**   | 接入 [Telegram](https://qwenlm.github.io/qwen-code-docs/en/users/features/channels/telegram/)、[钉钉](https://qwenlm.github.io/qwen-code-docs/en/users/features/channels/dingtalk/)、[微信](https://qwenlm.github.io/qwen-code-docs/en/users/features/channels/weixin/) 或 [飞书](https://qwenlm.github.io/qwen-code-docs/en/users/features/channels/feishu/)，然后运行 `qwen channel start`。 |

自动化与自定义集成：

- **无头模式** —— 在脚本、CI/CD 或批处理任务中运行 `qwen -p "..."`。
- **SDK** —— 用 [TypeScript](./packages/sdk-typescript/README.md)、[Python](./packages/sdk-python/README.md) 或 [Java](./packages/sdk-java/qwencode/README.md) 构建。
- **守护进程** —— 运行 `qwen serve`，客户端通过 HTTP + SSE（ACP）接入。_（实验性）_ [守护进程指南](https://qwenlm.github.io/qwen-code-docs/en/users/qwen-serve/)。

<details>
<summary>SDK 示例（Python）</summary>

```python
import asyncio

from qwen_code_sdk import is_sdk_result_message, query


async def main() -> None:
    result = query(
        "Summarize the repository layout.",
        {
            "cwd": "/path/to/project",
            "path_to_qwen_executable": "qwen",
        },
    )

    async for message in result:
        if is_sdk_result_message(message):
            print(message["result"])


asyncio.run(main())
```

</details>

## 能力

如果你熟悉 Claude Code，那你已经了解 Tay Bellow —— 而且不止于此。我们投入了大量精力[让 Tay Bellow 与 Claude Code 对齐功能](https://github.com/wenshao/codeagents/blob/main/docs/comparison/qwen-code-improvement-report.md)，在广度与可靠性上全面提升。

| 特性                                                         | Tay Bellow | Claude Code |
| ------------------------------------------------------------ | :--------: | :---------: |
| 子代理（SubAgents）、Agent Teams、动态工作流（Workflows）    |     ✓      |      ✓      |
| 自动记忆（Auto-Memory）、自动 Skills、Hooks                  |     ✓      |      ✓      |
| 内置 Skills（/review、/batch、/loop、/bugfix…）              |     ✓      |      ✓      |
| MCP、Plan Mode、LSP 集成                                     |     ✓      |      ✓      |
| Auto Mode、沙箱、Git 工作树                                  |     ✓      |      ✓      |
| Computer Use（桌面自动化）                                   |     ✓      |      ✓      |
| IDE 插件（VS Code / JetBrains / Zed）                        |     ✓      |      ✓      |
| SDK                                                          |     ✓      |      ✓      |
| 无头模式、会话管理                                           |     ✓      |      ✓      |
| 开源 —— 模型与框架                                           |     ✓      |      —      |
| 多协议（OpenAI / Anthropic / Gemini / Qwen + 任意 provider） |     ✓      |      —      |
| Agent Arena（同一任务上多模型正面对决）                      |     ✓      |      —      |
| 守护进程模式 —— `qwen serve`（多客户端共享一个代理）         |     ✓      |      —      |
| IM 渠道（Telegram / 钉钉 / 微信 / 飞书）                     |     ✓      |      —      |

## Tay Bellow 评测

### 评测配置

| 配置              | 值                                                                                                  |
| ----------------- | --------------------------------------------------------------------------------------------------- |
| 数据集            | `princeton-nlp/SWE-bench_Verified`，500 个用例                                                      |
| 运行次数          | 每个版本 3 次，每版本 1,500 个任务；共 7 个 Tay Bellow 版本                                         |
| 模型              | `Qwen 3.7 Max`                                                                                      |
| 采样              | `temperature=1`、`top_p=0.95`                                                                       |
| 思考 / 推理       | `interleaved_thinking=true`、`thinking_type=adaptive`、`reasoning_effort=high`                      |
| 上下文 / 输出上限 | `context_1m=true`、`model_context_length=1,000,000`、`max_tokens=64,000`、`model_max_tokens=65,535` |
| Harness 限制      | `max_iterations=500`、`runtime_timeout_sec=7,200`、`agent_timeout_multiplier=3.0`                   |

### 各版本得分

| 版本   |   平均分   | Pass Rate | pass@3 | pass^3 |
| ------ | :--------: | --------: | -----: | -----: |
| 0.0.14 | **77.80%** |     84.6% |  84.6% |  69.2% |
| 0.1.0  | **76.73%** |     84.6% |  84.6% |  68.0% |
| 0.5.0  | **76.60%** |     83.0% |  83.0% |  68.4% |
| 0.10.0 | **76.47%** |     84.4% |  84.4% |  67.4% |
| 0.15.0 | **77.67%** |     84.6% |  84.6% |  68.6% |
| 0.19.0 | **76.40%** |     85.0% |  85.0% |  65.8% |
| 0.22.0 | **77.33%** |     84.4% |  84.4% |  68.0% |

### 平均分趋势

![Tay Bellow 各版本平均分趋势](./.github/assets/qwen-code-avg-score-trend.svg)

## 生态

- [**Tay Bellow Desktop**](https://github.com/QwenLM/qwen-code/releases/tag/desktop-latest) —— 面向 macOS、Windows 与 Linux 的官方桌面应用
- [**AionUi**](https://github.com/iOfficeAI/AionUi) —— 面向命令行 AI 工具（含 Tay Bellow）的现代图形界面
- [**Gemini CLI Desktop**](https://github.com/Piebald-AI/gemini-cli-desktop) —— 面向 Tay Bellow 的跨平台桌面 / Web / 移动端 UI

- [**🦞 Tay Bellow Claw**](https://github.com/openclaw/acpx) —— 让其它代理（Claude、Codex 等）经 ACP 把编码任务委派给 Tay Bellow。把下面这段提示词粘贴进你的代理：

```text
Use Tay Bellow as a coding agent. First, fetch and read this skill reference:
https://raw.githubusercontent.com/QwenLM/qwen-code/refs/heads/main/.qwen/skills/qwen-code-claw/SKILL.md
Then follow the instructions inside to install, authenticate, and use Tay Bellow via acpx for all coding tasks.
```

- [**Aliyun Model Studio CLI**](https://github.com/modelstudioai/cli) —— 阿里云 AI 平台的官方 CLI（`bailian-cli`），为 Tay Bellow 扩展图像 / 视频生成、知识检索、应用编排与模型部署能力

## 隐私

见[服务条款与隐私声明](./docs/users/support/tos-privacy.md)，其中包含 [Chrome 扩展与 Browser Use 的数据处理](./docs/users/support/tos-privacy.md#chrome-extension-and-browser-use)。

## 贡献

欢迎贡献！指南见 [CONTRIBUTING.md](./CONTRIBUTING.md)。

## 致谢

本项目最初基于 [Google Gemini CLI](https://github.com/google-gemini/gemini-cli) v0.8.2，衷心感谢 Gemini CLI 团队的出色工作。自 Tay Bellow v0.1 起，我们停止与上游同步，开始独立开发，把 Tay Bellow 发展为面向 Qwen 及更广泛模型、具备深度集成的多协议、多平台代理框架。
