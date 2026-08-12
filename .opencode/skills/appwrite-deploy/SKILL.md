---
name: appwrite-deploy
description: Deploy a static site or Vite app to a self-hosted Appwrite instance (Appwrite Sites). Use when the user asks to deploy, push, or ship a site/landing page to Appwrite, set up a new Appwrite site, or connect an existing project to Appwrite Sites.
---

# Appwrite Sites Deploy

Deploy a frontend (Vite, static HTML/CSS/JS, SPAs) to a self-hosted or cloud Appwrite instance using Appwrite Sites. Builds happen on Appwrite's servers (`installCommand` + `buildCommand`), then the `outputDirectory` is served over the CDN.

This skill captures a reproducible workflow, **including the fallback that is required when the installed CLI does not match the server version** (a common failure on self-hosted instances).

## Prerequisites

- Appwrite server endpoint (default: `https://appwrite.malika.ai/v1` for this team)
- An **API key** with `sites.*`, `projects.read`, `rules.read` scopes, from: Console → Project Settings → API Keys. Share it directly with the user in chat if needed (never commit it to the repo).
- Project ID of the Appwrite project (found in the Console, format `[0-9a-f]{16}`).

## Step 0 — Repo readiness

Make sure these files exist, otherwise Vite build fails on the server:

```
package.json          # scripts.build = "vite build"
vite.config.js        # base: '/', build.outDir: 'dist'
index.html            # must be at repo root
src/...
```

`dist/`, `node_modules/`, `.git/`, `.DS_Store` must be **excluded** from the uploaded archive.

## Step 1 — Configure the CLI

```bash
appwrite client --endpoint https://<your-host>/v1
appwrite client --project-id <PROJECT_ID>
# API key may be set via:
appwrite client --key "<API_KEY>"
```

Verify: `appwrite client --debug` shows endpoint + project + key.

`appwrite login` is for interactive email/password sessions and console commands. **API keys work for resource commands** (`push site`, `sites` REST calls) but not console-only commands (`list-projects`, `push settings`). If your key hits an "missing scopes" error, either widen the key scopes or fall back to REST (Step 3).

## Step 2 — Create the site (preferred: CLI)

`appwrite init site` is interactive only and errors in non-TTY sessions. Prefer the REST endpoint (also what the CLI does underneath):

```bash
curl -s -X POST "https://<host>/v1/sites" \
  -H "X-Appwrite-Project: <PROJECT_ID>" \
  -H "X-Appwrite-Key: <API_KEY>" \
  -H "Content-Type: application/json" \
  -H "X-Appwrite-Response-Format: 1.9.5" \
  -d '{ "siteId": "<SITE_ID>", "name": "<SITE_NAME>", "framework": "vite",
        "buildRuntime": "node-22", "installCommand": "npm install",
        "buildCommand": "npm run build", "outputDirectory": "dist",
        "adapter": "static" }'
```

Constraints learned from a real server (v1.8.1):

- `buildRuntime` is **mandatory** on some versions. Valid values: `node-14.5`, `node-16.0`, `node-18.0`, `node-19.0`, `node-20.0`, `node-21.0`, `node-22`, … (pick `node-22` for modern Vite).
- `adapter`: `"static"` for static/SPA sites, `"ssr"` for server-rendered frameworks.
- `siteId` is lower-case, hyphen-separated.

Site is returned; note its `$id`.

## Step 3 — Deploy code (two paths)

### Path A — CLI (works when CLI ≥ server API version)

Write `appwrite.config.json`:

```json
{
  "$schema": "https://cloud.appwrite.io/v1/config/sites",
  "projectId": "<PROJECT_ID>",
  "sites": [
    {
      "siteId": "<SITE_ID>",
      "path": "./",
      "installCommand": "npm install",
      "buildCommand": "npm run build",
      "outputDirectory": "dist"
    }
  ]
}
```

Then:

```bash
appwrite push site --all --force   # deployment with build logs streamed
```

Troubleshooting:

- `project is not set` → add `"projectId"` at the top of `appwrite.config.json`.
- `"needs an answer ... Pass --all instead"` → add `--all`.
- `"create a deployment ... Pass --force"` → add `--force`.
- `Route not found. Please ensure the endpoint is configured correctly ... for this SDK version` → the server is older than the CLI (see server error `version`). This is the #1 self-host failure. **Stop and use Path B.**

### Path B — REST fallback (server older than CLI, or scope issues)

1. Archive the repo (exclude junk — macOS `tar` adds xattr headers, which the server tolerates but warms about):

```bash
tar --exclude=node_modules --exclude=.git --exclude=dist --exclude=.DS_Store \
  -czf /tmp/site.tar.gz .
```

2. Create a deployment (uploads code, triggers server-side build):

```bash
curl -s -X POST "https://<host>/v1/sites/<SITE_ID>/deployments" \
  -H "X-Appwrite-Project: <PROJECT_ID>" \
  -H "X-Appwrite-Key: <API_KEY>" \
  -H "X-Appwrite-Response-Format: 1.9.5" \
  -F "installCommand=npm install" \
  -F "buildCommand=npm run build" \
  -F "outputDirectory=dist" \
  -F "code=@/tmp/site.tar.gz" \
  -F "activate=true"
```

Returns a deployment object; note its `$id` and initial `status` (usually `waiting`).

3. Poll until not building:

```bash
curl -s "https://<host>/v1/sites/<SITE_ID>/deployments/<DEPLOYMENT_ID>" \
  -H "X-Appwrite-Project: <PROJECT_ID>" \
  -H "X-Appwrite-Key: <API_KEY>" \
  -H "X-Appwrite-Response-Format: 1.9.5"
```

`status: "ready"` = success. `buildLogs` shows the npm/vite output; `buildSize` > 0 confirms built artifacts exist.

## Step 4 — Verify

- Re-fetch the site: `GET /v1/sites/<SITE_ID>` → `deploymentId` set and `latestDeploymentStatus: "ready"` means the deployment is active.
- Public URL for self-hosted sites is a subdomain such as `https://<SITE_ID>.<appwrite-domain>` — depends on the server's `_APP_DOMAIN_TARGET` and wildcard DNS. If DNS does not resolve, the domain/proxy was never configured; that is a server-admin step, not a deploy step.

## Security & hygiene

- **Regenerate the API key** after a session if it was shown in a chat/log.
- Never write the API key into `appwrite.config.json` or any committed file.
- Keep `appwrite.config.json` committed so future deploys are one command (`appwrite push site --all --force`) once CLI/server versions match.

## Conventions for this team/project

- Team Appwrite endpoint: `https://appwrite.malika.ai/v1`
- Project ID: `6a7bdafa002a2c16beb9`
- Existing site: `malika-homepage` (framework `vite`, runtime `node-22`, static)
- After any deploy, tell the user to regenerate the API key if it was exposed.

## Delegatable routine

When asked to "deploy to Appwrite", do end-to-end: check repo readiness → configure CLI → use **Step 2 + Path B** first (most reliable for self-hosted old servers), verify via Step 4, and report deployment ID + status to the user. Do the site existence check before deploying: `GET /v1/sites/<SITE_ID>`; if 404, create it first.