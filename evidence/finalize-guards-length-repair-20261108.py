"""Windows artifact-only review; no application imports or process creation."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import runpy
import uuid
import xml.etree.ElementTree as ET
from datetime import datetime, timezone


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--finalize', action='store_true')
    parser.add_argument('--root-session', type=int)
    parser.add_argument('--root-actual-exit', type=int)
    args = parser.parse_args()
    if not args.finalize:
        print('NOT_RUN: requires recorded root76710 actual exit0.')
        return
    if os.name != 'nt' or args.root_session != 76710 or args.root_actual_exit != 0:
        raise ValueError('Windows review requires root76710 actual exit0')
    evidence = Path(__file__).resolve().parent
    utility = evidence / 'finalize-fullbackend-task-state-20261108.py'
    if hashlib.sha256(utility.read_bytes()).hexdigest() != '5364acd99969f32aee7ebd47e1df2badbb2eb0f5e32e7946b86d35efdc156b3f':
        raise ValueError('Reviewed artifact-reader functions changed')
    api = runpy.run_path(str(utility))
    require, digest, document, verify, verify_map, fresh_json = (
        api[name] for name in ('require', 'digest', 'document', 'verify', 'verify_map', 'fresh_json'))
    context_path = evidence / '080-guards-queue-budget-active-context-20261108.json'
    before_sha = digest(context_path)
    c = document(context_path)
    require(c['run_id'] == 'guards-length-repair080-20261108T203656Z'
            and c['status'] == 'finished_pending_evidence_review'
            and type(c['actual_windows_exit_code']) is int and c['actual_windows_exit_code'] == 0,
            'Root has not recorded this actual successful completion')
    root, artifacts = Path(c['windows_root']), Path(c['artifact_root'])
    verify(c['freeze_manifest'], '799680c55a32fc5354b5a10d8da68c4dd54c13d6d79bb636f0f88bf53794648f')
    freeze = document(c['freeze_manifest'])
    require(len(freeze['files']) == freeze['total_files'] == 56, 'Wrong frozen input count')
    verify_map(root, freeze['files'])
    verify(c['input_manifest'], c['input_manifest_sha256'])
    verify(c['specification'], '3ca1cb1b01c4f6ccee0f17bca2a8167676b4f5c5a1004c6ae227e2f60db8e812')
    spec = document(c['specification'])
    expected_argv = ['--execute', '--phase', 'guards', '--run-id', c['run_id'], '--artifact-root',
                     c['linux_artifact_root'], '--source-root', c['source_root'], '--private-root',
                     c['private_root'], '--updater', c['linux_root'] + '/candidate/devbrain-update-0.8.0.py']
    require(spec['argv'] == expected_argv and spec['python_launcher'] == c['python_launcher']
            and spec['run_id'] == c['run_id'], 'Exact guard specification differs')
    require(spec['env'] == {'LANG': 'C.UTF-8', 'LC_ALL': 'C.UTF-8', 'TMPDIR': '/tmp'}, 'Environment differs')
    helpers = c['helper_sha256']
    require(len(helpers) == 38 and helpers == c['reviewed_helper_sha256'] == freeze['helper_files'], 'Helper map differs')
    verify_map(c['windows_tools'], helpers)
    verify(c['previous_active_context_archive'], '7e1b2c594bbdd2355ff182192561ed5544f39efeba538d3ccb0d70d428550223')
    require(document(c['previous_active_context_archive'])['helper_sha256'] == helpers, 'Instrumentation changed')
    rows = {n: document(artifacts / n) for n in ('receipt.json', 'supervisor-report.json', 'controller-report.json',
            'regression-source.json', 'regressions-results.json', 'guards-collection.json', 'gate.json')}
    receipt, supervisor, controller, source, results, collection, gate = (
        rows[n] for n in ('receipt.json', 'supervisor-report.json', 'controller-report.json', 'regression-source.json',
                         'regressions-results.json', 'guards-collection.json', 'gate.json'))
    for name, row in rows.items():
        if name != 'gate.json':
            require(row['run_id'] == c['run_id'], 'Cross-run artifact')
    for row in (receipt, supervisor):
        require(row['passed'] is True and row['child_returncode'] == 0 and row['controller_exit_verified'] is True,
                'Actual child success missing')
        require(row['cleanup_complete'] is True and row['forced_cleanup'] is False and row['native_failure'] is False,
                'Cleanup/native failure')
        require(row['errors'] == row['new_wsl_dumps'] == row['new_kernel_fatals'] == [], 'Error or native delta')
        require(row['initial_boot_id'] == row['final_boot_id'] == receipt['initial_boot_id'], 'Boot changed')
        require(row['runtime'] == gate['runtime'] and row['python_launcher'] == c['python_launcher'], 'Runtime changed')
        require(row['helper_sha256_start'] == row['helper_sha256_end'], 'Helper changed during run')
        require(all(helpers[n] == h for n, h in row['helper_sha256_start'].items()), 'Unqualified runtime helper')
        require(row['gate_sha256'] == c['gate_sha256'], 'Wrong runtime gate')
    require(receipt['supervisor_returncode'] == receipt['windows_proxy_returncode'] == 0
            and receipt['supervisor_exit_verified'] is True, 'Supervisor/proxy actual exit missing')
    require(receipt['scope_empty_verified'] is True and receipt['scope_membership_verified'] is True
            and receipt['scope_cleanup_grace_seconds'] >= 30 and receipt['cleanup_grace_seconds'] >= 30, 'Quiet window missing')
    require(receipt['scope_unit'] == supervisor['scope_unit'] and receipt['scope_cgroup_identity'] == supervisor['scope_cgroup_identity']
            and receipt['control_group'] == supervisor['control_group'], 'Scope ownership changed')
    require(supervisor['remaining_scope_processes'] == supervisor['remaining_tagged_processes'] == []
            and supervisor['scope_descendants_stopped'] is True, 'Owned descendants remain')
    require(receipt['input_sha256_start'] == receipt['input_sha256_end'], 'Observer input changed')
    require(receipt['input_sha256_start'] == {'gate': c['gate_sha256'], 'arguments': c['specification_sha256'],
            'launcher': helpers['run-supervised-080.ps1'], 'supervisor': helpers['supervise-080.py']}, 'Observed inputs differ')
    require(receipt['controller_sha256_start'] == receipt['controller_sha256_end'] == supervisor['controller_sha256']
            == supervisor['controller_sha256_end'] == helpers['run-regressions-080.py'], 'Controller bytes changed')
    verify(artifacts / 'gate.json', c['gate_sha256'])
    verify(artifacts / 'controller-report.json', supervisor['controller_report_sha256'])
    require(set(receipt['artifact_sha256']) == set(spec['required_artifacts']) | {'power-samples.jsonl'}, 'Artifact coverage differs')
    verify_map(artifacts, receipt['artifact_sha256'])
    require(receipt['sleep_inhibition']['restored'] is True and receipt['power_monitor']['changed'] is False, 'Power restoration failed')
    require(receipt['power_profile_start'] == receipt['power_profile_end'] == gate['power_profile'], 'Power profile changed')
    power = [json.loads(line) for line in (artifacts / 'power-samples.jsonl').read_text().splitlines() if line.strip()]
    require(len(power) == receipt['power_monitor']['sample_count'] and len(power) >= 2, 'Power samples incomplete')
    require(all(p['state'] == gate['power_profile'] for p in power), 'Power sample differs')
    require(all(0 <= b['elapsed_seconds'] - a['elapsed_seconds'] <= receipt['power_monitor']['maximum_gap_seconds']
                for a, b in zip(power, power[1:])), 'Power monitoring gap')
    require(power[-1]['elapsed_seconds'] >= max(receipt['power_monitor']['supervisor_exit_elapsed_seconds'],
            receipt['power_monitor']['scope_empty_elapsed_seconds']) + 30, 'Final power sample too early')
    require(controller['scope'] == 'devbrain_targeted_regressions' and controller['phase'] == results['phase'] == source['phase'] == 'guards'
            and controller['status'] == 'regressions_completed_pending_external_watch' and results['status'] == 'passed', 'Guard status differs')
    require(controller['workload_criteria_passed'] is True and controller['cleanup_complete'] is True
            and controller['forced_cleanup'] is False and controller['errors'] == [], 'Controller failed')
    require(controller['controller_exit_verified'] is False and controller['full_suite_pass'] is False
            and controller['eight_hour_qualification'] is False, 'Raw pending flags changed')
    require(controller['guard_sources'] == source['guard_sources'] == {'helper_sha256': helpers, 'updater': expected_argv[-1],
            'updater_sha256': c['updater_sha256']}, 'Full guard-source map differs')
    require(controller['runtime'] == source['runtime'] == gate['runtime']
            and controller['runtime_gate_sha256'] == c['gate_sha256'], 'Controller runtime differs')
    counts = results['counts']
    require(counts['collected'] == counts['passed'] == 604, 'Incomplete604')
    require(all(counts[k] == 0 for k in ('failures', 'errors', 'skipped', 'unexpected_skips', 'duplicates', 'missing'))
            and counts['expected_skips'] == counts['observed_skips'] == {}, 'Nonpassing cases')
    require(results['individual_test_selectors'] == [] and results['normal_conftest'] is False
            and results['skips_permitted'] == 0 and collection['collection_errors'] == collection['deselected'] == [], 'Filtered guard collection')
    require(len(results['modules']) == len(collection['modules']) == len(freeze['test_modules']) == 12
            and set(results['modules']) == set(collection['modules']) == set(freeze['test_modules']), 'Module inventory differs')
    require(all(results['processes'][k]['returncode'] == 0 and results['processes'][k]['actual_exit_verified'] is True
                for k in ('collect', 'test')), 'Pytest actual exits missing')
    require(len(collection['nodeids']) == len(set(collection['nodeids'])) == 604, 'Collection not unique604')
    xml = ET.parse(artifacts / 'guards.xml').getroot()
    cases, suites = xml.findall('.//testcase'), xml.findall('.//testsuite')
    require(len(cases) == sum(int(s.attrib['tests']) for s in suites) == 604, 'JUnit count differs')
    require(not xml.findall('.//failure') and not xml.findall('.//error') and not xml.findall('.//skipped'), 'JUnit not all passed')
    nodeids = []
    for case in cases:
        values = [p.attrib['value'] for p in case.findall('./properties/property') if p.attrib.get('name') == 'nodeid']
        require(len(values) == 1, 'Missing or ambiguous JUnit nodeid')
        nodeids.append(values[0])
    require(len(set(nodeids)) == 604 and set(nodeids) == set(collection['nodeids']), 'JUnit/collection nodeids differ')
    app = document(evidence / '080-app-ux-snapshot-active-context.json')
    require(app['run_id'] == c['app_run_id'] == 'app080-20261108T202627Z' and app['status'] == 'prepared_passed'
            and app['actual_windows_exit_code'] == 0 and app['qualified_package_pin_count'] == 59
            and app['pins_unchanged'] is True and app['linux_source_matches_freeze'] is True, 'App preparation missing')
    verify(c['app_freeze'], '1f35dae9f2b3f894bb67535a215e29cba3c1235120ff30daa387bd5450f03e14')
    verify(c['app_prepare_receipt'], '4e18e967ea94bbe43c807e86c65c9d46a2d7205241a9713a7b6406dc8a97526e')
    app_freeze = document(c['app_freeze'])
    require(app_freeze['app_files'] == 198 and len(app_freeze['files']) == 209, 'App inventory differs')
    verify_map(app['bundle_root'], app_freeze['files'])
    expected_source = {name.removeprefix('devbrain/'): value for name, value in app_freeze['files'].items()
                       if name in {'devbrain/pyproject.toml', 'devbrain/uv.lock'} or name.startswith(('devbrain/src/', 'devbrain/tests/', 'devbrain/data/'))}
    require(len(expected_source) == 153 and controller['source_hashes'] == source['source_hashes'] == expected_source, 'Frozen source map differs')
    prep = document(c['app_prepare_receipt'])
    workload_path = Path(c['app_prepare_receipt']).parent / 'workload-report.json'
    verify(workload_path, prep['workload_report_sha256'])
    identity = document(workload_path)['installed_identity']
    require(len(identity['packages']) == 59 and identity['prefix'] + '/bin/python' == c['python_launcher']
            and prep['passed'] is True and prep['cleanup_complete'] is True, 'Prepared pins/prefix differ')
    verify(c['candidate_build_context'], 'cdd27ef8e5326c85ab4f85af562b2826c20f3b63cfd07c454441cb3fbf7766d6')
    report = {'schema_version': 1, 'scope': 'devbrain_length_repair_tooling_guards', 'status': 'passed',
              'recorded_utc': datetime.now(timezone.utc).isoformat(), 'run_id': c['run_id'], 'source_snapshot': app['run_id'],
              'app_freeze_sha256': c['app_freeze_sha256'], 'app_prepare_receipt_sha256': c['app_prepare_receipt_sha256'],
              'receipt': str(artifacts / 'receipt.json'), 'receipt_sha256': digest(artifacts / 'receipt.json'),
              'freeze_sha256': c['freeze_sha256'], 'junit_sha256': digest(artifacts / 'guards.xml'),
              'collection_sha256': digest(artifacts / 'guards-collection.json'), 'tests': 604, 'modules': 12, 'helpers': 38,
              'failures': 0, 'errors': 0, 'skipped': 0, 'missing': 0, 'duplicates': 0,
              'test_seconds': sum(float(s.attrib['time']) for s in suites), 'actual_windows_exit_code': 0,
              'actual_windows_exec_session': 76710, 'actual_windows_exit_evidence': 'Parent root confirmed exec session76710 actual EXIT0; current context records actual exit0',
              'controller_exit_verified': True, 'supervisor_exit_verified': True, 'child_returncode': 0, 'supervisor_returncode': 0,
              'cleanup_complete': True, 'forced_cleanup': False, 'scope_empty_verified': True,
              'scope_quiet_seconds': receipt['scope_cleanup_grace_seconds'], 'external_post_exit_seconds': receipt['cleanup_grace_seconds'],
              'initial_boot_id': receipt['initial_boot_id'], 'final_boot_id': receipt['final_boot_id'], 'native_failure': False,
              'power_changed': False, 'sleep_inhibition_restored': True, 'verified_frozen_input_count': 56,
              'verified_source_file_count': 198, 'verified_total_source_file_count': 209, 'verified_receipt_artifact_count': 8,
              'verified_backend_source_file_count': 153, 'verified_package_pin_count': 59,
              'junit_collection_nodeids_exact': True, 'all_helper_runtime_input_start_end_hashes_match': True,
              'unobservable_outside_owned_scope_process_count': len(supervisor['unobservable_external_processes']),
              'historical_results_pooled': False, 'production_modified': False, 'application_qualified': False,
              'release_qualified': False, 'context_before_review_sha256': before_sha}
    report_path = evidence / '080-guards-length-repair-final-20261108.json'
    report_sha = fresh_json(report_path, report)
    c.update(status='passed', actual_windows_exec_session=76710, actual_test_count=604,
             receipt=report['receipt'], receipt_sha256=report['receipt_sha256'], final_report=str(report_path),
             final_report_sha256=report_sha, cleanup_complete=True, forced_cleanup=False, native_failure=False,
             scope_empty_verified=True, evidence_review_finished_utc=report['recorded_utc'])
    pending = context_path.with_name(context_path.name + '.' + uuid.uuid4().hex + '.verified')
    context_sha = fresh_json(pending, c)
    require(digest(context_path) == before_sha, 'Context changed during review')
    os.replace(pending, context_path)
    require(digest(context_path) == context_sha, 'Published context differs')
    print(json.dumps({'context_sha256': context_sha, 'report_sha256': report_sha,
                      'receipt_sha256': report['receipt_sha256'], 'tests': 604, 'status': 'passed'}, indent=2))


if __name__ == '__main__':
    main()
