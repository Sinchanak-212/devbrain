"""Prepare an exact patch from already-tested immutable review copies; never apply it."""
import ast
import difflib
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
evidence = root / "evidence"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def bound(path, digest):
    assert sha(path) == digest, path.name
    return json.loads(path.read_text(encoding="utf-8-sig"))

proposal = bound(evidence / "080-native-failure-combined-proposal-20261109.json",
                 "a1ae09656010cadbfc50719f2d6da22004e22a9222247f603c4178e0d4610606")
old_app = bound(evidence / "080-app-ux-snapshot-active-context.json",
                "d0a5b7e2682cd3f540fcce87446517fb8a11b6712f689aeb6df6dfbf562c771c")
old_freeze = bound(Path(old_app["freeze_manifest"]), old_app["freeze_sha256"])
new_app = bound(evidence / "080-app-native-failure-diagnostic-prepared-context-20261109.json",
                "387f9f0075a89195e52164c1e83a15261afc7847508ec3462f5f094d9404fd92")
new_freeze = bound(Path(new_app["freeze_manifest"]), new_app["freeze_sha256"])
assert new_app["freeze_sha256"] == "9e5168bece45cf3c06bd0abded7e1573b51cf55778570fdc49c8e0a8872e81b9"
old_files = {k: v for k, v in old_freeze["files"].items() if k.startswith("devbrain/")}
new_files = {k: v for k, v in new_freeze["files"].items() if k.startswith("devbrain/")}
assert len(old_files) == len(new_files) == 198 and old_files.keys() == new_files.keys()
for relative, digest in old_files.items():
    assert sha(root / relative) == digest, relative
changed = {k for k in old_files if old_files[k] != new_files[k]}
assert changed == set(proposal["files"]) and len(changed) == 8
patch = []
proof = {"scope": "reviewed_working_source_patch_preparation_only", "source_modified": False,
         "original_source_freeze": old_app["freeze_sha256"], "tested_source_freeze": new_app["freeze_sha256"],
         "old_working_files_verified": 198, "changed_files": 8, "new_tests_executed_by_this_script": False,
         "backend1605_report_sha256": "106bb67cfd1338b26041d547192cc1ba6b6939cd69ab9911c07d8bca4340430b",
         "UX425_final_report_sha256": "15af1360b7f29c161a8576a9a284750356cb2a06fc3e48a4407d558c88ca4d23",
         "native_UI_qualified": False, "release_qualified": False, "files": {}}
for relative in sorted(changed):
    entry = proposal["files"][relative]
    current = root / relative
    desired = Path(entry["proposal_path"])
    assert sha(current) == entry["baseline_sha256"] == old_files[relative]
    assert sha(desired) == entry["proposal_sha256"] == new_files[relative]
    before = current.read_bytes().decode()
    after = desired.read_bytes().decode()
    ast.parse(after)
    patch.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                     fromfile="a/" + relative, tofile="b/" + relative))
    proof["files"][relative] = {"before_sha256": old_files[relative], "after_sha256": new_files[relative]}
patch_path = evidence / "apply-reviewed-UX-TERM-working-source-20261109.patch"
with patch_path.open("xb") as stream:
    stream.write("".join(patch).encode())
proof["patch_sha256"] = sha(patch_path)
proof_path = evidence / "080-reviewed-working-source-patch-preparation-20261109.json"
with proof_path.open("xb") as stream:
    stream.write((json.dumps(proof, indent=2) + "\n").encode())
print(json.dumps({"prepared_only": True, "source_modified": False,
                  "patch_path": str(patch_path), "patch_sha256": proof["patch_sha256"],
                  "proof_path": str(proof_path), "proof_sha256": sha(proof_path)}))
