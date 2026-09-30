# Web Shell：每轮 token、时长与速率统计

[English](2026-09-24-web-shell-turn-token-stats.md) | [简体中文](2026-09-24-web-shell-turn-token-stats.zh-CN.md)

状态：已实现（2026-09-24）

## 问题

Web Shell 在 composer 工具栏显示上下文占用，在对话流内也有一行每轮汇总
（`TurnCollapseRow`），但 composer 本身对「上一次回答花了多少、流式有多快」
一无所知。`ui.showResponseTokensPerSecond` 设置项在 Web Shell 侧**完全没有消费者**：
它出现在设置面板里却毫无效果，只有终端 UI 会遵循它。

## 目标

- 每轮结束后，在输入框下方展示该轮的 token 消耗与耗时。
- 流式过程中展示实时输出速率。
- 拆分缓存命中与思考 token，并显示模型请求次数。
- 复用单一开关（已有的响应速率设置项），在 Web Shell 中默认开启，可在设置页关闭。

## 非目标

- 不展示首字延迟（TTFT）：live SSE 帧不携带该数据（它只记录在 `ui_telemetry`
  中，并经分页 replay 的 timing 帧暴露）。要加它需要新的测量与 daemon 侧 live
  帧字段——属于独立改动。
- live 路径不做逐工具耗时拆分：工具 timing 帧同样只存在于分页 replay，live 轮次
  无法在缺少新 daemon 字段的情况下把时间归因到工具。对话流内既有的折叠行仍是查看
  工具次数的地方。
- 不改动终端 UI 自身的速率展示与其默认值。

## 方案

1. **会话 mapper**
   （`packages/web-shell/client/daemon/session/mappers.ts`）—— 从主会话的 usage 帧
   累加出每轮 `DaemonTurnStats`：`inputTokens`、`outputTokens`、`thoughtTokens`、
   `cachedTokens`、`modelDurationMs`（由 live 帧的 `_meta.durationMs` 求和）、
   `requestCount`。带 `parentToolCallId` 的子代理帧继续被排除，与上下文占用计数
   口径一致。`turn_complete` / `turn_error` 把进行中的累计冻结为 `lastTurnStats`
   并清空 `turnStats`，因此失败的轮次也会报告其消耗。
2. **连接状态**
   （`daemon/session/types.ts`）—— 在 `tokenUsage` 旁新增 `turnStats`（进行中）与
   `lastTurnStats`（刚结束的一轮）。二者在 `DaemonSessionProvider` 中随会话标识
   重置，因为它们只描述 live 帧。
3. **Composer 行** —— 新组件 `TurnStatsRow` 在每轮结束后渲染于输入框下方：
   `↑12.0k (8.0k 缓存, 67%) ↓3.0k · 思考 800 · 耗时 12.0s · 250 tok/s · 3 次请求`。
   复用既有的 `formatContextTokens` 与 `turn.cached` 文案，使它与对话流内的那一行
   读起来一致。
4. **实时速率** —— `StreamingStatus` 新增 `showTokensPerSecond`，在既有
   `(12s · ↓ 1.2k tokens · esc to cancel)` 行后追加 `N tok/s`，用该轮的已流逝时间
   与既有的流式 token 估算计算。
5. **开关** —— `useShowTurnStatsEnabled` 读取
   `ui.showResponseTokensPerSecond`，只有在 user 或 workspace 显式关闭时才返回
   false。刻意**不**读 `values.effective`：它携带 daemon 默认值（为终端 UI 而设的
   关闭），会让 Web Shell 被钉死在关闭状态。
6. **挂载点** —— `ChatPane` 与主 `App` 的 composer 状态区都渲染该行，并把速率开关
   传给 `StreamingStatus`。

## 设计决策与理由

- **在 mapper 层累加，而不是从已渲染消息求和。** composer 行必须在轮次结束的瞬间
  就是正确的（包括消息仍在投影中的轮次），且它需要模型时长之和——没有任何消息
  携带该值。对话流内的折叠行保留它自己的计算。
- **不改设置的默认值。** 该设置与终端 UI 共享，关闭是那里既定的默认；为一个
  Web Shell 关注点翻转它会改变 CLI 行为。只把显式取值视为权威，就能让 Web Shell
  拥有自己的默认而不必新增第二个设置项。
- **速率 = 输出 token / 模型时长之和。** 这是终端 UI 的吞吐口径去掉它能承担的
  TTFT 扣减。当 live 帧没有时长（重放历史、更老的 daemon）时，速率被省略，而不是
  拿包含工具轮次的墙钟时间去硬算。
- **缓存与思考 token 属展示性拆分，不是新记账。** 缓存读取是输入的子集，以占比
  形式呈现，便于一眼看出高缓存命中。

## 约束

- 未打 `_meta.durationMs` 的老 daemon 只显示 token、不显示时长与速率，不会报错。
- 重连后不恢复 `lastTurnStats`（它描述的是 live 轮次）；该行消失直到下一轮结束，
  而不是显示过期数字。

## 验证计划

- Mapper 测试：跨帧累加、无 durationMs 的帧、在 `turn_complete` 与 `turn_error` 上
  冻结、无进行中轮次时不动作、排除子代理帧。
- 组件测试：`TurnStatsRow` 渲染 token、缓存占比、时长、速率与请求数；轮次进行中或
  尚无轮次时不渲染；无模型时长时省略速率与时长；省略缓存与单次请求的噪声。
  `StreamingStatus` 仅在开启时追加速率。
- 手动：在 Web Shell 中流式跑一轮，观察实时速率，轮次结束后确认 composer 汇总，
  然后关闭该设置，确认两者都消失。

## 验收标准

1. 结束的一轮在输入框下方展示其 token 消耗（输入/输出/缓存/思考）与耗时。
2. 流式中的一轮展示实时的每秒 token 数。
3. 关闭 `ui.showResponseTokensPerSecond` 会隐藏 composer 行与实时速率；终端 UI 行为
   不变。
4. 切换或重载会话不会带出上一会话的统计。

## 遗留问题

- 是否在 daemon 中测量首字时间并打到 live usage 帧上，从而提供 live TTFT（以及与
  终端 UI 等价的速率）。
