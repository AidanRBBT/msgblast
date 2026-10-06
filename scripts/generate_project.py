#!/usr/bin/env python3
"""Create the dependency-free Xcode project from the committed Swift sources."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parents[1]
objects = {}
def ident(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def obj(name, body):
    key = ident(name); objects[key] = body; return key
def seq(values): return '(' + ', '.join(values) + (',)' if values else ')')
def configs(name, settings):
    ids = []
    for mode in ['Debug', 'Release']:
        s = dict(settings)
        s.update({'SWIFT_OPTIMIZATION_LEVEL': '"-Onone"' if mode == 'Debug' else '"-O"', 'SWIFT_ACTIVE_COMPILATION_CONDITIONS': '"DEBUG"' if mode == 'Debug' else '""'})
        ids.append(obj(name+mode, '{isa = XCBuildConfiguration; name = '+mode+'; buildSettings = {' + ''.join(f'{k} = {v};' for k,v in s.items()) + '};}'))
    return obj(name+'configs', '{isa = XCConfigurationList; buildConfigurations = '+seq(ids)+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;}')
files = {}
for p in sorted(list(root.glob('MsgBlast/**/*.swift')) + list(root.glob('MsgBlastTests/*.swift')) + list(root.glob('MsgBlastUITests/*.swift'))):
    rel = str(p.relative_to(root)); files[rel] = obj(rel, '{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "'+rel+'"; sourceTree = SOURCE_ROOT;}')
icon = obj('MsgBlast/AppIcon.icon', '{isa = PBXFileReference; lastKnownFileType = folder.iconcomposer.icon; path = "MsgBlast/AppIcon.icon"; sourceTree = SOURCE_ROOT;}')
demo_icon = obj('MsgBlast/AppIconDemo.icon', '{isa = PBXFileReference; lastKnownFileType = folder.iconcomposer.icon; path = "MsgBlast/AppIconDemo.icon"; sourceTree = SOURCE_ROOT;}')
notice = obj('MsgBlast/ThirdPartyNotices.txt', '{isa = PBXFileReference; lastKnownFileType = text; path = "MsgBlast/ThirdPartyNotices.txt"; sourceTree = SOURCE_ROOT;}')
discover = obj('MsgBlast/Resources/Discover', '{isa = PBXFileReference; lastKnownFileType = folder; path = "MsgBlast/Resources/Discover"; sourceTree = SOURCE_ROOT;}')
muse_avatar = obj('MsgBlast/Resources/MuseAvatar.jpg', '{isa = PBXFileReference; lastKnownFileType = image.jpeg; path = "MsgBlast/Resources/MuseAvatar.jpg"; sourceTree = SOURCE_ROOT;}')
web_agent_icons = obj('MsgBlast/Resources/WebAgentIcons', '{isa = PBXFileReference; lastKnownFileType = folder; path = "MsgBlast/Resources/WebAgentIcons"; sourceTree = SOURCE_ROOT;}')
products = {}
for name, kind, ext in [('MsgBlastCore','wrapper.framework','.framework'),('MsgBlast','wrapper.application','.app'),('MsgBlastTests','wrapper.cfbundle','.xctest'),('MsgBlastUITests','wrapper.cfbundle','.xctest')]:
    products[name] = obj(name+'product', '{isa = PBXFileReference; explicitFileType = '+kind+'; path = '+name+ext+'; sourceTree = BUILT_PRODUCTS_DIR;}')
product_group = obj('products', '{isa = PBXGroup; name = Products; sourceTree = "<group>"; children = '+seq(list(products.values()))+';}')
main_group = obj('mainGroup', '{isa = PBXGroup; sourceTree = "<group>"; children = '+seq(list(files.values())+[icon, demo_icon, notice, discover, muse_avatar, web_agent_icons, product_group])+';}')
targets = {}
for name in products:
    own = [p for p in files if (p.startswith('MsgBlast/Core/') if name == 'MsgBlastCore' else p.startswith('MsgBlastTests/') if name == 'MsgBlastTests' else p.startswith('MsgBlastUITests/') if name == 'MsgBlastUITests' else p.startswith('MsgBlast/') and not p.startswith('MsgBlast/Core/'))]
    if name == 'MsgBlastTests': own.append('MsgBlast/Permissions/MessagesAccessGuide.swift')
    builds = [obj(name+p+'build', '{isa = PBXBuildFile; fileRef = '+files[p]+';}') for p in own]
    sources = obj(name+'sources', '{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = '+seq(builds)+'; runOnlyForDeploymentPostprocessing = 0;}')
    framework_builds = []
    dependencies = []
    if name not in ('MsgBlastCore','MsgBlastUITests'):
        framework_builds.append(obj(name+'linkCore', '{isa = PBXBuildFile; fileRef = '+products['MsgBlastCore']+';}'))
        dependencies.append(obj(name+'dep', '{isa = PBXTargetDependency; target = '+ident('MsgBlastCoretarget')+';}'))
    framework_phase = obj(name+'frameworks', '{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = '+seq(framework_builds)+'; runOnlyForDeploymentPostprocessing = 0;}')
    phases = [sources, framework_phase]
    settings = {'PRODUCT_NAME': '"$(TARGET_NAME)"', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.msgblast.'+name, 'MACOSX_DEPLOYMENT_TARGET': '26.0', 'SWIFT_VERSION': '6.0', 'CODE_SIGN_STYLE': 'Automatic', 'CODE_SIGN_IDENTITY': '"-"', 'ENABLE_HARDENED_RUNTIME': 'YES' if name == 'MsgBlast' else 'NO', 'ENABLE_TESTABILITY': 'YES', 'GENERATE_INFOPLIST_FILE': 'YES', 'LD_RUNPATH_SEARCH_PATHS': '"$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks"'}
    if name == 'MsgBlastUITests':
        settings['TEST_TARGET_NAME'] = 'MsgBlast'
        dependencies.append(obj(name+'dep', '{isa = PBXTargetDependency; target = '+ident('MsgBlasttarget')+';}'))
    if name == 'MsgBlastCore':
        settings.update({'DEFINES_MODULE':'YES', 'DYLIB_INSTALL_NAME_BASE':'"@rpath"', 'SKIP_INSTALL':'YES', 'OTHER_LDFLAGS':'"$(inherited) -lsqlite3"'})
    if name == 'MsgBlast':
        settings.update({'GENERATE_INFOPLIST_FILE':'NO', 'INFOPLIST_FILE':'MsgBlast/Info.plist', 'CODE_SIGN_ENTITLEMENTS':'MsgBlast/MsgBlast.entitlements', 'PRODUCT_BUNDLE_IDENTIFIER':'com.msgblast.mac', 'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon'})
        icon_build = obj('appIconBuild', '{isa = PBXBuildFile; fileRef = '+icon+';}')
        demo_icon_build = obj('demoAppIconBuild', '{isa = PBXBuildFile; fileRef = '+demo_icon+';}')
        notice_build = obj('thirdPartyNoticeBuild', '{isa = PBXBuildFile; fileRef = '+notice+';}')
        discover_build = obj('discoverResourcesBuild', '{isa = PBXBuildFile; fileRef = '+discover+';}')
        muse_avatar_build = obj('museAvatarBuild', '{isa = PBXBuildFile; fileRef = '+muse_avatar+';}')
        web_agent_icons_build = obj('webAgentIconsBuild', '{isa = PBXBuildFile; fileRef = '+web_agent_icons+';}')
        phases.append(obj('appResources', '{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = '+seq([icon_build, demo_icon_build, notice_build, discover_build, muse_avatar_build, web_agent_icons_build])+'; runOnlyForDeploymentPostprocessing = 0;}'))
        embed = obj('embedCoreBuild','{isa = PBXBuildFile; fileRef = '+products['MsgBlastCore']+'; settings = {ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy,);};}')
        phases.append(obj('embedCore','{isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = ""; dstSubfolderSpec = 10; files = '+seq([embed])+'; name = "Embed Frameworks"; runOnlyForDeploymentPostprocessing = 0;}'))
    config = configs(name, settings)
    type_ = 'framework' if name == 'MsgBlastCore' else 'application' if name == 'MsgBlast' else 'bundle.ui-testing' if name == 'MsgBlastUITests' else 'bundle.unit-test'
    targets[name] = obj(name+'target', '{isa = PBXNativeTarget; name = '+name+'; productName = '+name+'; productReference = '+products[name]+'; productType = "com.apple.product-type.'+type_+'"; buildConfigurationList = '+config+'; buildPhases = '+seq(phases)+'; buildRules = (); dependencies = '+seq(dependencies)+';}')
project_config = configs('project', {'SDKROOT':'macosx', 'CLANG_ENABLE_MODULES':'YES', 'SWIFT_VERSION':'6.0', 'MACOSX_DEPLOYMENT_TARGET':'26.0'})
project = obj('project', '{isa = PBXProject; attributes = {LastUpgradeCheck = 2700;}; buildConfigurationList = '+project_config+'; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base,); mainGroup = '+main_group+'; productRefGroup = '+product_group+'; projectDirPath = ""; projectRoot = ""; targets = '+seq(list(targets.values()))+';}')
dest = root / 'MsgBlast.xcodeproj'; dest.mkdir(exist_ok=True)
(dest/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+ '\n'.join(f'{k} = {v};' for k,v in objects.items())+'\n}; rootObject = '+project+';}\n')
schemes = dest/'xcshareddata/xcschemes'; schemes.mkdir(parents=True, exist_ok=True)
def ref(name, suffix): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{targets[name]}" BuildableName="{name}{suffix}" BlueprintName="{name}" ReferencedContainer="container:MsgBlast.xcodeproj"/>'
(schemes/'MsgBlast.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref('MsgBlast','.app')}</BuildActionEntry><BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{ref('MsgBlastTests','.xctest')}</BuildActionEntry><BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{ref('MsgBlastUITests','.xctest')}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{ref('MsgBlastTests','.xctest')}</TestableReference><TestableReference skipped="NO">{ref('MsgBlastUITests','.xctest')}</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref('MsgBlast','.app')}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref('MsgBlast','.app')}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print(dest)
