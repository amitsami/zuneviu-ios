"""Generate a dependency-free iOS Xcode project. Safe to rerun after adding Swift files."""
from pathlib import Path
import hashlib, json, plistlib
from xml.sax.saxutils import escape
ROOT = Path(__file__).resolve().parents[1]
objects = {}
def ident(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def add(key, isa, **values):
    uid=ident(key); objects[uid]={'isa':isa, **values}; return uid
def encode(v, depth=0):
    if isinstance(v, dict): return '{\n'+''.join('\t'*(depth+1)+json.dumps(str(k))+' = '+encode(val,depth+1)+';\n' for k,val in v.items())+'\t'*depth+'}'
    if isinstance(v, list): return '(\n'+''.join('\t'*(depth+1)+encode(x,depth+1)+',\n' for x in v)+'\t'*depth+')'
    return json.dumps(str(v))
projectID=ident('project'); appID=ident('app-target')
appFiles=[]; unitFiles=[]; uiFiles=[]
for folder,out in [('Zuneviu',appFiles),('Tests',unitFiles),('UITests',uiFiles)]:
    for file in sorted((ROOT/folder).glob('*.swift')):
        out.append(add(str(file.relative_to(ROOT)),'PBXFileReference',lastKnownFileType='sourcecode.swift',path=file.name,sourceTree='<group>'))
resources=[]
for name,typ in [('Assets.xcassets','folder.assetcatalog'),('LICENSE.txt','text'),('UPSTREAM-NOTICE.md','net.daringfireball.markdown'),('ASSET-CREDITS.md','net.daringfireball.markdown'),('TestTone.wav','audio.wav'),('PrivacyInfo.xcprivacy','text.xml')]:
    resources.append(add('resource-'+name,'PBXFileReference',lastKnownFileType=typ,path=name,sourceTree='<group>'))
info=add('info','PBXFileReference',lastKnownFileType='text.plist.xml',path='Info.plist',sourceTree='<group>')
appGroup=add('app-group','PBXGroup',children=appFiles+resources+[info],path='Zuneviu',sourceTree='<group>')
unitGroup=add('unit-group','PBXGroup',children=unitFiles,path='Tests',sourceTree='<group>')
uiGroup=add('ui-group','PBXGroup',children=uiFiles,path='UITests',sourceTree='<group>')
products=[]; target_ids=[]
projectSettings={'ALWAYS_SEARCH_USER_PATHS':'NO','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SWIFT_VERSION':'5.0','SWIFT_STRICT_CONCURRENCY':'targeted','ENABLE_USER_SCRIPT_SANDBOXING':'YES','GCC_C_LANGUAGE_STANDARD':'gnu17'}
def configs(key, base):
    configurations=[]
    for mode in ['Debug','Release']:
        settings=base.copy()
        if mode=='Debug': settings.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG $(inherited)','ENABLE_TESTABILITY':'YES','DEBUG_INFORMATION_FORMAT':'dwarf','ONLY_ACTIVE_ARCH':'YES'})
        else: settings.update({'SWIFT_OPTIMIZATION_LEVEL':'-O','SWIFT_COMPILATION_MODE':'wholemodule','DEBUG_INFORMATION_FORMAT':'dwarf-with-dsym','VALIDATE_PRODUCT':'YES'})
        configurations.append(add(key+'-'+mode,'XCBuildConfiguration',buildSettings=settings,name=mode))
    return add(key+'-config','XCConfigurationList',buildConfigurations=configurations,defaultConfigurationIsVisible='0',defaultConfigurationName='Release')
projectConfigs=configs('project',projectSettings)
for key,name,files,kind in [('app','Zuneviu',appFiles,'application'),('unit','ZuneviuTests',unitFiles,'bundle.unit-test'),('ui','ZuneviuUITests',uiFiles,'bundle.ui-testing')]:
    product=add(key+'-product','PBXFileReference',explicitFileType='wrapper.application' if key=='app' else 'wrapper.cfbundle',includeInIndex='0',path=name+('.app' if key=='app' else '.xctest'),sourceTree='BUILT_PRODUCTS_DIR'); products.append(product)
    sourceBuilds=[add(key+'-build-'+file,'PBXBuildFile',fileRef=file) for file in files]
    sourcePhase=add(key+'-sources','PBXSourcesBuildPhase',buildActionMask='2147483647',files=sourceBuilds,runOnlyForDeploymentPostprocessing='0')
    frameworkPhase=add(key+'-frameworks','PBXFrameworksBuildPhase',buildActionMask='2147483647',files=[],runOnlyForDeploymentPostprocessing='0')
    resourceBuilds=[add(key+'-res-'+file,'PBXBuildFile',fileRef=file) for file in resources] if key=='app' else []
    resourcePhase=add(key+'-resources','PBXResourcesBuildPhase',buildActionMask='2147483647',files=resourceBuilds,runOnlyForDeploymentPostprocessing='0')
    settings={'PRODUCT_BUNDLE_IDENTIFIER':'com.zuneviu.ios'+('' if key=='app' else '.'+key+'tests'),'PRODUCT_NAME':'$(TARGET_NAME)','TARGETED_DEVICE_FAMILY':'1','CODE_SIGN_STYLE':'Automatic','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'0.1.0','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SUPPORTS_MACCATALYST':'NO','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @loader_path/Frameworks'}
    dependencies=[]
    if key=='app': settings.update({'INFOPLIST_FILE':'Zuneviu/Info.plist','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME':'AccentColor'})
    else:
        settings['GENERATE_INFOPLIST_FILE']='YES'
        proxy=add(key+'-proxy','PBXContainerItemProxy',containerPortal=projectID,proxyType='1',remoteGlobalIDString=appID,remoteInfo='Zuneviu')
        dependencies=[add(key+'-dependency','PBXTargetDependency',target=appID,targetProxy=proxy)]
        if key=='unit': settings.update({'TEST_HOST':'$(BUILT_PRODUCTS_DIR)/Zuneviu.app/Zuneviu','BUNDLE_LOADER':'$(TEST_HOST)'})
        else: settings['TEST_TARGET_NAME']='Zuneviu'
    target=add(key+'-target','PBXNativeTarget',buildConfigurationList=configs(key,settings),buildPhases=[sourcePhase,frameworkPhase,resourcePhase],buildRules=[],dependencies=dependencies,name=name,productName=name,productReference=product,productType='com.apple.product-type.'+kind)
    target_ids.append(target)
productsGroup=add('products','PBXGroup',children=products,name='Products',sourceTree='<group>')
mainGroup=add('main','PBXGroup',children=[appGroup,unitGroup,uiGroup,productsGroup],sourceTree='<group>')
add('project','PBXProject',attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'1600','TargetAttributes':{t:{'CreatedOnToolsVersion':'16.0'} for t in target_ids}},buildConfigurationList=projectConfigs,compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings='0',knownRegions=['en','Base'],mainGroup=mainGroup,productRefGroup=productsGroup,projectDirPath='',projectRoot='',targets=target_ids)
proj=ROOT/'Zuneviu.xcodeproj';proj.mkdir(exist_ok=True)
(proj/'project.pbxproj').write_text('// !$*UTF8*$!\n'+encode({'archiveVersion':'1','classes':{},'objectVersion':'56','objects':objects,'rootObject':projectID})+'\n')
scheme='''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>{buildEntries}</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>{testEntries}</Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{appRef}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{appRef}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
def ref(t,n,ext): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{t}" BuildableName="{n}.{ext}" BlueprintName="{n}" ReferencedContainer="container:Zuneviu.xcodeproj"/>'
refs=[ref(t,n,e) for t,n,e in zip(target_ids,['Zuneviu','ZuneviuTests','ZuneviuUITests'],['app','xctest','xctest'])]
build=''.join(f'<BuildActionEntry buildForTesting="YES" buildForRunning="{"YES" if i==0 else "NO"}" buildForProfiling="{"YES" if i==0 else "NO"}" buildForArchiving="{"YES" if i==0 else "NO"}" buildForAnalyzing="YES">{r}</BuildActionEntry>' for i,r in enumerate(refs))
tests=''.join(f'<TestableReference skipped="NO">{r}</TestableReference>' for r in refs[1:])
(proj/'xcshareddata/xcschemes').mkdir(parents=True,exist_ok=True)
(proj/'xcshareddata/xcschemes/Zuneviu.xcscheme').write_text(scheme.format(buildEntries=build,testEntries=tests,appRef=refs[0]))
info={'CFBundleDisplayName':'Zunéviu','CFBundleName':'$(PRODUCT_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundlePackageType':'APPL','CFBundleShortVersionString':'$(MARKETING_VERSION)','CFBundleVersion':'$(CURRENT_PROJECT_VERSION)','LSRequiresIPhoneOS':True,'UILaunchScreen':{},'UIBackgroundModes':['audio'],'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait'],'LSSupportsOpeningDocumentsInPlace':True,'UTImportedTypeDeclarations':[{'UTTypeIdentifier':'com.zuneviu.lrc','UTTypeDescription':'LRC Lyrics','UTTypeConformsTo':['public.plain-text'],'UTTypeTagSpecification':{'public.filename-extension':['lrc']}}]}
(ROOT/'Zuneviu/Info.plist').write_bytes(plistlib.dumps(info))
privacy={'NSPrivacyTracking':False,'NSPrivacyTrackingDomains':[],'NSPrivacyCollectedDataTypes':[],'NSPrivacyAccessedAPITypes':[{'NSPrivacyAccessedAPIType':'NSPrivacyAccessedAPICategoryUserDefaults','NSPrivacyAccessedAPITypeReasons':['CA92.1']}]}
(ROOT/'Zuneviu/PrivacyInfo.xcprivacy').write_bytes(plistlib.dumps(privacy))
print(f'Generated 3 targets; {len(appFiles)} application Swift files; {len(unitFiles)+len(uiFiles)} test files.')
