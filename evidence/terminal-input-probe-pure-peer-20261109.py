"""Windows-only pure fixtures and immutable-file review. Never runs the probe body."""
import ast
import hashlib
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
source = root / "evidence/terminal-input-probe-20261109.py"
expected = "7043d4a3beb8ef99aad68f3c681e1f13f61c27cee5f34fc948d1cf7a6aa46c06"
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
assert sha(source) == expected
tree = ast.parse(source.read_text(encoding="utf-8"))
pure = ast.Module(body=[node for node in tree.body if isinstance(node, (ast.ClassDef, ast.FunctionDef))
                       and node.name in {"require", "ControlClassifier"}], type_ignores=[])
assert len(pure.body) == 2
namespace = {"re": re}
exec(compile(pure, "<selected-pure-classifier-only>", "exec"), namespace)
Classifier = namespace["ControlClassifier"]
rows = []
def record(name, passed):
    assert passed, name
    rows.append({"name": name, "passed": True})

reply = b"\x1b[?1u\x1b[?64;1;2c\x1b[1;1R\x1b]10;rgb:eeee/eeee/eeee\x07\x1b]11;rgb:1111/1111/1111\x1b\\"
whole = Classifier()
whole.feed(reply, .1)
summary = whole.summary()
record("five_complete_reply_classes", len(summary["control_classes"]) == 5
       and all(value == 1 for value in summary["control_classes"].values())
       and summary["incomplete_tail_byte_count"] == 0)
split = Classifier()
for index, byte in enumerate(reply):
    split.feed(bytes([byte]), index * .001)
record("every_byte_fragmentation_preserves_classes", split.summary()["control_classes"] == summary["control_classes"]
       and split.summary()["incomplete_tail_byte_count"] == 0)
for data, kind in [(b"\x1b", "ESC"), (b"\x1b[?", "CSI"), (b"\x1b]10;rgb:", "OSC")]:
    partial = Classifier()
    partial.feed(data, 0)
    value = partial.summary()
    record("incomplete_" + kind, value["incomplete_tail_class"] == kind
           and value["incomplete_tail_byte_count"] == len(data))
private = Classifier()
private.feed(b"PRIVATE_FIXTURE_TEXT", 0)
value = private.summary()
record("printable_input_count_only_no_text_export", value["printable_input_byte_count"] == 20
       and "PRIVATE_FIXTURE_TEXT" not in json.dumps(value))
exceeded = False
try:
    Classifier().feed(b"x" * 65537, 0)
except ValueError:
    exceeded = True
record("strict_reply_byte_budget", exceeded)
exceeded = False
try:
    Classifier().feed(b"\x1b[I" * 513, 0)
except ValueError:
    exceeded = True
record("strict_event_budget", exceeded)

context_path = root / "evidence/080-terminal-input-probe-prepared-context-20261109T112930Z.json"
c = json.loads(context_path.read_text(encoding="utf-8-sig"))
assert c["controller_sha256"] == expected and len(c["helper_sha256"]) == 40
assert c["controller_duration_seconds"] == 120 and c["timeout_seconds"] == 240
assert c["no_model"] is True and c["model_requests"] == c["account_operations"] == 0
assert c["launch_permitted"] is False and c["linux_workload_started"] is False
g = json.loads(Path(c["guard_context"]).read_text(encoding="utf-8-sig"))
for name, digest in c["helper_sha256"].items():
    assert sha(Path(c["windows_tools"]) / name) == digest
for name, digest in c["original_38_helper_sha256"].items():
    assert sha(Path(g["windows_tools"]) / name) == digest
for name, metadata in c["registry_changes"].items():
    original = (Path(g["windows_tools"]) / name).read_bytes().decode("utf-8")
    replacement = original
    assert len(metadata["replacements"]) == 3
    for before, after in metadata["replacements"]:
        assert replacement.count(before) == 1
        replacement = replacement.replace(before, after)
    assert replacement.encode("utf-8") == (Path(c["windows_tools"]) / name).read_bytes()
for name in ("probe-native-terminal-input080.py", "supervise-080.py"):
    ast.parse((Path(c["windows_tools"]) / name).read_text(encoding="utf-8-sig"))
for field in ("specification", "input_freeze", "source_freeze", "guard_context", "guard_receipt"):
    assert sha(c[field]) == c[field + "_sha256"]
report = {"schema_version": 1, "scope": "terminal_probe_pure_fixtures_and_private_registry_peer",
          "status": "passed", "source_sha256": expected, "context_sha256": sha(context_path),
          "fixture_count": len(rows), "fixtures": rows, "private_helper_hashes_verified": 40,
          "original_helper_hashes_unchanged": 38, "registry_only_changes": 6,
          "registry_deltas_exact_bytes": True, "helper_body_executed": False,
          "Linux_processes_or_WindowsTerminal_launched": False, "model_auth_database_requests": 0,
          "actual_Codex_parser_tested": False, "ready_for_root_review_not_execution_approval": True}
out = root / "evidence/terminal-input-probe-independent-pure-peer-20261109.json"
assert not out.exists()
out.write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps({"status": "passed", "fixtures": len(rows), "peer": str(out), "sha256": sha(out)}))
