"""Read proposal ASTs and execute only pure translation fixtures, never App imports."""
import ast
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
proposal = root / "evidence/native-failure-ux-proposal-20261109"
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
patch_sha = "b2344d7511cec32a38967c705ef01bcc83d71babe8e25e2868ed4c170483bbab"
assert sha(proposal / "proposal.patch") == patch_sha
baseline = json.loads((proposal / "baseline-source-sha256.json").read_text(encoding="utf-8"))
rows = []
def definitions(tree):
    result = {}
    def walk(node, prefix=""):
        for item in ast.iter_child_nodes(node):
            scope = isinstance(item, (ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef))
            name = prefix + "." + item.name if prefix and scope else item.name if scope else prefix
            if isinstance(item, (ast.FunctionDef, ast.AsyncFunctionDef)):
                result[name] = ast.dump(item, include_attributes=False)
            walk(item, name)
    walk(tree)
    return result

for relative, expected in baseline.items():
    current = root / "devbrain" / relative
    assert sha(current) == expected
    old = ast.parse(current.read_text(encoding="utf-8"))
    new = ast.parse((proposal / relative).read_text(encoding="utf-8"))
    old_defs, new_defs = definitions(old), definitions(new)
    if relative.startswith("tests/"):
        assert all(new_defs.get(name) == code for name, code in old_defs.items()), relative
    rows.append({"file": relative, "current_sha256": expected,
                 "proposal_sha256": sha(proposal / relative), "AST_parsed": True,
                 "all_existing_test_function_ASTs_preserved": True if relative.startswith("tests/") else None})

tree = ast.parse((proposal / "src/devbrain/terminal_i18n.py").read_text(encoding="utf-8"))
nodes = [node for node in tree.body if isinstance(node, (ast.Assign, ast.Expr, ast.For))
         and node.lineno < 263]
nodes += [node for node in tree.body if isinstance(node, ast.FunctionDef)
          and node.name in {"tr", "native_failure_notice"}]
pure = ast.Module(body=nodes, type_ignores=[])
namespace = {}
exec(compile(pure, "<pure-literal-catalog-and-notice-only>", "exec"), namespace)
notice, tr = namespace["native_failure_notice"], namespace["tr"]
fixtures = []
for language in ("en", "pl"):
    for state in ("failed", "interrupted", "stale"):
        for purpose in ("coding", "auth"):
            value = notice({"client": "codex", "lifecycle": state, "purpose": purpose, "exit_code": 1,
                            "error": "PRIVATE_MUST_NOT_APPEAR"}, language)
            assert value and "PRIVATE" not in value and "\x1b" not in value
            if purpose == "auth":
                assert tr("Open Connections from the menu (Ctrl+B Space) to review account sign-in.", language) in value
                assert tr("Start work", language) not in value
            elif state == "stale":
                assert tr("Open the menu with Ctrl+B Space to review the current session.", language) in value
                assert tr("Start work", language) not in value
            else:
                assert tr("Exit code: {code}.", language, code=1) in value
            fixtures.append({"language": language, "state": state, "purpose": purpose, "passed": True})
    for code in (True, -1, 256, "1", {}, None):
        value = notice({"client": "PRIVATE\x1b]52;bad", "lifecycle": "failed", "exit_code": code}, language)
        assert "PRIVATE" not in value and "\x1b" not in value
        assert tr("Exit code: {code}.", language, code=1) not in value
        fixtures.append({"language": language, "unbounded_or_untyped_code_rejected": True})

result = {"schema_version": 1, "scope": "independent_native_failure_UX_proposal_readonly_peer",
          "status": "passed_for_implementation_and_supervised_tests_not_runtime_qualification",
          "proposal_patch_sha256": patch_sha, "files": rows, "pure_fixture_count": len(fixtures),
          "pure_fixtures": fixtures, "existing_test_ASTs_preserved": True,
          "bounded_final_nonblocking_writer_reviewed": True,
          "final_output_fd_flags_restored_on_timeout_error_cancellation": True,
          "auth_cleanup_finally_preserved_after_optional_feedback_cancellation": True,
          "all_three_status_paths_and_404_409_stale_feedback_reviewed": True,
          "fresh_selected_slot_and_identity_feedback_preserves_other_notices_and_scope": True,
          "meaningful_full_unread_PTY_external_deadline_test_proposed_not_run": True,
          "runtime_tests_or_full_App_imports_executed": False,
          "Linux_UI_models_or_accounts_started": False, "production_or_frozen_sources_modified": False,
          "remaining_runtime_validation": "Proposed PTY/Textual regressions must run under qualified supervision after implementation; this read-only peer is not their result."}
out = root / "evidence/native-failure-ux-independent-peer-20261109.json"
assert not out.exists()
out.write_text(json.dumps(result, indent=2), encoding="utf-8")
print(json.dumps({"status": "passed", "files": len(rows), "pure_fixtures": len(fixtures),
                  "peer": str(out), "sha256": sha(out)}))
