# meetbuddy-admin · 管理端 Web

Vue3 管理端，给运营/审核用。对应里程碑 **M6**，当前尚未开工（M0~M3 都在后端）。

## 技术栈与版本

| 项 | 选型 |
|---|---|
| 框架 | Vue 3（组合式 API） |
| 构建 | Vite |
| UI | Element Plus |
| 图表 | ECharts（看板的地域分布、活跃度曲线） |
| 路由 / 状态 | 待定，M6 开工时在 `docs/01` 补一条决策 |

本机已装 Node 24，直接跑 Vite 即可，不需要额外装全局脚手架。

## 启动（M6 开工后）

```bash
cd admin
npm install
npm run dev
```

## 与后端的约定

管理端**复用同一套鉴权**，额外加权限码校验（见 `docs/01` 第二节）。接口在 `docs/03` 第七节，全部挂在 `/admin` 前缀下：

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/dashboard` | 活跃度、匹配量、地域分布 |
| GET | `/activity/pending` | 待审核活动 |
| POST | `/activity/{id}/approve` \| `/reject` | 审核 |
| GET | `/report` | 举报列表 |
| POST | `/report/{id}/handle` | 处理，入参 approved/reason |
| POST | `/user/{id}/ban` \| `/unban` | 封禁与解封 |

错误码沿用 `docs/03` 第一节那张表，其中 4xxx 段留给管理端专用错误码，现在还是空的。

## 为什么现在只有这份 README

`docs/01` 要求「每个模块自带 README，写清启动方式和依赖版本」。后端（`server/`）已具备，这个目录先按同样的规格立住，M6 时往里填代码。
