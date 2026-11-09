# Reviewable UX proposal — not applied

These seven copies are based on source freeze `ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703`.
The working application and historical snapshots remain unchanged.

- `terminal_bridge.py` retains only final public metadata and prints a fixed EN/PL failure, interruption or changed-session message after terminal restoration. Initial GET, websocket status, later GET and stale broker rejection use the same completion path. Final feedback uses nonblocking output with a 250 ms deadline and restores its previous flags, including on cancellation; a closed or unread terminal cannot hold cleanup indefinitely. Account-login terminals receive Connections guidance; existing auth-pane cleanup remains in place even if final feedback is cancelled.
- `terminal_panels.py` tracks feedback from the exact project/worktree/slot/run/generation of an explicit Start. Fresh workspace lifecycle replaces a stale Starting message and cached-live presentation. Another notice, project, selected slot or generation ends that feedback ownership. A saved-form notice stays visible while the project state still shows a known failure.
- `workspace.py` projects only integer exit codes in 0–255; booleans and other values become null.
- `terminal_i18n.py` supplies fixed public messages and safe client labels. No raw terminal capture, failure-text classification, account request or automatic retry is added.

`proposal.patch` is generated against the untouched working sources. `static-review.json` records Windows CPython 3.11 AST parsing and source/hash checks only. It is not a runtime qualification or a test-pass report.

The proposal tests cover terminal completion through each of three paths in EN/PL for failed/interrupted/stale, auth-specific recovery and post-restoration cleanup, bounded metadata, actual Textual keyboard Start followed by a fresh failure, preservation of a saved-form notice, scope changes, and real-tmux workspace projection without a new Start.

Next: independently review the diff, then create a fresh isolated application copy on the qualified runtime and run `tests/test_terminal_bridge.py`, `tests/test_terminal_ux080.py`, and `tests/test_workspace_ux080.py` under the owned supervisor. Collect all failures there. Derive actual collection counts and JUnit results from that run; these tests have not been executed here. Then run the affected native/terminal regression gates before freezing replacement final sources. This proposal does not resolve Codex's underlying buffered-input timeout.
