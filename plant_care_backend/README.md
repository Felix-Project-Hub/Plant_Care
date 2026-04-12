# Plant Care Backend

## 模組簡介
提供 APP 所需 API：JWT 登入/註冊與 refresh、公告、植物與照護任務資料存取，並包含可選的 AI 任務產生端點（以環境變數串接 OpenAI 相容 API）。

## 使用技術
- FastAPI
- SQLAlchemy
- Alembic（DB migration）
- JWT（Bearer）
- PostgreSQL（部署建議）
- SQLite（本機快速測試）
- OpenAI 相容 API（`/v1/chat/completions` 或 `/chat/completions`）

## 資料夾結構
- `app/main.py`：FastAPI 入口與 router 註冊
- `app/core/`：設定、DB、JWT
- `app/models.py`：資料表模型
- `app/schemas.py`：API request/response schema
- `app/routers/`：各功能路由（`auth`、`plant`、`homepage`、`ai`）
- `scripts/`：本機測試腳本（smoke test）

## 本地開發流程
### 1) 建立虛擬環境與安裝套件

```bash
cd plant_care_backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

### 2) 套用 migration（SQLite）

```bash
DATABASE_URL=sqlite+pysqlite:///./plant_care.db JWT_SECRET=dev-secret .venv/bin/python -m alembic upgrade head
```

### 3) 啟動 API

```bash
DATABASE_URL=sqlite+pysqlite:///./plant_care.db JWT_SECRET=dev-secret .venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
```

### 4) 健康檢查

```bash
curl -s http://127.0.0.1:8000/health
```

### 5) Smoke 測試
用 SQLite in-memory 自動跑一輪主要 API（註冊、登入、refresh、植物 CRUD、AI 任務生成與更新、公告查詢）。

```bash
.venv/bin/python scripts/smoke_test.py
```

## 環境變數
參考：`.env.example`
- `DATABASE_URL`：資料庫連線字串（SQLAlchemy URL）
- `JWT_SECRET`：JWT 簽章密鑰
- `JWT_ACCESS_TTL_MINUTES`：access token 存活時間（分鐘）
- `JWT_REFRESH_TTL_DAYS`：refresh token 存活時間（天）
- `CORS_ALLOW_ORIGINS`：允許的前端來源（以逗號分隔或 `*`）
- `OPENAI_API_KEY`：AI 供應商金鑰（可留空，後端會走 fallback 任務）
- `OPENAI_BASE_URL`：OpenAI 相容 API base URL
- `OPENAI_MODEL`：使用的模型名稱（預設 `gpt-4o-mini`）
- `APP_NAME`：寄信主旨/內文使用的專案名稱
- `EMAIL_BACKEND`：寄信方式（`smtp`/`console`/`disabled`）
- `SMTP_HOST`：SMTP 主機（`EMAIL_BACKEND=smtp` 時必填）
- `SMTP_PORT`：SMTP 連接埠（預設 `587`）
- `SMTP_USERNAME`：SMTP 帳號
- `SMTP_PASSWORD`：SMTP 密碼
- `SMTP_FROM`：寄件者 Email（例如 `no-reply@your-domain.com`）
- `SMTP_FROM_NAME`：寄件者顯示名稱
- `SMTP_USE_TLS`：是否使用 STARTTLS（`true/false`）
- `SMTP_USE_SSL`：是否使用 SMTPS（`true/false`，與 TLS 二擇一）
- `SMTP_TIMEOUT_SECONDS`：SMTP 連線逾時秒數
- `.env` 僅建議本機開發使用；正式部署請改由平台環境變數注入
- `.env.example` 可公開，真實金鑰或 SMTP 密碼不要寫進 repo
- 若開發期 `.env` 曾使用真實金鑰，正式部署前請先旋轉這批憑證

## 建置 / 啟動方式
- 開發：`uvicorn app.main:app`
- 部署：`Dockerfile`
- 本機容器測試：專案內含 `docker-compose.yml`（API + PostgreSQL，並對外暴露 `8000` 與 `5433`）
- Docker build context 已透過 `.dockerignore` 排除 `.env`、`.venv`、本機 DB 與測試快取

## 部署細節
### Coolify
- 建議在 Coolify 建立 PostgreSQL，並將連線字串注入 `DATABASE_URL`
- 正式環境請使用強隨機 `JWT_SECRET`
- 建議設定 `CORS_ALLOW_ORIGINS` 鎖定前端網域（避免 `*`）
- Build context：`plant_care_backend`
- Dockerfile：`plant_care_backend/Dockerfile`
- Exposed port：`8000`
- Healthcheck path：`/health`
- 容器啟動時會先執行 migration，再啟動 API
- SMTP 相關設定為可選；若要啟用 `EMAIL_BACKEND=smtp`，請一併提供完整 SMTP 參數

### AI 供應商切換
後端使用 OpenAI 相容協定外呼，透過調整 `OPENAI_BASE_URL` 可切換供應商。
- 例：`OPENAI_BASE_URL=https://free.v36.cm` 或 `OPENAI_BASE_URL=https://api.v36.cm`

## 常見問題
- 沒有設定 `OPENAI_API_KEY` 會怎樣？
  - `/api/v1/ai/generate_tasks` 會回傳內建的預設任務，確保前端流程不被阻斷。
