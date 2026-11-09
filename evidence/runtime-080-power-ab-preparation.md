# Prepared temporary no-boost diagnostic — NOT EXECUTED

2026-11-07. User authorization has not yet been requested or granted for a power-plan change or scheduled-task registration. Source preparation, static parsing and the parent's read-only `Inspect` validation were performed. No Begin, task registration or plan change occurred.

## Concrete proposed comparison

**A:** retain the already observed system Perl SIGSEGV during verified OpenSSL3.5.9 `Configure` as the baseline (`runtime-080-perl-configure-fatal.json`). There is no automatic repeat of that failed phase.

**B, only after consent:** duplicate the currently active Windows power plan to a new GUID, set only the clone's AC/DC `PERFBOOSTMODE` values to0, and run at most3 serial copies of the same `Configure` command in fresh directories. No make/install, DB, Java, models or GPU. Each process scope has a verified2GiB cap. Work stops on the first new core, boot change, plan change, nonzero exit or time limit. The helper budgets75s work,15s cleanup reserve and a full30s post-cleanup observation within120s. It always stops its owned UUID scope, including when its parent process has exited, and requires evidence that the scope is empty or gone. Actual observation duration is recorded; less than30s cannot pass. A result is diagnostic only; it does not reopen the application stability gate.

Before activating the clone, the script registers and starts one hidden, current-user Windows Task Scheduler task and verifies its fresh heartbeat/running state. This task is independent of our command process. Future consent must explicitly include this temporary task as well as the plan change. No credentials are stored. Missing task permissions, AC/DC readback or live watchdog causes refusal to activate the clone.

The watchdog starts rollback at150s from preparation, leaving margin to an180s operating budget. Normal orchestration must also call `Restore -Execute` in a `finally` block immediately when the diagnostic ends. Restore selects the saved original GUID only when the clone is currently active, verifies readback, deletes only the owned inactive clone and removes only its own task. The original plan is never edited. If another plan is observed active, it is preserved and only the inactive owned clone/task are removed. State/ownership/heartbeat files are atomic and restricted to a generated absolute workspace artifact directory.

## Reviewable entry points

- `temporary-no-boost-080.ps1 -Mode Inspect` — read current active GUID and original AC/DC values, no changes.
- `temporary-no-boost-080.ps1 -Mode Begin -Execute` — future authorized activation; returns owned `state_path`, `original`, `clone`, deadline.
- `diagnose-perl-power-ab-080.py --execute --phase no-boost --expected-plan <clone GUID> --state <absolute WSL path to owned state.json>` — future bounded diagnostic, no power changes.
- `temporary-no-boost-080.ps1 -Mode Restore -Execute -StatePath <returned Windows state_path>` — future explicit cleanup, always called after B even on failure.

The Perl helper also supports an explicitly authorized `baseline` phase with a supplied expected GUID; it does not automatically alternate phases or repeat a fatal.

## Limits, stated explicitly

Microsoft defines0 as disabling processor boost policy for the supported power-management models. WSL2 runs within a managed VM. The inference is that host power policy can affect the physical CPU resources used by WSL; neither a successful setting readback nor `/proc/cpuinfo` establishes the guest workload's actual physical clock behavior. No frequency measurement or hardware diagnosis is claimed. Sources: [Microsoft PERFBOOSTMODE](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/options-for-perf-state-engine-perfboostmode), [WSL version comparison](https://learn.microsoft.com/en-us/windows/wsl/compare-versions).

Windows has no atomic compare-and-swap power-plan API. A narrow race remains if the user switches plans precisely between the final active-plan read and restoration. Observed manual changes are preserved. The experiment is brief; no user action is required during it.

The watchdog cannot guarantee wall-clock restoration if Windows, Task Scheduler or power-management APIs fail or the machine is suspended. It refuses activation unless the watchdog is already running, retries restoration within its operating deadline, and records failures for inspection. No BIOS/firmware, voltage, max-CPU percentage, affinity, reboot or global-runtime setting is changed.

## Frozen source hashes and validation

- `release-tools/temporary-no-boost-080.ps1`: SHA256 `71e67ffe9c22ea53562ea01b15cc47bd8a56c726a43604b4da898b196f955200`.
- `release-tools/diagnose-perl-power-ab-080.py`: SHA256 `c871598205ce4017f94f3958a97ea54a2aa57f558fcf1a2191bffa50e3ac96ff`.

PowerShell Parser AST:0errors. Python AST:PASS. The parent separately ran only `-Mode Inspect`: exit0, `applied=false`, active Balanced GUID `381b4222-f694-41f0-9685-ff5bb260df2e`, AC2/DC2. This validates PInvoke readback without registering a task or changing power settings. The Perl diagnostic was not executed. Independent static review found no PowerShell blocker and requested unconditional scope cleanup plus complete post-cleanup observation in the Perl helper. Follow-up review identified a scope-registration race: final cleanup evidence is now collected after the exact launcher has exited and a repeated stop. The independent reviewer rechecked the final changes and reported no remaining concrete blocker in either script. This was static review only; neither the watchdog nor Configure was executed. The source hashes above are frozen for the consent decision.
