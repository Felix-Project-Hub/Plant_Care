# Plant Care

## 專案名稱
Plant Care

## 專案簡介
本專案包含一個 Flutter APP（`plant_care_app`）與一個後端 API（`plant_care_backend`）。
後端提供 JWT 登入/註冊、公告、植物與照護任務資料存取，以及可選的 AI 任務產生功能（透過環境變數串接 OpenAI 相容 API）。

## 功能列表
- 使用者註冊 / 登入（`access token` + `refresh token`）
- 公告列表
- 植物建立 / 列表 / 每日初始化（今日狀態、最後澆水時間）
- 任務勾選與同步
- AI 任務產生（未設定 `OPENAI_API_KEY` 時回傳內建預設任務）

## 技術架構
- 前端：Flutter（Dart）
- 後端：FastAPI（Python）
- 資料庫：PostgreSQL（本機開發與部署主要方案），SQLite（僅供快速測試）
- 認證：JWT（Bearer）
- AI：OpenAI 相容 API（`/v1/chat/completions` 或 `/chat/completions`）

## 專案結構
- `plant_care_app/`：Flutter APP
- `plant_care_backend/`：FastAPI 後端

## 本地測試教學
### 後端（PostgreSQL + Uvicorn）
1) 安裝依賴

```bash
cd plant_care_backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

2) 啟動 PostgreSQL（需先啟動 Docker Desktop 或其他可用的 Docker daemon）

```bash
cd plant_care_backend
docker compose up -d db
```

3) 套用 migration

```bash
DATABASE_URL=postgresql+psycopg://plant_care:plant_care@localhost:5433/plant_care JWT_SECRET=dev-secret .venv/bin/python -m alembic upgrade head
```

4) 啟動 API

```bash
DATABASE_URL=postgresql+psycopg://plant_care:plant_care@localhost:5433/plant_care JWT_SECRET=dev-secret .venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
```

5) 健康檢查

```bash
curl -s http://127.0.0.1:8000/health
```

6) 端到端 smoke 測試（不需要真的連 AI；未設定 `OPENAI_API_KEY` 時會走 fallback）

```bash
.venv/bin/python scripts/smoke_test.py
```

註：`scripts/smoke_test.py` 預設使用 SQLite in-memory，不會依賴本機 PostgreSQL。

### 前端（Flutter）
1) 安裝依賴與靜態檢查

```bash
cd plant_care_app
flutter pub get
flutter analyze
flutter test
```

2) 啟動（macOS）

```bash
flutter run -d macos --dart-define=API_BASE_URL=http://localhost:8000
```

## 環境變數
### 前端（編譯期參數）
- `API_BASE_URL`：後端 base URL（預設 `http://localhost:8000`）

### 後端（建議以環境變數或 `.env` 注入）
參考：`plant_care_backend/.env.example`
- `DATABASE_URL`：資料庫連線字串
- `JWT_SECRET`：JWT 簽章密鑰
- `JWT_ACCESS_TTL_MINUTES`：access token 存活時間（分鐘）
- `JWT_REFRESH_TTL_DAYS`：refresh token 存活時間（天）
- `CORS_ALLOW_ORIGINS`：允許的前端來源（以逗號分隔或 `*`）
- `OPENAI_API_KEY`：AI 供應商金鑰（可留空，後端會自動回傳 fallback 任務）
- `OPENAI_BASE_URL`：OpenAI 相容 API base URL
- `OPENAI_MODEL`：使用的模型名稱（預設 `gpt-4o-mini`）

## GitHub 上傳建議
- 可以上傳：原始碼、平台專案檔、`pubspec.lock`、`Podfile.lock`、Alembic migration、`Dockerfile`、`docker-compose.yml`、README。
- 不要上傳：任何 `.env`、`plant_care_backend/.venv/`、本機資料庫、Flutter `build/`、`.dart_tool/`、`.metadata`、IDE 暫存與測試/覆蓋率產物。
- `plant_care_backend/.env` 僅供本機使用；正式部署請改由 Coolify 環境變數注入。
- 若 `.env` 曾放過真實金鑰或 SMTP 密碼，部署前請先旋轉這些憑證。

## Coolify 部署教學
### 後端服務
- Build context：`plant_care_backend`
- Dockerfile：`plant_care_backend/Dockerfile`
- Exposed port：`8000`
- Healthcheck path：`/health`
- 容器啟動流程：`entrypoint.sh` 會先執行 `alembic upgrade head`，再啟動 `uvicorn`
- 建議將 `plant_care_backend/.env` 留在本機，不要上傳；正式值統一在 Coolify 的環境變數介面設定

### 建議的後端環境變數
- 必填：`DATABASE_URL`、`JWT_SECRET`
- 建議：`CORS_ALLOW_ORIGINS`（正式環境請不要用 `*`）
- 可選（AI）：`OPENAI_API_KEY`、`OPENAI_BASE_URL`、`OPENAI_MODEL`
- 可選（寄信）：`EMAIL_BACKEND`、`SMTP_HOST`、`SMTP_PORT`、`SMTP_USERNAME`、`SMTP_PASSWORD`、`SMTP_FROM`、`SMTP_FROM_NAME`
- 正式環境請務必使用強隨機 `JWT_SECRET`，不要保留 `change-me` 類型的 placeholder

### AI 串接與更換供應商
- 本專案後端使用「OpenAI 相容協定」呼叫 AI，因此只要供應商支援該協定即可透過調整 `OPENAI_BASE_URL` 切換。
- 例：`OPENAI_BASE_URL=https://free.v36.cm` 或 `OPENAI_BASE_URL=https://api.v36.cm`

## 正式建置範例
### Android APK
```bash
cd plant_care_app
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com
```

### iOS（不簽章）
```bash
cd plant_care_app
flutter build ios --no-codesign --dart-define=API_BASE_URL=https://api.example.com
```

### Android release 簽章
- `plant_care_app/android/key.properties` 不要進 Git；可參考 `plant_care_app/android/key.properties.example`
- 若未提供 `key.properties`，Android release 會退回 debug signing，僅適合本機驗證，不適合正式上架

## 前端 / 後端詳細文件連結
- 前端：[plant_care_app/README.md](https://github.com/Felix-Project-Hub/Plant_Care/blob/main/plant_care_app/README.md)
- 後端：[plant_care_backend/README.md](https://github.com/Felix-Project-Hub/Plant_Care/blob/main/plant_care_backend/README.md)
