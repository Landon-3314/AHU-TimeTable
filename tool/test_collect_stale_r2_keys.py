import json
import tempfile
import unittest
from pathlib import Path

from tool.collect_stale_r2_keys import collect_stale_r2_keys, main


R2_PUBLIC_BASE_URL = "https://download.277620035.xyz"


class CollectStaleR2KeysTest(unittest.TestCase):
    def test_collects_stale_apk_keys_and_skips_current_keys(self):
        with tempfile.TemporaryDirectory() as root:
            root_path = Path(root)
            current_manifest = root_path / "current.json"
            manifest_dir = root_path / "published"
            manifest_dir.mkdir()

            _write_manifest(
                current_manifest,
                [
                    f"{R2_PUBLIC_BASE_URL}/releases/0.3.15%2B3/"
                    "timetable-0.3.15%2B3-arm64-v8a.apk",
                ],
            )
            _write_manifest(
                manifest_dir / "old.json",
                [
                    f"{R2_PUBLIC_BASE_URL}/releases/0.3.14%2B2/"
                    "timetable-0.3.14%2B2-arm64-v8a.apk",
                    f"{R2_PUBLIC_BASE_URL}/releases/0.3.15%2B3/"
                    "timetable-0.3.15%2B3-arm64-v8a.apk",
                ],
            )

            keys = collect_stale_r2_keys(
                current_manifest,
                manifest_dir,
                R2_PUBLIC_BASE_URL,
            )

        self.assertEqual(
            keys,
            ["releases/0.3.14+2/timetable-0.3.14+2-arm64-v8a.apk"],
        )

    def test_ignores_non_matching_urls_and_non_apk_assets(self):
        with tempfile.TemporaryDirectory() as root:
            root_path = Path(root)
            current_manifest = root_path / "current.json"
            manifest_dir = root_path / "published"
            manifest_dir.mkdir()

            _write_manifest(current_manifest, [])
            _write_manifest(
                manifest_dir / "old.json",
                [
                    f"{R2_PUBLIC_BASE_URL}/releases/0.3.14%2B2/"
                    "timetable-0.3.14%2B2-arm64-v8a.apk",
                    "https://github.com/Landon-3314/AHU-TimeTable/releases/"
                    "download/v0.3.14%2B2/timetable-0.3.14%2B2-arm64-v8a.apk",
                    "https://other.example.com/releases/0.3.14%2B2/"
                    "timetable-0.3.14%2B2-x86_64.apk",
                    f"{R2_PUBLIC_BASE_URL}/releases/0.3.14%2B2/update.json",
                    f"{R2_PUBLIC_BASE_URL}/other/0.3.14%2B2/"
                    "timetable-0.3.14%2B2-armeabi-v7a.apk",
                ],
            )

            keys = collect_stale_r2_keys(
                current_manifest,
                manifest_dir,
                R2_PUBLIC_BASE_URL,
            )

        self.assertEqual(
            keys,
            ["releases/0.3.14+2/timetable-0.3.14+2-arm64-v8a.apk"],
        )

    def test_ignores_invalid_historical_manifests(self):
        with tempfile.TemporaryDirectory() as root:
            root_path = Path(root)
            current_manifest = root_path / "current.json"
            manifest_dir = root_path / "published"
            manifest_dir.mkdir()

            _write_manifest(current_manifest, [])
            (manifest_dir / "broken.json").write_text("{not-json", encoding="utf-8")
            _write_manifest(
                manifest_dir / "old.json",
                [
                    f"{R2_PUBLIC_BASE_URL}/releases/0.3.14%2B2/"
                    "timetable-0.3.14%2B2-x86_64.apk",
                ],
            )

            keys = collect_stale_r2_keys(
                current_manifest,
                manifest_dir,
                R2_PUBLIC_BASE_URL,
            )

        self.assertEqual(
            keys,
            ["releases/0.3.14+2/timetable-0.3.14+2-x86_64.apk"],
        )

    def test_cli_writes_sorted_stale_keys(self):
        with tempfile.TemporaryDirectory() as root:
            root_path = Path(root)
            current_manifest = root_path / "current.json"
            manifest_dir = root_path / "published"
            output = root_path / "stale-r2-keys.txt"
            manifest_dir.mkdir()

            _write_manifest(current_manifest, [])
            _write_manifest(
                manifest_dir / "old.json",
                [
                    f"{R2_PUBLIC_BASE_URL}/releases/0.3.14%2B2/"
                    "timetable-0.3.14%2B2-x86_64.apk",
                    f"{R2_PUBLIC_BASE_URL}/releases/0.3.14%2B2/"
                    "timetable-0.3.14%2B2-arm64-v8a.apk",
                ],
            )

            exit_code = main(
                [
                    "--current-manifest",
                    str(current_manifest),
                    "--manifest-dir",
                    str(manifest_dir),
                    "--r2-public-base-url",
                    R2_PUBLIC_BASE_URL,
                    "--output",
                    str(output),
                ]
            )

            self.assertEqual(exit_code, 0)
            self.assertEqual(
                output.read_text(encoding="utf-8").splitlines(),
                [
                    "releases/0.3.14+2/timetable-0.3.14+2-arm64-v8a.apk",
                    "releases/0.3.14+2/timetable-0.3.14+2-x86_64.apk",
                ],
            )


def _write_manifest(path: Path, urls: list[str]):
    path.write_text(
        json.dumps(
            {
                "versionName": "0.3.14",
                "versionCode": 2002,
                "assets": [
                    {"abi": str(index), "url": url}
                    for index, url in enumerate(urls)
                ],
            }
        ),
        encoding="utf-8",
    )


if __name__ == "__main__":
    unittest.main()
