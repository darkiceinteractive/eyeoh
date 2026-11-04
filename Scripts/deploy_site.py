#!/usr/bin/env python3
"""Deploy EyeOh without executing unrelated entries in the local secret store."""
import argparse
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys

NAMES = {"CLOUDFLARE_API_TOKEN", "CLOUDFLARE_ADMIN_API_TOKEN", "CLOUDFLARE_ACCOUNT_ID"}


def deployment_environment(path, inherited, account):
    values = {}
    if path.is_file():
        for line in path.read_text().splitlines():
            line = line.strip()
            if line.startswith("export "):
                line = line[7:].lstrip()
            key, separator, raw = line.partition("=")
            key = key.strip()
            if not separator or key not in NAMES:
                continue
            try:
                parts = shlex.split(raw, comments=True)
            except ValueError:
                raise ValueError(f"{key} must contain one quoted or unquoted literal value.") from None
            if len(parts) > 1:
                raise ValueError(f"{key} must contain one quoted or unquoted literal value.")
            values[key] = parts[0] if parts else ""
    selected = {key: inherited.get(key) or values.get(key, "") for key in NAMES}
    result = dict(inherited)
    token = selected["CLOUDFLARE_API_TOKEN"] or selected["CLOUDFLARE_ADMIN_API_TOKEN"]
    if token:
        result["CLOUDFLARE_API_TOKEN"] = token
    else:
        result.pop("CLOUDFLARE_API_TOKEN", None)
    result["CLOUDFLARE_ACCOUNT_ID"] = selected["CLOUDFLARE_ACCOUNT_ID"] or account
    result["WRANGLER_SEND_METRICS"] = "false"
    result["CI"] = "true"
    if not result["CLOUDFLARE_ACCOUNT_ID"]:
        raise ValueError("Set account_id in Website/wrangler.jsonc before deploying.")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--credentials-file", type=Path, default=Path.home() / ".darkiceconfig/aiconfig.env")
    parser.add_argument("--preflight", action="store_true", help="Check real deployment access without uploading.")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    config = json.loads((root / "Website/wrangler.jsonc").read_text())
    deployment = json.loads((root / "Config/EyeOh-Deployment.json").read_text())
    try:
        environment = deployment_environment(args.credentials_file, os.environ, deployment.get("cloudflare_account_id", ""))
    except ValueError as error:
        sys.exit(str(error))
    executable = ["wrangler"] if shutil.which("wrangler") else ["npx", "--yes", "wrangler@4.110.0"]
    if args.preflight:
        command = executable + ["pages", "deployment", "list", "--project-name", config["name"], "--environment", "production", "--json"]
        result = subprocess.run(command, cwd=root / "Website", env=environment, capture_output=True, text=True)
        if result.returncode:
            sys.stderr.write(result.stderr)
            return result.returncode
        deployments = json.loads(result.stdout)
        print(f"Deployment access verified for {config['name']}: {len(deployments)} production deployments visible.")
        return 0
    return subprocess.run(executable + ["pages", "deploy", "dist", "--project-name", config["name"],
                                       "--branch", "main", "--commit-dirty=true"],
                          cwd=root / "Website", env=environment).returncode


if __name__ == "__main__":
    sys.exit(main())
