import hashlib
import re
import unittest
from pathlib import Path


class AnonymizationTest(unittest.TestCase):
    def test_repository_contains_no_origin_application_names(self):
        root = Path(__file__).resolve().parents[1]
        forbidden_hashes = {
            "0e6a8e0b849ed9b064c5a25e1ee5592f427e3eb9d250e42069ce46147d00e8d4",
            "18a87469e31161a1e8bc59979a39b3753b6a43ede62b06f1d40c3253da603848",
            "29df2cf59c04bc4566ea1c18ec7f62b7ca3c43108b0659aaecf83722bf22e1e9",
        }
        ignored = {".git", "release", "__pycache__"}
        findings: list[str] = []
        for path in root.rglob("*"):
            if not path.is_file() or any(part in ignored for part in path.parts):
                continue
            try:
                content = path.read_text(encoding="utf-8").lower()
            except UnicodeDecodeError:
                continue
            words = re.findall(r"[a-z0-9]+", content)
            candidates = words + [words[index] + words[index + 1] for index in range(len(words) - 1)]
            for candidate in candidates:
                digest = hashlib.sha256(candidate.encode()).hexdigest()
                if digest in forbidden_hashes:
                    findings.append(f"{path.relative_to(root)} contains a deployment-specific name")
        self.assertEqual([], findings)


if __name__ == "__main__":
    unittest.main()
