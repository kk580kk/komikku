# 用 DevEco Code（ACP）执行具体开发步骤

参考文档：[BaoAgent_DevEcoCode_ACP与Agent互操作指南_v1.0](../../../../gitlab.baocloud.cn/xin3plat/LLM-INTEGRATION/baoagent-ohos/docs/current/guides/)（不同工程，仅借鉴接入方式）。

## 1. 本机复测结论（与参考文档不同）

| 检查项 | 参考文档（0.2.0/0.2.5） | 本机实测（2026-11-06，deveco 0.2.5 / devecocli 1.3.0-stable） |
|---|---|---|
| `initialize` 握手 | ✅ | ✅ 返回 `agentInfo=DevEco Code 0.2.5` |
| `session/new` | ✅ | ✅ 返回 `sessionId`（`ses_...`） |
| `session/prompt` | ❌ 零响应 | **✅ 可用**：逐 token 返回 `session/update`，最终 `stopReason=end_turn` |
| 权限请求 | 需 `/permission/{id}/reply` | ✅ `session/request_permission` 可在 stdio 内直接回复 |
| 模型 | — | `xiaomi-token-plan-cn / mimo-v2.6-pro`（agent=build） |

> 差异原因未确认（可能与版本、`--print-logs`、权限回复方式有关）。结论：**在本机可以走 ACP 派活**，不必退回 `deveco serve` 的 HTTP 轮询。

## 2. 客户端

仓库内工具：[`tools/acp/deveco_acp.py`](../../../tools/acp/deveco_acp.py)

```bash
python3 tools/acp/deveco_acp.py --cwd harmonyApp --timeout 900 \
  --transcript /tmp/acp.log "任务描述"
```

做的事：`deveco acp --print-logs`（stdio）→ `initialize` → `session/new` → `session/prompt` →
流式打印 agent 输出 → 自动批准 `session/request_permission` → 等 `stopReason` 退出。

退出码：`0` 正常 / `2` 握手失败 / `3` 建会话失败 / `4` 超时 / `5` 会话报错。

## 3. 派活模板

把「要做什么」写清楚，并且**指定自验方式**，否则它会停在"看起来完成了"：

```
你在这个 HarmonyOS ArkTS 工程里工作。请<新增/修改> <文件路径>，要求：
1. <接口签名>
2. <行为约束>
3. <复用哪些已有类型>
4. 严格遵循 ArkTS 语法限制（禁止 any、对象字面量必须有具名类型、参数必须标注类型）
5. 完成后在 harmonyApp 目录执行 ./build.sh，报错自己修到通过
6. 不要改动其它文件
完成后说明：文件路径、公开 API、复用类型、build 是否通过。
```

## 4. 落地流程（人/AI 双保险）

```
派活(ACP) → agent 改代码 → 本地 ./build.sh → git diff review → 提交
                              ↑ 不通过就带着报错再派一次
```

不直接信任 ACP 的"完成"结论：**构建结果与 diff 才是判据**。

## 5. 已知坑

1. `--print-logs` 时日志走 stderr，stdout 保持 JSON-RPC；客户端不能把两者混读。
2. 权限请求必须回 `{"outcome":{"outcome":"selected","optionId":"..."}}`；回错字段会让会话挂住。
3. agent 默认在 `--cwd` 内工作；`harmonyApp` 是独立工程，必须把 cwd 指到它，否则看不到 `entry/`。
4. `deveco` 快照功能会在工程里跑 git 命令，偶发 `failed to remove snapshot files` 警告，不影响结果。
5. 不要把 `deveco` 当构建工具：编译仍用 `./build.sh`（`hvigorw` + DevEco 自带 JBR）。
