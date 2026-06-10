import argparse
import json
from pathlib import Path
from urllib.parse import unquote, urlparse


DEFAULT_R2_PUBLIC_BASE_URL = "https://download.277620035.xyz"


class StaleR2KeyError(ValueError):
    pass


def collect_stale_r2_keys(
    current_manifest_path: Path,
    manifest_dir: Path,
    r2_public_base_url: str,
) -> list[str]:
    public_base = _parse_public_base_url(r2_public_base_url)
    current_keys = set(
        _manifest_r2_apk_keys(
            current_manifest_path,
            public_base,
            ignore_invalid_manifest=False,
        )
    )

    stale_keys: set[str] = set()
    if not manifest_dir.exists():
        return []

    current_manifest_resolved = _safe_resolve(current_manifest_path)
    for manifest_path in sorted(manifest_dir.rglob("*.json")):
        if _safe_resolve(manifest_path) == current_manifest_resolved:
            continue
        for key in _manifest_r2_apk_keys(
            manifest_path,
            public_base,
            ignore_invalid_manifest=True,
        ):
            if key not in current_keys:
                stale_keys.add(key)

    return sorted(stale_keys)


def _manifest_r2_apk_keys(
    manifest_path: Path,
    public_base,
    ignore_invalid_manifest: bool,
) -> list[str]:
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        if ignore_invalid_manifest:
            return []
        raise

    if not isinstance(manifest, dict):
        if ignore_invalid_manifest:
            return []
        raise StaleR2KeyError(f"Manifest must be a JSON object: {manifest_path}")

    assets = manifest.get("assets")
    if not isinstance(assets, list):
        if ignore_invalid_manifest:
            return []
        raise StaleR2KeyError(f"Manifest assets must be an array: {manifest_path}")

    keys = []
    for asset in assets:
        if not isinstance(asset, dict):
            continue
        url = asset.get("url")
        if not isinstance(url, str):
            continue
        key = _r2_apk_key_from_url(url, public_base)
        if key is not None:
            keys.append(key)
    return keys


def _r2_apk_key_from_url(url: str, public_base) -> str | None:
    try:
        parsed_url = urlparse(url)
    except ValueError:
        return None

    base_scheme, base_netloc, base_path = public_base
    if (
        parsed_url.scheme.lower() != base_scheme
        or parsed_url.netloc.lower() != base_netloc
    ):
        return None

    if base_path:
        if parsed_url.path != base_path and not parsed_url.path.startswith(
            f"{base_path}/"
        ):
            return None
        relative_path = parsed_url.path[len(base_path) :].lstrip("/")
    else:
        relative_path = parsed_url.path.lstrip("/")

    key = unquote(relative_path)
    if not key.startswith("releases/") or not key.lower().endswith(".apk"):
        return None
    return key


def _parse_public_base_url(public_base_url: str):
    normalized = (public_base_url.strip() or DEFAULT_R2_PUBLIC_BASE_URL).rstrip("/")
    parsed = urlparse(normalized)
    if parsed.scheme.lower() not in {"http", "https"} or not parsed.netloc:
        raise StaleR2KeyError(f"Invalid R2 public base URL: {public_base_url}")
    return parsed.scheme.lower(), parsed.netloc.lower(), parsed.path.rstrip("/")


def _safe_resolve(path: Path) -> Path:
    try:
        return path.resolve()
    except OSError:
        return path.absolute()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Collect stale Cloudflare R2 APK object keys from release manifests."
    )
    parser.add_argument("--current-manifest", type=Path, required=True)
    parser.add_argument("--manifest-dir", type=Path, required=True)
    parser.add_argument(
        "--r2-public-base-url",
        default=DEFAULT_R2_PUBLIC_BASE_URL,
    )
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)

    try:
        keys = collect_stale_r2_keys(
            args.current_manifest,
            args.manifest_dir,
            args.r2_public_base_url,
        )
    except (OSError, json.JSONDecodeError, StaleR2KeyError) as error:
        parser.error(str(error))

    content = "\n".join(keys)
    if content:
        content += "\n"
    args.output.write_text(content, encoding="utf-8")
    print(f"Collected {len(keys)} stale R2 APK key(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
