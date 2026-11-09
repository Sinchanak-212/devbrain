"""Windows-only cross-hash audit after actual standalone metadata attestation."""
import hashlib
import json
from pathlib import Path
w = Path(__file__).resolve().parent.parent
read = lambda p: json.loads(Path(p).read_text(encoding='utf-8-sig'))
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
ep = w / 'evidence/080-standalone-native-failure-attestation-envelope-20261109.json'
assert sha(ep) == '937d937bc0c88ee37b00c0f6a36d2c85e80dd7a15a66faf2e8d9054f24802e65'
e = read(ep)
op = Path(e['artifact_root']) / 'attestation-observation.json'
o = read(op)
assert o['status'] == 'attestation_generated_observed'
assert o['scope'] == 'devbrain_standalone_attestation_process_observation' and o['run_id'] == e['run_id']
assert o['backend_run_id'] == e['backend_run_id']
assert all(o[k] is True for k in ('passed','cleanup_complete','actual_exit_verified','stdio_complete','attestation_validated'))
assert all(o[k] is False for k in ('qualified','application_qualification','production_modified','registered_controller','manual_pid_birth_cleanup_admission_required'))
assert type(o['actual_proxy_exit']) is int and o['actual_proxy_exit'] == 0 and o['errors'] == []
assert o['post_exit_observed_seconds'] >= 30 and o['native_probe_count'] >= 2
assert o['initial_boot_id'] == o['final_boot_id'] and o['power_start'] == o['power_end']
assert o['power_start']['active_guid'] == '381b4222-f694-41f0-9685-ff5bb260df2e'
assert o['power_start']['settings_sha256'] == '6bac59f1660b69c8c9e8d83728cbb7cf2fd184458181fa05a351b72c4c2d9dc1'
assert o['sleep_inhibition']['acquired'] is True and o['sleep_inhibition']['restored'] is True
assert sha(e['admission_freeze']) == e['admission_sha256'] == o['input_freeze_sha256']
assert sha(e['launcher_freeze']) == e['launcher_freeze_sha256'] == o['launcher_freeze_sha256']
for field in ('seed_freeze','plan','launcher','materializer'):
    assert sha(e[field]) == e[field + '_sha256']
for field in ('admission_freeze','launcher_freeze','seed_freeze'):
    for rel, digest in read(e[field])['files'].items():
        assert sha(Path(e['windows_root']) / rel) == digest
for name, digest in e['helper_sha256'].items():
    assert sha(Path(read(e['plan'])['tools']) / name) == digest
assert len(e['helper_sha256']) == 38
b = read(e['backend_context'])
assert sha(e['backend_context']) == e['actual_backend_context_sha256'] == '8a4b0c1a1a3074d98f9e3bd04069607bcf008ab2b122ec5cd4a6fb8c4c18d37e'
assert b['actual_windows_exec_session'] == 74540 and b['actual_windows_exit_code'] == 0
assert b['actual_test_count'] == 1605 and b['cleanup_complete'] is True
assert sha(b['receipt']) == e['actual_backend_receipt_sha256'] == '9416368767ed5d6ec8eee6486da9f868ee6350ebc1c5231300b242b0d6343d6b'
r = read(b['receipt'])
assert sha(b['final_report']) == b['final_report_sha256'] == '106bb67cfd1338b26041d547192cc1ba6b6939cd69ab9911c07d8bca4340430b'
for rel, digest in r['artifact_sha256'].items():
    assert sha(Path(b['artifact_root']) / rel) == digest
fp = Path(e['canonical_output'])
f = read(fp)
assert sha(fp) == o['output_sha256']['final-full-suite.json'] == '281b4067bff2e9f7873c06aa38e4203d16b69524dbf6b772d8e748704dc1c149'
assert f['scope'] == 'devbrain_final_full_suite_attestation' and f['final_full_suite_pass'] is True
assert f['run_id'] == b['run_id'] and f['artifact_root'] == b['linux_artifact_root']
assert f['external_receipt_sha256'] == sha(b['receipt'])
assert f['counts'] == b['counts'] and f['counts']['collected'] == f['counts']['passed'] == 1605
assert all(f['counts'][k] == 0 for k in ('skipped','failures','errors','unexpected_skips','duplicates','missing'))
frozen = read(Path(b['artifact_root']) / 'frozen-source.json')
assert f['source_hashes'] == frozen['source_hashes'] and len(f['source_hashes']) == 153
assert f['runtime'] == frozen['runtime'] == b['runtime']
for rel, digest in f['artifact_sha256'].items():
    assert sha(Path(b['artifact_root']) / rel) == digest
for rel, digest in f['source_hashes'].items():
    assert sha(Path('//wsl.localhost/Ubuntu' + b['source_root']) / rel) == digest
for name in ('python','java','tmux'):
    assert sha(Path('//wsl.localhost/Ubuntu' + f['runtime'][name + '_executable'])) == f['runtime'][name + '_binary_sha256']
out = w / 'evidence/080-full-suite-native-failure-attestation-final-20261109.json'
assert not out.exists()
report = {'schema_version':1,'scope':'canonical_full_backend_attestation_and_actual_observation',
    'status':'passed','run_id':e['run_id'],'backend_run_id':b['run_id'],
    'actual_windows_exec_session':49295,'actual_windows_exit_code':0,'actual_final_chunk':'9e678e',
    'backend_actual_windows_exec_session':74540,'backend_actual_windows_exit_code':0,
    'canonical_attestor_sha256':e['helper_sha256']['attest-full-suite-080.py'],
    'attestation':str(fp),'attestation_sha256':sha(fp),'counts':f['counts'],
    'observation':str(op),'observation_sha256':sha(op),'backend_context_sha256':sha(e['backend_context']),
    'backend_receipt_sha256':sha(b['receipt']),'backend_audit_sha256':sha(b['final_report']),
    'source_freeze_sha256':b['source_freeze_sha256'],'source_hashes_verified':153,'canonical_helper_count':38,
    'cleanup_complete':True,'post_exit_observed_seconds':o['post_exit_observed_seconds'],
    'native_probe_count':o['native_probe_count'],'native_failure':False,'power_unchanged':True,
    'boot_unchanged':True,'sleep_restored':True,'registered_controller':False,
    'application_qualified':False,'release_qualified':False,'source_final':False,
    'full_backend_criterion_passed_on_source9e':True,'eight_hour_started':False,'production_modified':False,
    'tests_models_accounts_or_DB_started_by_attestation':False,'canonical_backend_artifacts_preserved':True}
out.write_text(json.dumps(report,indent=2),encoding='utf-8')
e.update(status='passed',actual_windows_exec_session=49295,actual_windows_exit_code=0,
    cleanup_complete=True,linux_workload_started=True,launch_permitted=True,attestation=str(fp),
    attestation_sha256=sha(fp),observation=str(op),observation_sha256=sha(op),final_report=str(out),
    final_report_sha256=sha(out),application_qualified=False,release_qualified=False,qualified=False)
ep.write_text(json.dumps(e,indent=2),encoding='utf-8')
print(json.dumps({'status':'passed','report_sha256':sha(out),'envelope_sha256':sha(ep),
                  'attestation_sha256':sha(fp),'observation_sha256':sha(op),'count':1605}))
