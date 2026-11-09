# WSL restart diagnosis — 2026-11-07

Read-only investigation. No WSL, Windows, BIOS, GPU driver, registry or memory settings were changed; no restart or GPU workload was initiated by this investigation.

## Finding

The interruption at **10:18:52 Europe/Warsaw (09:18:52 UTC)** was a **WSL guest kernel panic**, followed by recreation of the WSL virtual machine. It was not merely a DevBrain request timeout. The initiating defect is still unconfirmed; the available evidence does not establish Ollama, GPU, memory exhaustion, or a specific WSL bug as its cause.

The decisive artifact is Windows `%TEMP%\wsl-crashes\kernel-panic-1794043132-{c74e3be2-be7b-4a34-84a9-b1275ca8dc01}.txt`, modified at `2026-11-07T10:18:52.0967018+01:00`. An exact copy is saved as [wsl-kernel-panic-20261107T091852Z.txt](wsl-kernel-panic-20261107T091852Z.txt), SHA-256 `79a8ec97824a31414590f719b2c88d214adb05d6733394e0307ab97037136b95`.

The dump ends with `Kernel panic - not syncing: Fatal exception`. The fault location is `idle_cpu+0x13/0x60`; the stack contains `update_sd_lb_stats`, `find_busiest_group`, `load_balance`, `newidle_balance`, `pick_next_task_fair`, `__schedule`, and `do_coredump`. It reports CR2 `0x18`. This places the fatal exception in the scheduler while a process was in the core-dump path. The retained 4,148-byte excerpt begins in a register dump, so it does not identify the process or retain the initial exception header. The low fault address alone does not distinguish a software defect from earlier corruption.

## Corroboration

Windows event queries covered 10:16–10:21 local time, including System, Application and every enumerated Hyper-V/Host-Network channel. Exact results and no-event responses are in [wsl-restart-events-20261107.json](wsl-restart-events-20261107.json).

| Local time | Observation |
| --- | --- |
| 10:18:45 | Last persisted entry from Linux boot `4704f8c158be4f1cb02f2d5a4616195f` |
| 10:18:52.096 | Kernel panic artifact written |
| 10:18:52.100 | Hyper-V VmSwitch IDs 234/233 disconnect and delete NIC of VM `C74E3BE2-BE7B-4A34-84A9-B1275CA8DC01`, matching panic filename |
| 10:18:54.137 | IDs 69/71 delete its WSL switch port |
| 10:18:57.115 | ID 233 creates NIC for new VM `C1044371-BCBD-47F5-B7EC-966BF70C7B31` |
| 10:18:58 | New Linux boot `48692a5867514547820bd3595c6767db` starts |

Windows last boot remained `2026-11-07T08:21:41.5+01:00`. No Application Error or WER event was returned in the five-minute window. No WHEA, Resource-Exhaustion, nvlddmkm, Display, Kernel-Power or BugCheck warning/error was returned from System between 08:21 and 10:21. Hyper-V Compute/Worker/Hypervisor channels returned no matching records; some diagnostic channels need not have been enabled. These absences do not exclude failures that were never persisted.

VmSwitch warning 285 repeats about once per minute for **Default Switch**, both before and after the panic, with reported execution/queue time zero; it does not establish a causal WSL networking fault. The previous Linux kernel journal ends without the panic and has no OOM record in its retained tail. The external Windows panic artifact explains why relying only on the distro journal missed the failure.

Three earlier Python 3.12 signal-11 dump files exist in the same crash directory, at 09:42:49, 09:52:52 and 10:05:12. Only file metadata was inspected, not process memory. Their relationship to this panic is unknown.

## Versions and official-source review

Observed locally: WSL `2.6.1.0`, packaged kernel `6.6.87.2-1` / running `6.6.87.2-microsoft-standard-WSL2`, WSLg `1.0.66`, Windows `10.0.26300.9818`. Parent's collected environment additionally reports RTX 4080 Super, NVIDIA 610.88, Ollama 0.40.14, host RAM 64 GB and WSL memory limit 56 GB.

On the investigation date, Microsoft's [latest stable WSL release](https://github.com/microsoft/WSL/releases/tag/3.0.3) is **3.0.3**, published 2026-10-09; the official releases API confirms `prerelease=false`. Its notes update the bundled kernel to **6.18.54.1**. The stable release notes after 2.6.1 were checked for `panic`, `scheduler`, `null.pointer`, `idle_cpu`, `do_coredump` and `kernel`; no exact matching fix is documented. Metadata and matched lines are saved in [wsl-stable-release-notes-20261107.json](wsl-stable-release-notes-20261107.json). This is a significant kernel update, not proof of a fix for this incident.

Microsoft's [WSL debugging documentation](https://github.com/microsoft/WSL/blob/master/doc/docs/debugging.md) identifies ETL as the principal Windows-side WSL trace and the Lxss.Manager provider as containing guest/error/VM-lifetime events. Its [contribution guidance](https://github.com/microsoft/WSL/blob/master/CONTRIBUTING.md) documents the official log collector. A trace surrounding any recurrence would provide more useful evidence than another journal-only check. No collector was started in this read-only investigation.

An additional independent hardware context was observed: Intel i9-14900K, ASUS ROG STRIX Z690-G GAMING WIFI, BIOS 4101 dated 2024-12-03; Windows CPU Update Revision bytes are `2B 01 00 00` (0x12B). Intel's [current official advisory](https://www.intel.com/content/www/us/en/support/articles/000102331/processors.html) recommends 0x12F or later and Intel Default Settings for this processor generation's confirmed Vmin-instability class. **This is a differential consideration, not a diagnosis of this CPU.** No firmware or settings change is proposed as part of the immediate WSL step.

## Maintenance step proposed by the initial investigation

After the full test suite and other WSL jobs finish, save persistent reports and stop DevBrain/database services cleanly. Run `wsl --update` without prerelease options. If the Microsoft Store route does not offer the current stable release, the documented `wsl --update --web-download` route obtains the update from GitHub. Then perform a controlled `wsl --shutdown` and start Ubuntu to load the new kernel. Verify both `wsl --version` and `wsl -d Ubuntu -- uname -r`, then restore services and run the isolated validation workload. The running kernel cannot be replaced merely by installing the new package.

Microsoft documents both update routes and that shutdown immediately terminates **all** running WSL distributions and the utility VM in its [basic commands guide](https://learn.microsoft.com/en-us/windows/wsl/basic-commands#update-wsl). This step does not require changing Windows Update, firmware, RAM settings or GPU drivers. It is a reasonable maintenance step on an old WSL/kernel stack; a successful repeat run cannot prove that an intermittent panic has been eliminated permanently.

## Authorized update and recurrence

The user subsequently authorized the stable WSL update and global WSL restart, and approved the Windows administrator prompt. The update completed. A controlled `wsl --shutdown` was followed by Ubuntu startup at approximately 11:10 local time. Observed versions are WSL **3.0.3.0** and running kernel **6.18.54.1-microsoft-standard-WSL2**, boot ID `44a44f82-70ad-4cc5-b703-6f6572e2dc3a`; see [post-update evidence](wsl-after-update-20261107.json).

At **11:13:43 local time**, an isolated test ArcadeDB process again crashed after 126.5 seconds. Its OpenJDK `21.0.12.1+1-1-24.04.4-Ubuntu` fatal report records SIGSEGV in `PhaseIFG::effective_degree(unsigned int) const`, on `C2 CompilerThread0`, while compiling `org.xnio.nio.WorkerThread::run`. The subsequent abort is visible in the new kernel's dmesg. This differs from the earlier HotSpot `Type::typerr` failure. See [exact fatal report](arcade-jvm-post-update-fatal-20261107.log).

The WSL boot ID remained unchanged and approximately 54 GB of Linux memory was available. Consequently, the update has **not established runtime stability**, and this occurrence was a JVM process crash rather than another observed WSL restart. No evidence establishes whether the initiating defect is JDK software, hardware instability, or another form of corruption.

A bounded diagnostic repeat uses `JAVA_TOOL_OPTIONS=-XX:TieredStopAtLevel=1` only for an isolated test engine. This selects C1 without C2, as documented in [AWS's Java runtime configuration guide](https://docs.aws.amazon.com/lambda/latest/dg/java-customization.html). A pass under that setting cannot establish normal C2 stability or identify the original cause. Global Java configuration, BIOS, GPU drivers and Windows memory settings remain unchanged.

The bounded repeat completed **56/56 tests successfully in 309.92 seconds**. Separately, a Python 3.12 process running the evaluation tests aborted with signal 6 after 27 completed test indicators, inside `ssl.create_default_context`; its Java database process was still alive. The Python run has no complete JUnit result and is not counted as a successful full run. See [Python abort stack](native-evaluation-python-abort-20261107.log) and [runner result](native-evaluation-post-update-20261107.json). This independent failure prevents treating C1 as a complete solution.

Production database/service processes were left stopped. The expensive live-model recall evaluation, final production UI run and retries of historical production jobs were not resumed. Installed source and application files were verified by byte comparison without opening the production database; account/configuration fingerprints remain unchanged. Further diagnosis must account for both independent runtime failures rather than weakening application assertions or marking interrupted tests as passed.
