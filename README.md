# FastAPI Backend

## 运行（本地）

```bash
python -m venv .venv
.venv\Scripts\activate
python -m pip install -U pip
pip install -r requirements.txt
copy .env.example .env
uvicorn main:app --reload
```

访问：
- http://127.0.0.1:8000/health
- http://127.0.0.1:8000/docs

