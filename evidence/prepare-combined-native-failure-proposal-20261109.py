import ast,hashlib,json
from pathlib import Path
root=Path("evidence/native-failure-combined-proposal-v2-20261109");assert not root.exists();root.mkdir()
ux=Path("evidence/native-failure-ux-proposal-20261109");term=Path("evidence/native-worker-term-proposal-20261109")
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda p:p.read_text(encoding="utf-8")
assert sha((ux/"proposal.patch").read_bytes())=="b2344d7511cec32a38967c705ef01bcc83d71babe8e25e2868ed4c170483bbab"
assert sha((term/"proposal.patch").read_bytes())=="61927180e1743f44b40dfbc86323d641f68539792c34f18b0be6970f198f8d50"
u=json.loads(read(ux/"static-review.json"))
for rel,v in u["files"].items():
 source=ux/rel;assert sha(source.read_bytes())==v["proposal_sha256"]
 target=root/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(source.read_bytes())
rel="src/devbrain/native_worker.py";t=json.loads(read(term/"static-proof.json"))
assert sha((term/rel).read_bytes())==t["files"][rel]["proposal_sha256"]
target=root/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((term/rel).read_bytes())
name="test_native_worker_rebinds_actual_inner_tmux_identity";rel="tests/test_terminal_bridge.py"
original=read(Path("devbrain")/rel);proposed=read(root/rel);replacement=read(term/rel)
def function(text):
 n=next(n for n in ast.parse(text).body if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef)) and n.name==name)
 return n,min([n.lineno]+[d.lineno for d in n.decorator_list])-1,n.end_lineno
old,_,_=function(original);current,start,end=function(proposed);new,ns,ne=function(replacement)
assert ast.dump(old,include_attributes=False)==ast.dump(current,include_attributes=False)
lines=proposed.splitlines(keepends=True)
merged="".join(lines[:start]+replacement.splitlines(keepends=True)[ns:ne]+lines[end:])
(root/rel).write_text(merged,encoding="utf-8",newline="\n")
functions=lambda text:{n.name:ast.dump(n,include_attributes=False) for n in ast.parse(text).body if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef))}
cf,uf=functions(merged),functions(proposed)
assert cf.keys()==uf.keys() and [k for k in uf if cf[k]!=uf[k]]==[name]
assert cf[name]==ast.dump(new,include_attributes=False)
files={}
for rel in sorted(list(u["files"])+["src/devbrain/native_worker.py"]):
 source=Path("devbrain")/rel;proposed=root/rel;ast.parse(read(proposed))
 files["devbrain/"+rel]={"baseline_sha256":sha(source.read_bytes()),"proposal_sha256":sha(proposed.read_bytes()),"proposal_path":str(proposed.resolve())}
manifest={"schema_version":1,"scope":"combined_native_failure_diagnostic_proposal_only","source_freeze_sha256":"ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703","UX_patch_sha256":"b2344d7511cec32a38967c705ef01bcc83d71babe8e25e2868ed4c170483bbab","TERM_patch_sha256":"61927180e1743f44b40dfbc86323d641f68539792c34f18b0be6970f198f8d50","unique_changed_files":8,"logical_patch_components":9,"disjoint_test_function":name,"all_other_UX_test_function_AST_unchanged":True,"all_UX_test_function_names_preserved":True,"AST_proposed_files":8,"source_changed":False,"Linux_or_models_or_auth_started":False,"release_qualified":False,"files":files}
out=Path("evidence/080-native-failure-combined-proposal-20261109.json");assert not out.exists()
out.write_text(json.dumps(manifest,indent=2),encoding="utf-8",newline="\n")
print(json.dumps({"manifest":str(out),"sha256":sha(out.read_bytes()),"unique_files":8,"logical_components":9,"all_other_UX_test_functions_AST_unchanged":True,"old_partial_attempt_preserved":True}))

