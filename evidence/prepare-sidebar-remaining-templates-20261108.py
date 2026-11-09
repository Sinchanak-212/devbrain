"""Author public Windows metadata only; no application imports or process launches."""
import copy
import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path

W = Path(__file__).resolve().parent.parent
E = W/'evidence'
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p, digest=None):
    if digest is not None: assert sha(p) == digest, Path(p).name
    return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def put(p, data):
    p = Path(p)
    assert p.parent.resolve() == p.parent.absolute() and not p.exists()
    with p.open('xb') as f:
        f.write(data); f.flush(); os.fsync(f.fileno())
    return sha(p)
def js(p, o): return put(p, (json.dumps(o, ensure_ascii=False, indent=2)+'\n').encode())
def cp(p, target, digest):
    assert sha(p) == digest
    assert put(target, Path(p).read_bytes()) == digest
    assert sha(p) == digest

old_path = E/'080-length-repair-remaining-gate-templates-604-20261108.json'
old_sha = 'c9576982a7b550b0991dd6edfccf98cc87abd3c776ad572da4f4730e1c3b0a0c'
old = read(old_path, old_sha)
old_freeze = read(old['input_freeze'], old['input_freeze_sha256'])
for rel, digest in old_freeze['files'].items(): assert sha(Path(old['windows_root'])/rel) == digest
app_path = E/'080-app-ux-snapshot-active-context.json'
app_sha = 'd0a5b7e2682cd3f540fcce87446517fb8a11b6712f689aeb6df6dfbf562c771c'
app = read(app_path, app_sha)
assert app['run_id'] == 'app080-20261108T222731Z' and app['status'] == 'prepared_passed' and app['actual_windows_exit_code'] == 0
source = read(app['freeze_manifest'], app['freeze_sha256'])
assert len(source['files']) == 209 and sum(k.startswith('devbrain/') for k in source['files']) == 198
for rel, digest in source['files'].items(): assert sha(Path(app['bundle_root'])/rel) == digest
read(app['setup_receipt'], app['setup_receipt_sha256'])
for name, digest in old['helper_sha256'].items(): assert sha(W/'release-tools'/name) == digest
build_path = E/'080-final-candidate-build-ready-context-v8-20261108.json'
build_sha = '6d6ce8780c9c4fa9d04d3bfbfca3f2fe1852c1390122605dc5513a82eb2a118b'
build = read(build_path, build_sha)
assert build['actual_windows_exit_code'] == 0 and build['cleanup_complete'] is True
assert build['source_freeze_sha256'] == app['freeze_sha256'] and build['root_output_review_passed'] is True
read(build['observation'], build['observation_sha256'])
assert len(build['output_sha256']) == 4
for rel, digest in build['output_sha256'].items(): assert sha(Path(build['windows_root'])/rel) == digest
candidate = dict(context=str(build_path),context_sha256=build_sha,directory=build['candidate_directory'],observation=build['observation'],observation_sha256=build['observation_sha256'],output_sha256=build['output_sha256'],qualified=False,actual_windows_exit_code=0)
root = E/'sidebar-resize-remaining-gate-templates-604-20261108'
assert not root.exists()
root.mkdir(); (root/'inputs').mkdir()
files = {}
def inp(name,p,digest):
    cp(p,root/'inputs'/name,digest);files['inputs/'+name] = digest
inp('app-context.json',app_path,app_sha)
inp('source-freeze.json',app['freeze_manifest'],app['freeze_sha256'])
inp('prepare-receipt.json',app['setup_receipt'],app['setup_receipt_sha256'])
inp('candidate-v8-context.json',build_path,build_sha)
inp('candidate-v8-observation.json',build['observation'],build['observation_sha256'])
inp('previous-template-master.json',old_path,old_sha)
inp('runtime-gate.json',Path(old['windows_root'])/'inputs/runtime-gate.json',old['runtime_gate_sha256'])
inp('runtime-only-fixtures.json',old['runtime_only_fixtures']['path'],old['runtime_only_fixtures']['sha256'])
old_proof_path = E/'080-length-repair-eight-hour-proof-manifest-after-ux-20261108.json'
inp('previous-partial-proof-NOT-current.json',old_proof_path,'e494c73a75c42a658fdca6f66a02dfc38e6db43686cb27f9e0e46e2a3d37a4ed')
bases = [
    (E/'stage-five-length-final-gates-after-ui-v2-20261108.ps1','f06db0400e3d7c02f68bd48930458156aa417808a456056c046bd96ad49294bd'),
    (E/'stage-final-eight-hour-length-repair-604-v3-20261108.ps1','c5acbb4670305e9dae7a878be6c7571945bb06089774fc3622b3283bd0c289e9'),
]
for i,(p,h) in enumerate(bases): inp(f'previous-materializer-{i}.ps1',p,h)
inp('strict-visual-admission-peer.json',E/'080-ui-visual-acceptance-admission-peer-review-20261108.json','0341139d5498efa57b6fa87aeae211f5b425356d0012412681a77ea3778a7afd')
def retarget(o):
    s = json.dumps(o)
    for a,b in [(old['source_snapshot'],app['run_id']),(old['source_freeze_sha256'],app['freeze_sha256']),(old['app_prepare_receipt_sha256'],app['setup_receipt_sha256'])]: s=s.replace(a,b)
    return json.loads(s)
templates={}
for name,entry in old['templates'].items():
    original=read(entry['path'],entry['sha256']);inp(f'previous-{name}.template.json',entry['path'],entry['sha256'])
    t=retarget(original)
    t.update(scope='devbrain_sidebar_resize_gate_template',status='prepared_not_run_pending_current604_fullbackend_and_visual_UI',created_utc=datetime.now(timezone.utc).isoformat(),candidate_binding=candidate)
    t['current_full_backend_binding']['expected_count']=1561
    t['current_ux_binding']['expected_cases']=381
    t['current_ui_binding']['visual_acceptance_passed_required']=True
    if name=='upgrade_smoke':
        argv=t['specification_template']['argv']
        argv[argv.index('--release-dir')+1]=build['linux_root']+'/releases/candidates/0.8.0'
        argv[argv.index('--baseline-zip')+1]=build['linux_root']+'/releases/devbrain-0.7.2.zip'
        for label,leaf in [('updater','devbrain-update-0.8.0.py'),('zip','devbrain-0.8.0.zip'),('manifest','devbrain-update-0.8.0-manifest.json')]:
            t['acceptance']['candidate_'+label+'_sha256']=build['output_sha256']['releases/candidates/0.8.0/'+leaf]
    if name=='soak':
        t['eight_hour_launch_permitted_this_session']=False
        t['next_session_preflight_required']=['Current source/helper/runtime binary hashes','Fresh boot identity; no new native failures or dumps','Qualified Balanced fingerprint and power settings','Account quota above user stop threshold','One uninterrupted28800s trial; restart after poweroff, never pool intervals']
    p=root/(name+'.template.json');h=js(p,t);files[p.name]=h;templates[name]={'path':str(p),'sha256':h}
    expected=retarget(original)['specification_template']
    if name=='upgrade_smoke':
        a=expected['argv'];a[a.index('--release-dir')+1]=build['linux_root']+'/releases/candidates/0.8.0';a[a.index('--baseline-zip')+1]=build['linux_root']+'/releases/devbrain-0.7.2.zip'
    assert t['specification_template']==expected
assert len(files)==24
freeze_path=root/'template-input-freeze.json'
freeze_sha=js(freeze_path,dict(schema_version=1,scope='devbrain_sidebar_resize_gate_template_inputs',files=files,helper_sha256=old['helper_sha256'],source_freeze_sha256=app['freeze_sha256']))
master=retarget(old)
master.update(scope='devbrain_sidebar_resize_gate_templates',windows_root=str(root),input_freeze=str(freeze_path),input_freeze_sha256=freeze_sha,input_file_count=len(files),templates=templates,candidate_binding=candidate,expected_backend_cases=1561,expected_ux_cases=381,eight_hour_launch_permitted_this_session=False)
master_path=E/'080-sidebar-resize-remaining-gate-templates-604-20261108.json'
master_sha=js(master_path,master)
proof=read(E/'080-length-repair-eight-hour-proof-manifest-template-20261108.json')
proof.update(scope='devbrain_sidebar_resize_eight_hour_prerequisites',template_master_sha256=master_sha,source_freeze_sha256=app['freeze_sha256'],status='pending_all_actual_current_source_application_proofs',eight_hour_launch_permitted_this_session=False)
proof['guard']={k:None for k in proof['guard']}
proof['standalone']['final_report']=None
proof['note']='Fill a NEW immutable proof manifest only with current222731 actual context/receipt/report hashes. Canonical1561 stays in its actual backend artifact root. UI requires literal visual_acceptance_passed=true. NO8h this session; next session fresh boot/runtime/power/native/quota checks and a new uninterrupted trial are mandatory.'
proof_path=E/'080-sidebar-resize-eight-hour-proof-manifest-template-20261108.json'
proof_sha=js(proof_path,proof)
changes=[('length-repair','sidebar-resize'),('length_repair','sidebar_resize'),('length-final','sidebar-final'),(old['source_snapshot'],app['run_id']),(old['source_freeze_sha256'],app['freeze_sha256']),(old_sha,master_sha),('1557','1561'),('377','381'),('v7','v8')]
stagers={}
for i,(base,digest) in enumerate(bases):
    s=base.read_bytes().decode('utf-8-sig')
    for a,b in changes:s=s.replace(a,b)
    if i==0:
        s=s.replace('[string]$UiFinalReportSha256)', '[string]$UiFinalReportSha256,[string]$ProofManifest,[string]$ProofManifestSha256)')
        old_assign="$ProofManifest=Join-Path $workspace 'evidence/080-sidebar-resize-eight-hour-proof-manifest-after-ux-20261108.json'"
        assert s.count(old_assign)==1
        s=s.replace(old_assign,"if(-not $ProofManifest){$ProofManifest=Join-Path $workspace 'evidence/080-sidebar-resize-eight-hour-proof-manifest-template-20261108.json'}")
        s=s.replace("$ProofManifestSha256='e494c73a75c42a658fdca6f66a02dfc38e6db43686cb27f9e0e46e2a3d37a4ed'", "if(-not $ProofManifestSha256){$ProofManifestSha256='"+proof_sha+"'}")
        path=E/'stage-five-sidebar-final-gates-after-ui-20261108.ps1'
    else:path=E/'stage-final-eight-hour-sidebar-resize-604-20261108.ps1'
    assert s.count("'Actual root visual acceptance required'")==1
    h=put(path,s.encode());stagers['next5' if i==0 else 'eight_hour']={'path':str(path),'sha256':h}
report=dict(schema_version=1,scope='devbrain_sidebar_remaining_conditional_preparation',status='prepared_not_run',master=str(master_path),master_sha256=master_sha,proof_manifest=str(proof_path),proof_manifest_sha256=proof_sha,stagers=stagers,verified_input_files=24,verified_helper_files=38,verified_app_files=198,verified_source_freeze_files=209,source_snapshot=app['run_id'],source_freeze_sha256=app['freeze_sha256'],app_prepare_receipt_sha256=app['setup_receipt_sha256'],candidate_context_sha256=build_sha,current_guard_passed=False,current_backend_passed=False,current_UI_passed=False,actual_new_proofs=None,stage_invoked=False,linux_started=False,application_or_helper_code_modified=False,eight_hour_launch_permitted_this_session=False,production_modified=False,history_preserved=True,next5_new_parameter_contract='Optional exact completed ProofManifest/ProofManifestSha256; default pending NULL proof cannot pass admission',expected_counts={'guards':604,'backend':1561,'ux':381,'ux_modules':28},todo_before_next_session_8h=['Complete every current-source pre8h gate; persist all exact proofs','Root shutdown only after safe cleanup and handoff; production072 staysSTOPPED','Reboot: fresh runtime/source/power/boot/native/quota checks; no resumed intervals','Require actual current visual_acceptance_passed boolean true and all eight functional proofs','Stage only from completed immutable proof manifest; never launch8h this session'])
report_path=E/'080-sidebar-remaining-conditional-preparation-20261108.json'
report_sha=js(report_path,report)
print(json.dumps({'master_sha256':master_sha,'proof_sha256':proof_sha,'stagers':stagers,'preparation_sha256':report_sha}))
