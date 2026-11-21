#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT_DIR/eggs"

cat > "$ROOT_DIR/eggs/nodejs-22.json" <<'JSON'
{
  "_comment": "Generated Node.js 22 Egg for Pterodactyl 1.x. Review before importing.",
  "meta": {
    "version": "PTDL_v2",
    "update_url": null
  },
  "exported_at": "2026-11-21T00:00:00+00:00",
  "name": "Node.js 22",
  "author": "local-installer@example.invalid",
  "description": "Generic Node.js application using npm and Node.js 22.",
  "features": [],
  "docker_images": {
    "Node.js 22": "ghcr.io/parkervcp/yolks:nodejs_22"
  },
  "file_denylist": [],
  "startup": "if [[ -d .git ]] && [[ \"${AUTO_UPDATE}\" == \"1\" ]]; then git pull; fi; if [[ -f package.json ]]; then npm install; fi; node /home/container/{{ENTRY}}",
  "config": {
    "files": "{}",
    "startup": "{\n  \"done\": \"listening\"\n}",
    "logs": "{}",
    "stop": "^C"
  },
  "scripts": {
    "installation": {
      "script": "#!/bin/ash\nset -e\napk add --no-cache git",
      "container": "alpine:3.20",
      "entrypoint": "ash"
    }
  },
  "variables": [
    {
      "name": "Main file",
      "description": "JavaScript entry file, for example index.js.",
      "env_variable": "ENTRY",
      "default_value": "index.js",
      "user_viewable": true,
      "user_editable": true,
      "rules": "required|string|max:100"
    },
    {
      "name": "Auto update",
      "description": "Run git pull before starting when the server directory is a Git repository.",
      "env_variable": "AUTO_UPDATE",
      "default_value": "0",
      "user_viewable": true,
      "user_editable": true,
      "rules": "required|boolean"
    }
  ]
}
JSON

echo "[OK] Egg JSON dibuat: $ROOT_DIR/eggs/nodejs-22.json"
echo "Impor melalui Admin > Nests > Import Egg pada Panel."
echo "Pilih file nodejs-22.json. Pastikan image yolks tersedia untuk arsitektur node."
