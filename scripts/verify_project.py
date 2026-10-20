#!/usr/bin/env python3
"""Static checks only. This does NOT compile Swift or execute iOS tests."""
from pathlib import Path
import json, plistlib, re, hashlib, wave, xml.etree.ElementTree as ET
from datetime import datetime, timezone
import openstep_plist
import tree_sitter, tree_sitter_swift
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
checks=[]
def check(label, condition, detail=''):
    checks.append({'check':label,'passed':bool(condition),'detail':detail})
parser=tree_sitter.Parser(tree_sitter.Language(tree_sitter_swift.language()))
swiftFiles=list(ROOT.rglob('*.swift'))
for path in swiftFiles:
    tree=parser.parse(path.read_bytes())
    check('Swift syntax: '+str(path.relative_to(ROOT)),not tree.root_node.has_error,'Tree-sitter parse only; no Apple SDK type checking')
p= openstep_plist.loads((ROOT/'Zuneviu.xcodeproj/project.pbxproj').read_text())
obj=p['objects']
check('OpenStep Xcode project parses', p['rootObject'] in obj)
refs=['buildConfigurationList','productReference','mainGroup','productRefGroup','containerPortal','remoteGlobalIDString','target','targetProxy','fileRef']
arrays=['children','buildPhases','dependencies','targets','files','buildConfigurations']
for uid,value in obj.items():
    for name in refs:
        if name in value: check('Reference '+uid+'.'+name,value[name] in obj)
    for name in arrays:
        for target in value.get(name,[]): check('Reference '+uid+'.'+name,target in obj)
check('Three Xcode targets',len([v for v in obj.values() if v['isa']=='PBXNativeTarget'])==3)
for folder in ['Zuneviu','Tests','UITests']:
    group=next(v for v in obj.values() if v.get('isa')=='PBXGroup' and v.get('path')==folder)
    for child in group['children']:
        ref=obj[child];check('File exists: '+folder+'/'+ref['path'],(ROOT/folder/ref['path']).exists())
info=plistlib.loads((ROOT/'Zuneviu/Info.plist').read_bytes())
privacy=plistlib.loads((ROOT/'Zuneviu/PrivacyInfo.xcprivacy').read_bytes())
check('Background audio declared','audio' in info['UIBackgroundModes'])
check('No App Transport Security bypass','NSAppTransportSecurity' not in info)
check('No tracking declared',privacy['NSPrivacyTracking'] is False)
check('UserDefaults required-reason declaration',privacy['NSPrivacyAccessedAPITypes'][0]['NSPrivacyAccessedAPITypeReasons']==['CA92.1'])
for contents in (ROOT/'Zuneviu/Assets.xcassets').rglob('Contents.json'):
    values=json.loads(contents.read_text())
    for image in values.get('images',[]):
        if 'filename' in image: check('Asset file exists: '+image['filename'],(contents.parent/image['filename']).is_file())
icon=Image.open(ROOT/'Zuneviu/Assets.xcassets/AppIcon.appiconset/AppIcon.png')
check('Opaque 1024 app icon',icon.size==(1024,1024) and icon.mode=='RGB')
ET.parse(ROOT/'Zuneviu.xcodeproj/xcshareddata/xcschemes/Zuneviu.xcscheme')
check('Shared scheme XML parses',True)
with wave.open(str(ROOT/'Zuneviu/TestTone.wav')) as f:
    check('8-second audio fixture',f.getnframes()/f.getframerate()==8 and f.getnchannels()==1)
methods=[]
for path in (ROOT/'Tests').glob('*.swift'): methods+=re.findall(r'func (test\w+)\(',path.read_text())
ui=[]
for path in (ROOT/'UITests').glob('*.swift'): ui+=re.findall(r'func (test\w+)\(',path.read_text())
report={'generatedAt':datetime.now(timezone.utc).isoformat(),'scope':'STATIC_ONLY','summary':{'checks':len(checks),'passed':sum(c['passed'] for c in checks),'failed':sum(not c['passed'] for c in checks),'swiftFiles':len(swiftFiles),'unitTestsWritten':len(methods),'uiTestsWritten':len(ui)},'notExecutedByThisScript':['Apple SDK compilation','XCTest unit tests','XCUITest UI tests','iOS Simulator execution','Physical iPhone testing','GitHub Actions workflow'],'checks':checks,'sourceSHA256':{str(x.relative_to(ROOT)):hashlib.sha256(x.read_bytes()).hexdigest() for x in swiftFiles}}
(ROOT/'STATIC_VALIDATION.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report['summary'],indent=2))
for c in checks:
    if not c['passed']: print('FAILED:',c['check'])
print('NOT an iOS build/test pass. Apple compilation and runtime tests are not executed by this script; see BUILD_STATUS.md for remote results.')
raise SystemExit(1 if any(not c['passed'] for c in checks) else 0)
