# Builds one plugin of this folder for Skyrim 1.7 with the compiler, CMake, Ninja and vcpkg that ship with Visual Studio
# Usage: build.ps1 equipment-panel
#        build.ps1 equipment-panel build/side     a second build folder, so two people can build the same plugin at once
#        build.ps1 equipment-panel build/debug IR_DEBUG_EDITION=ON     options of the plugin's CMakeLists.txt after it
# The first run builds CommonLibSSE-NG and takes several minutes, the result is <plugin>\build\<Name>.dll
param([Parameter(Mandatory)][string]$Plugin, [string]$Folder = "build", [Parameter(ValueFromRemainingArguments)][string[]]$Define = @())

$visualStudio = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
$cmake = "$visualStudio\Common7\IDE\CommonExtensions\Microsoft\CMake"
$env:VCPKG_ROOT = "$visualStudio\VC\vcpkg"
$env:PATH = "$cmake\CMake\bin;$cmake\Ninja;$env:PATH"
$options = ($Define | ForEach-Object { "-D$_" }) -join " "

$steps = @(
    "call `"$visualStudio\VC\Auxiliary\Build\vcvars64.bat`" >nul",
    "cd /d `"$PSScriptRoot\$Plugin`"",
    "cmake --preset skyrim-17 -B $Folder $options",
    "cmake --build $Folder"
) -join " && "

cmd /c $steps
exit $LASTEXITCODE
