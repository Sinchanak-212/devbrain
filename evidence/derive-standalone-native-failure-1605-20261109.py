"""Mechanical new-source attestation envelope derivation; filesystem only."""
import hashlib
import json
from pathlib import Path
w = Path(__file__).resolve().parent.parent
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
oldp = w / 'evidence/stage-standalone-sidebar-resize-1561-20261109.ps1'
old = oldp.read_text(encoding='utf-8-sig')
text = old
replacements = {
 'standalone1561': 'standalone1605',
 '080-standalone-length-repair-attestation-prepared-context-20261108.json': '080-standalone-sidebar-resize-attestation-prepared-context-20261109.json',
 '8598f2e8e68cd91f60d609617777ee082133e82346ab95de3dcaaed549b195ce': 'dd0b9167aefc8729ffd7ce3a218d23fc257fef890cf419bf0e8f4d6e3b4aea4b',
 'c7e8ca2373c32d22cb0113b902dc8c4fb13b0cdd19f2e69b09e8ab0564690b4f': '174a7e601b9b991a5baa02fe1bac109e78ec8c62e1b4aac61ed0b25cbb7572c7',
 'de263bb59d27fa73e63a4f590f99e6169ea6d83375b4425b3c9310b93b4da7a6': '5f866de6f81c19b9a560c482510ec12305d7a7ecd71692f03123b52193a5cf94',
 '080-fullbackend-sidebar-resize-active-context-20261108.json': '080-fullbackend-native-failure-diagnostic-active-context-20261109.json',
 '54c47944a9d53fdbea1d546d56e470b6641403a1bdf07183247d7e4b10830782': '8a4b0c1a1a3074d98f9e3bd04069607bcf008ab2b122ec5cd4a6fb8c4c18d37e',
 "$b.status-ceq'passed'": "$b.status-ceq'diagnostic_passed_not_release_qualified'",
 '1561': '1605', '56737': '74540',
 '3befefb2a484b86e39da8ed25973b62e37bf812a5c117aafca680c0a12b39da0': '9416368767ed5d6ec8eee6486da9f868ee6350ebc1c5231300b242b0d6343d6b',
 '90272cf32524a02a4c80d3c47203728748ebd924d89152df72cc58a3cab104a3': '106bb67cfd1338b26041d547192cc1ba6b6939cd69ab9911c07d8bca4340430b',
 'ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703': '9e5168bece45cf3c06bd0abded7e1573b51cf55778570fdc49c8e0a8872e81b9',
 '4cba08753a5d44463687271f5e695ccddac4d2284ca348b66630f480facde918': 'fc63c2782c515d63e8c6e45b1c130d8a16b43904a8b6a050163b4034552db0bd',
 '080-standalone-sidebar-resize-attestation-prepared-context-20261109.json': '080-standalone-native-failure-attestation-prepared-context-20261109.json',
 'suite-attest-sidebar-envelope-': 'suite-attest-native-failure-envelope-',
}
# The previous prepared envelope remains the reference, not the new destination.
for before, after in replacements.items():
    assert before in text, before
    text = text.replace(before, after)
text = text.replace("$oldPath=Join-Path $workspace 'evidence/080-standalone-native-failure-attestation-prepared-context-20261109.json'",
                    "$oldPath=Join-Path $workspace 'evidence/080-standalone-sidebar-resize-attestation-prepared-context-20261109.json'")
# The reference launcher already binds positive session dynamically. Its only
# new semantic input is the honest diagnostic completion status of this source.
line = "$launcher=[IO.File]::ReadAllText($old.launcher).Replace($old.windows_root,$root).Replace((ReadMap $old.plan).tools,$g.windows_tools).Replace('1557','1605')"
assert line in text
text = text.replace(line, "$launcher=[IO.File]::ReadAllText($old.launcher).Replace($old.windows_root,$root).Replace((ReadMap $old.plan).tools,$g.windows_tools).Replace('1561','1605').Replace(\"`$context.status -cne 'passed'\",\"`$context.status -cne 'diagnostic_passed_not_release_qualified'\")")
line = "$materializer=[IO.File]::ReadAllText($old.materializer).Replace($old.windows_root,$root).Replace((ReadMap $old.plan).tools,$g.windows_tools)"
assert line in text
text = text.replace(line, line + '.Replace("`$context.status -ceq \'passed\'","`$context.status -ceq \'diagnostic_passed_not_release_qualified\'")')
# These proof flags stay explicitly false despite successful backend evidence.
line = "$c=$old"
assert text.count(line) == 1
text = text.replace(line, "$c=$old\n$c.source_final=$false;$c.application_qualified=$false;$c.release_qualified=$false;$c.qualified=$false;$c.diagnostic_only=$true;$c.error_inventory_only=$true;$c.guard_qualifies_current_source=$false;$c.status='prepared_pending_actual_backend_admission'")
out = w / 'evidence/stage-standalone-native-failure-1605-20261109.ps1'
assert not out.exists()
out.write_text(text, encoding='utf-8')
proof = w / 'evidence/080-standalone1605-stager-derivation-20261109.json'
proof.write_text(json.dumps({'scope':'mechanical_standalone_attestation_stager_derivation',
    'baseline':str(oldp),'baseline_sha256':sha(oldp),'derived':str(out),'derived_sha256':sha(out),
    'replacements':replacements,'same_canonical_attestor_and_observer_functions':True,
    'new_source_completion_status_explicit':True,'expected_actual_cases':1605,'backend_actual_session':74540,
    'Linux_started':False,'stage_executed':False,'application_qualified':False},indent=2),encoding='utf-8')
print(json.dumps({'stager':str(out),'sha256':sha(out),'derivation_sha256':sha(proof)}))
