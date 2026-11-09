"""Windows-only review copies; no app import or subprocess execution."""
import ast
import difflib
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
target = root / "evidence/native-worker-term-proposal-20261109"
target.mkdir(exist_ok=False)
changes = {
    "src/devbrain/native_worker.py": [
        ('for key in ("TMUX", "TMUX_PANE"):\n        # These identify this actual inner native pane, never the terminal\n        # workspace which happened to start the broker or prepare the launch.',
         'for key in ("TERM", "TMUX", "TMUX_PANE"):\n        # Capabilities and identity belong to this actual inner native pane,\n        # never the terminal which happened to prepare the broker launch.')
    ],
    "tests/test_terminal_bridge.py": [
        ('def test_native_worker_rebinds_actual_inner_tmux_identity(tmp_path, monkeypatch):',
         '@pytest.mark.parametrize("inner_term", ["tmux-256color", None])\ndef test_native_worker_rebinds_actual_inner_tmux_identity(tmp_path, monkeypatch, inner_term):'),
        ('                                                       "CODEX_HOME": "/fixture/config"}}))',
         '                                                       "TERM": "xterm-256color", "CODEX_HOME": "/fixture/config"}}))'),
        ('    monkeypatch.setenv("TMUX_PANE", "%3")\n    monkeypatch.setattr("sys.argv", ["worker", "--spec", str(spec)])',
         '    monkeypatch.setenv("TMUX_PANE", "%3")\n    if inner_term is None:\n        monkeypatch.delenv("TERM", raising=False)\n    else:\n        monkeypatch.setenv("TERM", inner_term)\n    monkeypatch.setattr("sys.argv", ["worker", "--spec", str(spec)])'),
        ('    assert seen[0] == {"TMUX": "/inner/socket,2,0", "TMUX_PANE": "%3", "CODEX_HOME": "/fixture/config"}',
         '    expected = {"TMUX": "/inner/socket,2,0", "TMUX_PANE": "%3", "CODEX_HOME": "/fixture/config"}\n    if inner_term is not None:\n        expected["TERM"] = inner_term\n    assert seen[0] == expected')
    ],
}
proof = {"scope": "native_worker_TERM_consistency_proposal_only", "working_source_modified": False,
         "runtime_or_model_tested": False, "Codex_timeout_cause_established": False, "files": {}}
patch = []
for relative, replacements in changes.items():
    original_path = root / "devbrain" / relative
    original_bytes = original_path.read_bytes()
    original = original_bytes.decode()
    updated = original
    for old, new in replacements:
        assert updated.count(old) == 1, relative
        updated = updated.replace(old, new)
    ast.parse(updated)
    output = target / relative
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(updated.encode())
    patch.extend(difflib.unified_diff(original.splitlines(True), updated.splitlines(True),
                                     fromfile="a/" + relative, tofile="b/" + relative))
    proof["files"][relative] = {"baseline_sha256": hashlib.sha256(original_bytes).hexdigest(),
                               "proposal_sha256": hashlib.sha256(updated.encode()).hexdigest()}
    assert original_path.read_bytes() == original_bytes
(target / "proposal.patch").write_bytes("".join(patch).encode())
proof["proposal_patch_sha256"] = hashlib.sha256((target / "proposal.patch").read_bytes()).hexdigest()
(target / "static-proof.json").write_bytes((json.dumps(proof, indent=2) + "\n").encode())
print(json.dumps({"status": "proposal_only_AST2_passed_no_execution", "path": str(target),
                  "patch_sha256": proof["proposal_patch_sha256"]}))
