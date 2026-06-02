import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence


class ReleaseVersionError(ValueError):
    pass


@dataclass(frozen=True)
class ReleaseVersionResult:
    candidate_version: str
    candidate_code: int
    highest_published_code: int


def verify_release_version(
    pubspec_path: Path,
    published_manifest_paths: Sequence[Path],
) -> ReleaseVersionResult:
    candidate_version, candidate_code = _read_candidate_version(pubspec_path)
    if not published_manifest_paths:
        raise ReleaseVersionError("At least one published manifest is required")

    published_codes = [
        _read_published_version_code(path) for path in published_manifest_paths
    ]
    highest_published_code = max(published_codes)
    if candidate_code <= highest_published_code:
        raise ReleaseVersionError(
            f"Candidate versionCode {candidate_code} must be greater than "
            f"published versionCode {highest_published_code}"
        )

    return ReleaseVersionResult(
        candidate_version=candidate_version,
        candidate_code=candidate_code,
        highest_published_code=highest_published_code,
    )


def _read_candidate_version(pubspec_path: Path) -> tuple[str, int]:
    content = pubspec_path.read_text(encoding="utf-8")
    match = re.search(r"^version:\s*(\S+)\s*$", content, re.MULTILINE)
    if match is None:
        raise ReleaseVersionError(f"Missing version in {pubspec_path}")

    version = match.group(1)
    code_match = re.search(r"\+([1-9]\d*)$", version)
    if code_match is None:
        raise ReleaseVersionError(
            f"Candidate version must end with a positive build number: {version}"
        )
    return version, int(code_match.group(1))


def _read_published_version_code(manifest_path: Path) -> int:
    content = json.loads(manifest_path.read_text(encoding="utf-8"))
    code = content.get("versionCode") if isinstance(content, dict) else None
    if not isinstance(code, int) or isinstance(code, bool) or code <= 0:
        raise ReleaseVersionError(
            f"Published manifest has invalid versionCode: {manifest_path}"
        )
    return code


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Reject Android release candidates with non-monotonic build numbers."
    )
    parser.add_argument("--pubspec", type=Path, required=True)
    parser.add_argument(
        "--published-manifest",
        action="append",
        dest="published_manifests",
        type=Path,
        required=True,
    )
    args = parser.parse_args()

    try:
        result = verify_release_version(args.pubspec, args.published_manifests)
    except (OSError, json.JSONDecodeError, ReleaseVersionError) as error:
        parser.error(str(error))

    print(
        f"Release version accepted: {result.candidate_version} "
        f"(versionCode {result.candidate_code} > "
        f"{result.highest_published_code})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
