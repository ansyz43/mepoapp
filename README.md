# Meepo — iOS + Meta Channels

AI-powered sales automation platform for Instagram Direct and Facebook Messenger.

## Architecture

```
├── backend/          # FastAPI API server
├── meta_worker/      # Meta Webhooks processor + AI pipeline
├── nginx/            # Reverse proxy
├── spec/             # Technical specification
└── docker-compose.yml
```

## Quick Start

```bash
cp .env.example .env
# Edit .env with your credentials
docker compose up -d
```

## Stack

- **Backend**: FastAPI, Python 3.12, PostgreSQL 16, SQLAlchemy 2
- **AI**: OpenAI GPT, RAG, Circuit Breaker
- **Channels**: Instagram Messaging API, Facebook Messenger
- **Auth**: Email/Password, Sign in with Apple, Google OAuth
- **Deploy**: Docker Compose, Nginx, Let's Encrypt
