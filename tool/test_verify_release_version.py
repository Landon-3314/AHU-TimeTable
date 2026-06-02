import json
import tempfile
import unittest
from pathlib import Path

from tool.verify_release_version import ReleaseVersionError, verify_release_version


class VerifyReleaseVersionTest(unittest.TestCase):
    def test_accepts_candidate_with_higher_build_number(self):
        with _release_files(candidate="0.3.6+3", published_codes=[1, 2]) as files:
            result = verify_release_version(files.pubspec, files.manifests)

        self.assertEqual(result.candidate_version, "0.3.6+3")
        self.assertEqual(result.candidate_code, 3)
        self.assertEqual(result.highest_published_code, 2)

    def test_rejects_duplicate_build_number(self):
        with _release_files(candidate="0.3.6+2", published_codes=[2]) as files:
            with self.assertRaisesRegex(ReleaseVersionError, "must be greater"):
                verify_release_version(files.pubspec, files.manifests)

    def test_rejects_regressed_build_number(self):
        with _release_files(candidate="0.3.6+1", published_codes=[2]) as files:
            with self.assertRaisesRegex(ReleaseVersionError, "must be greater"):
                verify_release_version(files.pubspec, files.manifests)


class _ReleaseFiles:
    def __init__(self, root: Path, candidate: str, published_codes: list[int]):
        self.pubspec = root / "pubspec.yaml"
        self.pubspec.write_text(
            f"name: timetable\nversion: {candidate}\n",
            encoding="utf-8",
        )
        self.manifests = []
        for index, code in enumerate(published_codes):
            path = root / f"published-{index}.json"
            path.write_text(
                json.dumps({"versionName": f"0.3.{code}", "versionCode": code}),
                encoding="utf-8",
            )
            self.manifests.append(path)


class _ReleaseFilesContext:
    def __init__(self, candidate: str, published_codes: list[int]):
        self.candidate = candidate
        self.published_codes = published_codes
        self.temp_directory = tempfile.TemporaryDirectory()

    def __enter__(self):
        return _ReleaseFiles(
            Path(self.temp_directory.name),
            self.candidate,
            self.published_codes,
        )

    def __exit__(self, exc_type, exc_value, traceback):
        self.temp_directory.cleanup()


def _release_files(candidate: str, published_codes: list[int]):
    return _ReleaseFilesContext(candidate, published_codes)


if __name__ == "__main__":
    unittest.main()
