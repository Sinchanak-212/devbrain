"""Bounded Windows UNC read of one closed synthetic hook spool; no application imports."""
import hashlib
import json
from collections import Counter
from pathlib import Path

w = Path(__file__).resolve().parent.parent
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(path):
    assert not path.is_symlink() and path.stat().st_size <= 1024 * 1024, 'bounded_regular_metadata_required'
    return json.loads(path.read_text(encoding='utf-8-sig'))
proof_path = w / 'evidence/080-prototype-real-wt-ui-failed-acceptance-safe-next-20261109.json'
assert sha(proof_path) == '87958ff26b8cab75b4879a395a5b0a59191f05609449b813e120dea01212ae19'
proof = read(proof_path)
assert proof['status'] == 'canonical_UI_acceptance_failed_cleanup_verified'
assert proof['actual_windows_exec_session'] == 11559 and proof['actual_windows_exit_code'] == 1
assert all(proof[k] is True for k in ('safe_for_next_owned_workload','owned_cleanup_verified',
    'external_viewers_actual_exit_verified','engine_actual_exit_verified','oauth_source_lease_release_verified'))
base = Path('//wsl.localhost/Ubuntu/home/piotr/.cache/devbrain-regressions-080/interactive-01ad2a3eea6144ffa4c70d29fa71c739')
report = {'schema_version':1,'scope':'closed_synthetic_UI_hook_spool_metadata_only',
    'run_id':proof['run_id'],'safe_next_report_sha256':sha(proof_path),'private_manifest_retained':False,
    'private_runtime_registry_retained':False,'hook_spool_retained':False,'hook_files_observed':0,
    'event_name_counts':{},'event_metadata':[],'native_Resume_verified':False,
    'database_started':False,'Linux_program_started':False,'model_or_account_request_started':False,
    'private_payload_exported':False,'not_observed_does_not_mean_hook_never_ran':True}
manifest = base / 'interactive.json'
if manifest.is_file():
    state = read(manifest)
    assert state['run_id'] == proof['run_id'] and state['status'] == 'closed'
    assert state['work_root'] == '/home/piotr/.cache/devbrain-regressions-080/' + base.name
    assert state['data_dir'] == state['work_root'] + '/engine-home'
    report['private_manifest_retained'] = True
    data = base / 'engine-home'
    assert not base.is_symlink() and not data.is_symlink(), 'owned_plain_private_directory_required'
    registry_path = data / 'runtime/runs.json'
    expected_logical = None
    if registry_path.is_file():
        registry = read(registry_path)
        assert registry['version'] == 1 and isinstance(registry['runs'],list) and len(registry['runs']) <= 8
        rows = [row for row in registry['runs'] if row.get('client') == 'codex'
                and row.get('purpose') == 'coding' and str(row.get('id','')).startswith('f168')
                and row.get('generation') == 1]
        assert len(rows) == 1 and isinstance(rows[0].get('session_id'),str)
        expected_logical = rows[0]['session_id']
        assert expected_logical.startswith('17a')
        report.update(private_runtime_registry_retained=True, expected_owned_Codex_generation_identified=True,
            expected_logical_id_matches_known_prefix=True,
            runtime_registry_native_id_present=bool(rows[0].get('native_session_id')))
    spool = data / 'hook-events'
    if spool.is_dir():
        assert not spool.is_symlink()
        report['hook_spool_retained'] = True
        files = sorted(spool.glob('*.json'))
        assert len(files) <= 100, 'hook_spool_count_bound_exceeded'
        counts = Counter()
        for path in files:
            payload = read(path)
            event = payload.get('hook_event_name')
            event = event if event in {'SessionStart','PreCompact','Stop','SessionEnd'} else 'unrecognized'
            counts[event] += 1
            native = payload.get('session_id')
            logical = payload.get('devbrain_session_id')
            report['event_metadata'].append({'event_name':event,
                'native_session_id_present':isinstance(native,str) and bool(native),
                'logical_id_present':isinstance(logical,str) and bool(logical),
                'logical_id_matches_expected_owned_session':logical == expected_logical if expected_logical else None})
        report['hook_files_observed'] = len(files)
        report['event_name_counts'] = dict(sorted(counts.items()))
report['classification'] = ('retained_hook_metadata_observed_native_identity_not_yet_qualified'
                            if report['hook_files_observed'] else 'no_retained_hook_event_observed_no_execution_inference')
out = w / 'evidence/080-closed-prototype-ui-hook-spool-metadata-20261109.json'
assert not out.exists()
out.write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({'report_sha256':sha(out),**report}))
