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
    candidate_name: str
    candidate_code: int
    highest_published_name: str
    highest_published_code: int


@dataclass(frozen=True)
class PublishedVersion:
    name: str
    code: int


def verify_release_version(
    pubspec_path: Path,
    published_manifest_paths: Sequence[Path],
) -> ReleaseVersionResult:
    candidate_version, candidate_name, candidate_code = _read_candidate_version(
        pubspec_path
    )
    if not published_manifest_paths:
        raise ReleaseVersionError("At least one published manifest is required")

    published_versions = [
        _read_published_version(path) for path in published_manifest_paths
    ]
    highest_published_name = max(
        (version.name for version in published_versions),
        key=_version_name_key,
    )
    candidate_key = _version_name_key(candidate_name)
    highest_published_key = _version_name_key(highest_published_name)
    highest_published_code = max(
        version.code
        for version in published_versions
        if version.name == highest_published_name
    )

    if candidate_key < highest_published_key:
        raise ReleaseVersionError(
            f"Candidate versionName {candidate_name} must be newer than "
            f"published versionName {highest_published_name}"
        )

    if candidate_key == highest_published_key and candidate_code <= highest_published_code:
        raise ReleaseVersionError(
            f"Candidate versionCode {candidate_code} must be greater than "
            f"published versionCode {highest_published_code} for "
            f"versionName {candidate_name}"
        )

    return ReleaseVersionResult(
        candidate_version=candidate_version,
        candidate_name=candidate_name,
        candidate_code=candidate_code,
        highest_published_name=highest_published_name,
        highest_published_code=highest_published_code,
    )


def _read_candidate_version(pubspec_path: Path) -> tuple[str, str, int]:
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
    name = version.rsplit("+", 1)[0]
    _version_name_key(name)
    return version, name, int(code_match.group(1))


def _read_published_version(manifest_path: Path) -> PublishedVersion:
    content = json.loads(manifest_path.read_text(encoding="utf-8"))
    name = content.get("versionName") if isinstance(content, dict) else None
    if not isinstance(name, str) or not name.strip():
        raise ReleaseVersionError(
            f"Published manifest has invalid versionName: {manifest_path}"
        )
    code = content.get("versionCode") if isinstance(content, dict) else None
    if not isinstance(code, int) or isinstance(code, bool) or code <= 0:
        raise ReleaseVersionError(
            f"Published manifest has invalid versionCode: {manifest_path}"
        )
    _version_name_key(name)
    return PublishedVersion(name=name, code=code)


def _version_name_key(version_name: str) -> tuple[int, ...]:
    if not re.fullmatch(r"\d+(?:\.\d+)*", version_name):
        raise ReleaseVersionError(f"Invalid numeric versionName: {version_name}")
    return tuple(int(part) for part in version_name.split("."))


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
        f"(candidate versionName {result.candidate_name}, "
        f"published versionName {result.highest_published_name}, "
        f"published versionCode {result.highest_published_code})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
