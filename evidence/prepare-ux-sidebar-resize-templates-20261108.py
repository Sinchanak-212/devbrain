"""Windows-only immutable UX metadata authoring; never imports app or launches processes."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
E = ROOT / 'evidence'
def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path, digest=None):
    p = Path(path)
    if digest is not None:
        assert sha(p) == digest, p.name
    return json.loads(p.read_text(encoding='utf-8-sig'))
def new(path, data):
    p = Path(path)
    with p.open('xb') as f:
        f.write(data)
    return sha(p)
def newjson(path, obj):
    return new(path, (json.dumps(obj, indent=2, ensure_ascii=False)+'\n').encode())
def text(path):
    return Path(path).read_bytes().decode('utf-8-sig')

app_path = E/'080-app-ux-snapshot-active-context.json'
app_sha = 'd0a5b7e2682cd3f540fcce87446517fb8a11b6712f689aeb6df6dfbf562c771c'
app = read(app_path, app_sha)
assert app['status'] == 'prepared_passed' and app['actual_windows_exit_code'] == 0
assert app['run_id'] == 'app080-20261108T222731Z'
freeze = read(app['freeze_manifest'], app['freeze_sha256'])
assert len(freeze['files']) == 209
assert sum(k.startswith('devbrain/') for k in freeze['files']) == 198
for name, digest in freeze['files'].items():
    assert sha(Path(app['bundle_root'])/name) == digest, name
read(app['setup_receipt'], app['setup_receipt_sha256'])
old = read(E/'080-ux-length-repair-604-templates-20261108.json', 'c9e80de2e0c7120e2f8b966c0a5286fc354445859cf047e3cb1b269fed9dc5f0')
for p, h in old['files'].items():
    assert sha(p) == h
old_dir = E/'ux-length-repair-604-templates-20261108'
new_dir = E/'ux-sidebar-resize-604-templates-20261108'
assert not new_dir.exists()
new_dir.mkdir()
replacements = {
    'app080-20261108T202627Z': app['run_id'],
    'source202627': 'source222731',
    old['source_freeze_sha256']: app['freeze_sha256'],
    old['app_prepare_receipt_sha256']: app['setup_receipt_sha256'],
    'ux-length-repair': 'ux-sidebar-resize',
    'length_repair': 'sidebar_resize',
    'context-v7-': 'context-v8-',
    'Actual v7': 'Actual v8',
}
def transform(s):
    for a, b in replacements.items():
        s = s.replace(a, b)
    return s
spec = json.loads(transform(text(old_dir/'ux.spec.template.json')))
assert len(spec['argv']) == 13
spec_path = new_dir/'ux.spec.template.json'
spec_sha = newjson(spec_path, spec)
context = json.loads(transform(text(old_dir/'ux.context.template.json')))
context['expected_nodeid_count'] = 381
context['specification_template_sha256'] = spec_sha
context['materialization_prerequisites'][-1] = 'Root serial handoff; no backend or UI PASS inferred'
for name, digest in context['expected_unchanged_helper_sha256'].items():
    assert sha(ROOT/'release-tools'/name) == digest, name
context_path = new_dir/'ux.context.template.json'
context_sha = newjson(context_path, context)
master = json.loads(transform(json.dumps(old)))
master['created_utc'] = datetime.now(timezone.utc).isoformat()
master['expected_cases'] = 381
master['files'] = {str(context_path): context_sha, str(spec_path): spec_sha}
master_path = E/'080-ux-sidebar-resize-604-templates-20261108.json'
master_sha = newjson(master_path, master)
old_stage = E/'stage-ux-length-repair-604-20261108.ps1'
assert sha(old_stage) == '337c38e0470031e86c617a05c6bc3db3fe5ac66d29dd1e594aa9c6b98a8da3e2'
stage = transform(text(old_stage))
stage = stage.replace('377', '381')
stage = stage.replace('c9e80de2e0c7120e2f8b966c0a5286fc354445859cf047e3cb1b269fed9dc5f0', master_sha)
stage = stage.replace('a4a2298bbae6599f3a9b0685283071b9f821580759b843b8c9056f2f6b9eb1a3', app_sha)
stage = stage.replace('param([switch]$Stage)', 'param([switch]$Stage,[string]$GuardContextSha256,[string]$GuardReceiptSha256,[string]$GuardFinalReportSha256,[long]$GuardActualWindowsExecSession,[string]$CandidateContextSha256)')
for literal, variable in [
    ('0d47b2ea314be36b18749076196693227d91d8395645ad1779a412894582565d', '$GuardContextSha256'),
    ('c2469d14d080ecdf96d42d6dc4c887207a706898ea3681fa5b10749a26113b82', '$GuardReceiptSha256'),
    ('e3c5362952f7d56f5dc7f5d9e45678752bf8304060c961baee8fe49c372e63b5', '$GuardFinalReportSha256'),
    ('cdd27ef8e5326c85ab4f85af562b2826c20f3b63cfd07c454441cb3fbf7766d6', '$CandidateContextSha256')]:
    assert stage.count("'"+literal+"'") == 1
    stage = stage.replace("'"+literal+"'", variable)
stage = stage.replace('$g.actual_windows_exec_session-eq76710', '$GuardActualWindowsExecSession-gt0-and$g.actual_windows_exec_session-eq$GuardActualWindowsExecSession')
stage = stage.replace("$g.run_id-ceq'guards-length-repair080-20261108T203656Z'", "$g.run_id-cmatch'^guards-sidebar-resize080-[0-9]{8}T[0-9]{6}Z$'")
stage = stage.replace('candidate-v7-', 'candidate-v8-').replace('Actual v7', 'Actual v8')
assert "^guards-sidebar-resize080-" in stage
for forbidden in ('202627', '76710', '377', 'candidate-v7', 'c2469d14', '0d47b2ea'):
    assert forbidden not in stage, forbidden
stage_path = E/'stage-ux-sidebar-resize-604-20261108.ps1'
stage_sha = new(stage_path, stage.encode())
report = {
    'schema_version': 1, 'scope': 'devbrain_sidebar_resize_ux_template_preparation',
    'status': 'prepared_not_run_pending_actual_current604_and_v8',
    'master': str(master_path), 'master_sha256': master_sha,
    'stager': str(stage_path), 'stager_sha256': stage_sha,
    'source_context_sha256': app_sha, 'source_snapshot': app['run_id'],
    'source_freeze_sha256': app['freeze_sha256'], 'app_prepare_receipt_sha256': app['setup_receipt_sha256'],
    'files': master['files'], 'expected_cases': 381, 'whole_modules': 28,
    'source_file_count_verified': 198, 'source_total_files_verified': 209, 'helper_count_verified': 38,
    'spec_contract_changed_only_source_venv': spec == json.loads(transform(text(old_dir/'ux.spec.template.json'))),
    'guard_actual_receipt': None, 'candidate_v8_actual_context_sha256': None,
    'new_runtime_or_app_pass_claimed': False, 'stage_invoked': False, 'linux_started': False,
    'future_stage_parameters': ['Stage','GuardContextSha256','GuardReceiptSha256','GuardFinalReportSha256','GuardActualWindowsExecSession','CandidateContextSha256'],
}
report_path = E/'080-ux-sidebar-resize-template-preparation-20261108.json'
report_sha = newjson(report_path, report)
print(json.dumps({'master_sha256':master_sha,'stager_sha256':stage_sha,'preparation_sha256':report_sha,'status':report['status']}))
