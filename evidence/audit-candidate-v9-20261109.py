"""Read-only mechanical archive/payload audit after retained actual build exit."""
import ast
import base64
import hashlib
import json
import re
import tomllib
import zipfile
import zlib
from pathlib import Path

w = Path(__file__).resolve().parent.parent
cp = w / 'evidence/080-final-candidate-build-ready-context-v9-20261109.json'
read = lambda p: json.loads(Path(p).read_text(encoding='utf-8-sig'))
digest = lambda b: hashlib.sha256(b).hexdigest()
sha = lambda p: digest(Path(p).read_bytes())
c = read(cp)
assert sha(cp) == 'e932bceac1e06410b839afda3f78f6bc4363222fe8f15d98fc9eb8f0c1e8ce8c'
root = Path(c['windows_root'])
op = root / 'artifacts/build-observation.json'
o = read(op)
assert c['run_id'] == o['run_id'] == 'final-candidate-native-failure080-20261109T124013Z'
assert o['passed'] is True and o['qualified'] is False and o['application_qualification'] is False
assert o['status'] == 'candidate_built_observed_not_qualified'
assert type(o['actual_proxy_exit']) is int and o['actual_proxy_exit'] == 0
assert o['actual_exit_verified'] is True and o['cleanup_complete'] is True and o['stdio_complete'] is True
assert o['post_exit_observed_seconds'] >= 30 and o['manual_pid_birth_cleanup_admission_required'] is False
assert o['errors'] == [] and o['initial_boot_id'] == o['final_boot_id']
assert o['power_start'] == o['power_end']
assert o['power_start']['active_guid'] == '381b4222-f694-41f0-9685-ff5bb260df2e'
assert o['power_start']['settings_sha256'] == '6bac59f1660b69c8c9e8d83728cbb7cf2fd184458181fa05a351b72c4c2d9dc1'
assert o['sleep_inhibition']['acquired'] is True and o['sleep_inhibition']['restored'] is True
assert o['native_probe_count'] >= 2 and o['production_modified'] is False
assert sha(c['input_freeze']) == c['input_freeze_sha256'] == o['input_freeze_sha256']
assert sha(c['launcher_freeze']) == c['launcher_freeze_sha256'] == o['launcher_freeze_sha256']
inputs, launcher = read(c['input_freeze']), read(c['launcher_freeze'])
assert len(inputs['files']) == 214
for rel, h in inputs['files'].items():
    assert sha(root / rel) == h, rel
for rel, h in launcher['files'].items():
    assert sha(root / rel) == h, rel
assert sha(c['launcher']) == c['launcher_sha256'] == 'dc9c810abec0edeee707658717f215d22cfb6ffc6f298c4bac06a00ec4456d1b'
assert sha(c['launch_plan']) == c['launch_plan_sha256']
for rel, h in o['output_sha256'].items():
    assert sha(root / rel) == h, rel
assert len(o['output_sha256']) == 4
out = Path(c['candidate_directory'])
mp = out / 'devbrain-update-0.8.0-manifest.json'
m = read(mp)
expected = {rel.removeprefix('devbrain/'): h for rel, h in inputs['files'].items() if rel.startswith('devbrain/')}
assert len(expected) == m['source_files'] == 198 and m['source_sha256'] == expected
assert m['version'] == '0.8.0' and m['supported_versions'] == ['0.7.2'] and m['stage'] == 'candidate' and m['qualified'] is False
assert m['apply_requires'] == ['--python', '--backup-python', '--runtime-gate', '--data-dir']
zp = out / 'devbrain-0.8.0.zip'
assert sha(zp) == m['zip_sha256'] and zp.stat().st_size == m['zip_bytes']
with zipfile.ZipFile(zp) as archive:
    names = archive.namelist()
    assert len(names) == len(set(names)) == 198
    assert set(names) == {'devbrain/' + rel for rel in expected}
    current = {rel: archive.read('devbrain/' + rel) for rel in expected}
assert {rel: digest(raw) for rel, raw in current.items()} == expected
assert (out / 'devbrain-0.8.0.zip.sha256').read_text() == m['zip_sha256'] + '  devbrain-0.8.0.zip\n'
up = out / 'devbrain-update-0.8.0.py'
assert sha(up) == m['updater_sha256'] and up.stat().st_size == m['updater_bytes']
tree = ast.parse(up.read_text(encoding='utf-8'))
payload_nodes = [node.value for node in tree.body if isinstance(node, ast.Assign)
                 and any(isinstance(t, ast.Name) and t.id == 'PAYLOAD' for t in node.targets)]
assert len(payload_nodes) == 1
encoded = ast.literal_eval(payload_nodes[0])
package = json.loads(zlib.decompress(base64.b64decode(encoded, validate=True)))
assert package['version'] == '0.8.0' and package['supported_versions'] == ['0.7.2']
baseline = root / 'releases/devbrain-0.7.2.zip'
assert sha(baseline) == package['backup_baseline_sha256'] == c['baseline_sha256'] == '6b65e7315895b8c44b84bafc9146dfcdae732c3890f959d0e5e58cbf4fd9aa2c'
assert package['backup_version'] == '0.7.2'
with zipfile.ZipFile(baseline) as archive:
    before = {n.removeprefix('devbrain/'): archive.read(n) for n in archive.namelist() if not n.endswith('/')}
rebuilt = dict(before)
changed = set()
for row in package['files']:
    rel = row['path']
    assert rel not in changed and rel in expected
    changed.add(rel)
    old_hash = digest(before[rel]) if rel in before else None
    assert row['before'] == [old_hash] and row['before_by_version'] == {'0.7.2': old_hash}
    raw = row['content'].encode('utf-8') if row['encoding'] == 'utf-8' else base64.b64decode(row['content'], validate=True)
    assert row['encoding'] in ('utf-8', 'base64') and digest(raw) == row['after'] == expected[rel]
    rebuilt[rel] = raw
assert rebuilt == current
assert m['files'] == [{k: v for k, v in row.items() if k != 'content'} for row in package['files']]
pkg = lambda files: {rel.removeprefix('src/devbrain/'): digest(raw) for rel, raw in files.items() if rel.startswith('src/devbrain/')}
assert package['backup_package_sha256'] == m['backup_package_sha256'] == pkg(before)
assert package['target_package_sha256'] == pkg(current)
def pins(files):
    result = {}
    for row in tomllib.loads(files['uv.lock'].decode())['package']:
        if row['name'] != 'devbrain' and 'registry' in row.get('source', {}):
            name = row['name'].lower().replace('_', '-').replace('.', '-')
            result.setdefault(name, []).append(row['version'])
    result = {name: sorted(set(versions)) for name, versions in sorted(result.items())}
    result['__required__'] = sorted(re.match(r'[A-Za-z0-9_.-]+', item).group().lower().replace('_', '-').replace('.', '-')
                                  for item in tomllib.loads(files['pyproject.toml'].decode())['project']['dependencies'])
    return result
assert package['backup_dependency_pins'] == pins(before)
assert package['target_dependency_pins'] == pins(current)
old = read(w / 'evidence/080-final-candidate-build-ready-context-v8-20261108.json')
for rel, h in c['previous_candidate_outputs'].items():
    assert sha(Path(old['windows_root']) / rel) == h
runtime = Path('//wsl.localhost/Ubuntu' + c['base_python'])
assert sha(runtime) == '23bc148d2b48964b621c5561ff2b81c1d9c7b717967a7491efbf12f4304882b5'
report_path = w / 'evidence/080-final-candidate-v9-mechanical-audit-20261109.json'
assert not report_path.exists()
report = {'schema_version': 1, 'scope': 'mechanical_candidate_build_and_payload_audit',
    'status': 'candidate_built_observed_not_qualified', 'run_id': c['run_id'],
    'actual_windows_exec_session': 92942, 'actual_windows_exit_code': 0, 'actual_final_chunk': 'f3080e',
    'observation': str(op), 'observation_sha256': sha(op), 'output_sha256': o['output_sha256'],
    'source_file_count': 198, 'zip_entries_verified': 198, 'updater_reconstructs_identical_198_files': True,
    'updater_changed_file_count': len(changed), 'source_freeze_sha256': c['source_freeze_sha256'],
    'frozen_inputs_verified': 214, 'baseline_and_dependency_pin_maps_verified': True,
    'previous_V8_outputs_unchanged': True, 'runtime_binary_hash_unchanged': True,
    'cleanup_complete': True, 'post_exit_observed_seconds': o['post_exit_observed_seconds'],
    'native_probe_count': o['native_probe_count'], 'native_failure': False, 'power_unchanged': True,
    'initial_boot_id': o['initial_boot_id'], 'final_boot_id': o['final_boot_id'], 'sleep_restored': True,
    'qualified': False, 'application_qualification': False, 'release_qualified': False, 'source_final': False,
    'production_modified': False, 'eight_hour_started': False, 'no_new_Linux_programs_started_by_audit': True}
report_path.write_text(json.dumps(report, indent=2), encoding='utf-8')
c.update(status=report['status'], actual_windows_exec_session=92942, actual_windows_exit_code=0,
    build_started=True, cleanup_complete=True, observation=str(op), observation_sha256=sha(op),
    output_sha256=o['output_sha256'], mechanical_audit=str(report_path), mechanical_audit_sha256=sha(report_path),
    qualified=False, application_qualification=False, release_qualified=False, source_final=False)
cp.write_text(json.dumps(c, indent=2), encoding='utf-8')
print(json.dumps({'status': report['status'], 'report_sha256': sha(report_path), 'context_sha256': sha(cp),
                  'zip_sha256': m['zip_sha256'], 'updater_sha256': m['updater_sha256'], 'source_files': 198}))
