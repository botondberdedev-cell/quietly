#!/usr/bin/env python3
"""Generate the checked-in Xcode project using only Python's standard library."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
release = json.loads((ROOT / "release.json").read_text())
objects = {}


def uid(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()


def add(name, body):
    key = uid(name)
    objects[key] = body
    return key


def quoted(value):
    return json.dumps(value)


def array(items):
    return "(" + ", ".join(items) + ("," if items else "") + ")"


source_paths = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "Quietly").rglob("*.swift"))
resources = ["Quietly/Resources/filters.js", "Quietly/Resources/single-post.js", "Quietly/Resources/message-alerts.js", "Quietly/Resources/LICENSE.txt", "Quietly/PrivacyInfo.xcprivacy", "Quietly/Assets.xcassets"]
file_refs, source_builds, resource_builds = [], [], []
(ROOT / "Quietly/Resources/LICENSE.txt").write_text((ROOT / "LICENSE").read_text())

for path in source_paths + resources + ["Quietly/Info.plist"]:
    kind = ("sourcecode.swift" if path.endswith(".swift") else
            "folder.assetcatalog" if path.endswith(".xcassets") else
            "text.plist.xml" if path.endswith((".plist", ".xcprivacy")) else
            "sourcecode.javascript" if path.endswith(".js") else "text")
    ref = add(path, f'isa = PBXFileReference; lastKnownFileType = {kind}; path = {quoted(path)}; sourceTree = SOURCE_ROOT;')
    file_refs.append(ref)
    if path in source_paths or path in resources:
        build = add("build:" + path, f"isa = PBXBuildFile; fileRef = {ref};")
        (source_builds if path in source_paths else resource_builds).append(build)

product = add("product", 'isa = PBXFileReference; explicitFileType = wrapper.application; path = Quietly.app; sourceTree = BUILT_PRODUCTS_DIR;')
products = add("products", f'isa = PBXGroup; children = {array([product])}; name = Products; sourceTree = "<group>";')
main = add("main", f'isa = PBXGroup; children = {array(file_refs + [products])}; sourceTree = "<group>";')
sources = add("sources", f"isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {array(source_builds)}; runOnlyForDeploymentPostprocessing = 0;")
res_phase = add("resources", f"isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {array(resource_builds)}; runOnlyForDeploymentPostprocessing = 0;")
frameworks = add("frameworks", "isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;")


def configs(prefix, settings):
    refs = []
    for name in ["Debug", "Release"]:
        cfg = dict(settings)
        cfg["SWIFT_OPTIMIZATION_LEVEL"] = "-Onone" if name == "Debug" else "-O"
        cfg["DEBUG_INFORMATION_FORMAT"] = "dwarf" if name == "Debug" else "dwarf-with-dsym"
        if name == "Debug":
            cfg["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
            cfg["ENABLE_TESTABILITY"] = "YES"
        pairs = " ".join(f"{key} = {quoted(str(value))};" for key, value in sorted(cfg.items()))
        refs.append(add(f"{prefix}:{name}", f"isa = XCBuildConfiguration; buildSettings = {{ {pairs} }}; name = {name};"))
    return add(prefix + ":configs", f"isa = XCConfigurationList; buildConfigurations = {array(refs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")


project_configs = configs("project", {
    "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "SDKROOT": "iphoneos",
    "SWIFT_VERSION": "5.0", "ENABLE_USER_SCRIPT_SANDBOXING": "YES"
})
target_configs = configs("target", {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": release["build"],
    "GENERATE_INFOPLIST_FILE": "NO", "INFOPLIST_FILE": "Quietly/Info.plist",
    "MARKETING_VERSION": release["version"], "PRODUCT_BUNDLE_IDENTIFIER": "org.quietly.focus",
    "PRODUCT_NAME": "$(TARGET_NAME)", "TARGETED_DEVICE_FAMILY": "1,2",
    "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "SUPPORTS_MACCATALYST": "NO",
    "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks"
})
target = add("target", f'isa = PBXNativeTarget; buildConfigurationList = {target_configs}; buildPhases = {array([sources, frameworks, res_phase])}; buildRules = (); dependencies = (); name = Quietly; productName = Quietly; productReference = {product}; productType = "com.apple.product-type.application";')


def test_target(name, folder, ui=False):
    builds = []
    for path in sorted((ROOT / folder).glob("*.swift")):
        relative = path.relative_to(ROOT).as_posix()
        ref = add(relative, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quoted(relative)}; sourceTree = SOURCE_ROOT;')
        file_refs.append(ref)
        builds.append(add("build:" + relative, f"isa = PBXBuildFile; fileRef = {ref};"))
    phase = add(name + ":sources", f"isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {array(builds)}; runOnlyForDeploymentPostprocessing = 0;")
    bundle = add(name + ":product", f"isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = {name}.xctest; sourceTree = BUILT_PRODUCTS_DIR;")
    proxy = add(name + ":proxy", f"isa = PBXContainerItemProxy; containerPortal = {uid('project')}; proxyType = 1; remoteGlobalIDString = {target}; remoteInfo = Quietly;")
    dependency = add(name + ":dependency", f"isa = PBXTargetDependency; target = {target}; targetProxy = {proxy};")
    settings = {
        "CODE_SIGN_STYLE": "Automatic", "GENERATE_INFOPLIST_FILE": "YES",
        "PRODUCT_BUNDLE_IDENTIFIER": "org.quietly.focus." + name,
        "PRODUCT_NAME": "$(TARGET_NAME)", "TARGETED_DEVICE_FAMILY": "1,2",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @loader_path/Frameworks",
    }
    if ui:
        settings["TEST_TARGET_NAME"] = "Quietly"
    else:
        settings["TEST_HOST"] = "$(BUILT_PRODUCTS_DIR)/Quietly.app/Quietly"
        settings["BUNDLE_LOADER"] = "$(TEST_HOST)"
    configuration = configs(name, settings)
    kind = "ui-testing" if ui else "unit-test"
    test_id = add(name, f'isa = PBXNativeTarget; buildConfigurationList = {configuration}; buildPhases = {array([phase])}; buildRules = (); dependencies = {array([dependency])}; name = {name}; productName = {name}; productReference = {bundle}; productType = "com.apple.product-type.bundle.{kind}";')
    return test_id, bundle


native_tests, native_product = test_target("QuietlyTests", "Tests/iOS")
ui_tests, ui_product = test_target("QuietlyUITests", "Tests/UI", ui=True)
objects[products] = f'isa = PBXGroup; children = {array([product, native_product, ui_product])}; name = Products; sourceTree = "<group>";'
objects[main] = f'isa = PBXGroup; children = {array(file_refs + [products])}; sourceTree = "<group>";'
project = add("project", f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; }}; buildConfigurationList = {project_configs}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = {array([target, native_tests, ui_tests])};')
project_dir = ROOT / "Quietly.xcodeproj"
project_dir.mkdir(exist_ok=True)
lines = ["// !$*UTF8*$!", "{", "archiveVersion = 1;", "classes = {};", "objectVersion = 56;", "objects = {"]
lines.extend(f"{key} = {{ {body} }};" for key, body in objects.items())
lines.extend(["};", f"rootObject = {project};", "}"])
(project_dir / "project.pbxproj").write_text("\n".join(lines) + "\n")
scheme_dir = project_dir / "xcshareddata/xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Quietly.app" BlueprintName="Quietly" ReferencedContainer="container:Quietly.xcodeproj"/>'
(scheme_dir / "Quietly.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
    <Testables>
      <TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{native_tests}" BuildableName="QuietlyTests.xctest" BlueprintName="QuietlyTests" ReferencedContainer="container:Quietly.xcodeproj"/></TestableReference>
      <TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ui_tests}" BuildableName="QuietlyUITests.xctest" BlueprintName="QuietlyUITests" ReferencedContainer="container:Quietly.xcodeproj"/></TestableReference>
    </Testables>
  </TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print(f"Generated Quietly.xcodeproj ({len(source_paths)} Swift files)")
