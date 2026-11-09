"""Parse proposal copies and create a diff without importing application code."""
import ast
import difflib
import hashlib
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parent
repository = root.parent.parent
baseline = json.loads((root / "baseline-source-sha256.json").read_text(encoding="utf-8"))
context = json.loads((repository / "evidence/080-interactive-sidebar-resize-agent-active-context-20261108.json").read_text(encoding="utf-8"))
freeze = json.loads(Path(context["source_freeze"]).read_text(encoding="utf-8"))
sha = lambda data: hashlib.sha256(data).hexdigest()
assert sha(Path(context["source_freeze"]).read_bytes()) == "ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703"
diff = []
files = {}
for relative, expected in baseline.items():
    source, proposed = repository / "devbrain" / relative, root / relative
    old, new = source.read_bytes(), proposed.read_bytes()
    assert sha(old) == expected == freeze["files"]["devbrain/" + relative], relative + ": current source changed"
    ast.parse(old.decode("utf-8"), filename=str(source))
    ast.parse(new.decode("utf-8"), filename=str(proposed))
    changes = list(difflib.unified_diff(old.decode("utf-8").splitlines(keepends=True),
                                      new.decode("utf-8").splitlines(keepends=True),
                                      fromfile="a/" + relative, tofile="b/" + relative))
    diff.extend(changes)
    files[relative] = {"baseline_sha256": expected, "proposal_sha256": sha(new),
                       "added_lines": sum(line.startswith("+") and not line.startswith("+++") for line in changes),
                       "removed_lines": sum(line.startswith("-") and not line.startswith("---") for line in changes)}
patch = "".join(diff).replace("\r\n", "\n")
(root / "proposal.patch").write_text(patch, encoding="utf-8", newline="\n")
result = {"scope": "proposal_copies_static_review_only", "python_executable": sys.executable,
          "python_version": sys.version.split()[0], "AST_parsed_files": len(files),
          "current_sources_unchanged_and_equal_ad77_freeze": True,
          "proposal_diff_sha256": sha((root / "proposal.patch").read_bytes()),
          "App_imports_or_tests_executed": False, "Linux_models_or_accounts_started": False,
          "release_qualification_claimed": False, "files": files}
(root / "static-review.json").write_text(json.dumps(result, indent=2), encoding="utf-8", newline="\n")
print(json.dumps({key: value for key, value in result.items() if key != "files"}, indent=2))
