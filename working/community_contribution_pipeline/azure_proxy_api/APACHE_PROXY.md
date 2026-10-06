# Apache reverse proxy (e.g. domain.org/validate-proxy)

The app is designed to run at the **root** of its process (e.g. `http://localhost:8080/health`). When you put it behind Apache under a path like `https://domain.org/validate-proxy`, configure Apache to **strip the path prefix** so the app still sees `/health`, `/validate`, etc.

## Recommended Apache config

Use **trailing slashes** so `/validate-proxy/` is rewritten to `/` when forwarding:

```apache
# Proxy /validate-proxy/* to the app (path prefix stripped)
ProxyPass        /validate-proxy/  http://127.0.0.1:8080/
ProxyPassReverse /validate-proxy/  http://127.0.0.1:8080/
```

Result:

| Public URL | Forwarded to app as |
|------------|----------------------|
| `https://domain.org/validate-proxy/health` | `GET /health` |
| `https://domain.org/validate-proxy/validate` | `POST /validate` |
| `https://domain.org/validate-proxy/test-connection` | `POST /test-connection` |
| `https://domain.org/validate-proxy/ip` | `GET /ip` |

No code changes are required; the app does not need a base path.

## Optional: enable proxy modules

```bash
sudo a2enmod proxy proxy_http
sudo systemctl reload apache2
```

## Client / Google Apps Script

Point your client to the full path, for example:

- Base URL: `https://domain.org/validate-proxy`
- Health: `https://domain.org/validate-proxy/health`
- Validate: `https://domain.org/validate-proxy/validate`

The app has `trust proxy` enabled so `req.ip` and `X-Forwarded-For` reflect the real client when behind Apache.
