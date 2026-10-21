#!/usr/bin/env bash
# Vérifie que les scripts du prototype Unity compilent, sans éditeur Unity : compilation avec .NET contre les vraies DLL UnityEngine (NuGet UnityEngine.Modules).
# Ne couvre pas : le code Editor, les tests NUnit, les shaders, le rendu. Usage : tools/unity_check.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${TMPDIR:-/tmp}/altopia_unity_check"
mkdir -p "$WORK"; cd "$WORK"
if ! command -v dotnet >/dev/null 2>&1; then
  [ -x "$WORK/dotnet/dotnet" ] || { curl -sSL https://dot.net/v1/dotnet-install.sh -o di.sh && bash di.sh --channel 8.0 --install-dir "$WORK/dotnet" >/dev/null; }
  export PATH="$WORK/dotnet:$PATH"
fi
if [ ! -d um ]; then
  curl -sSL -o um.nupkg https://api.nuget.org/v3-flatcontainer/unityengine.modules/2021.3.33/unityengine.modules.2021.3.33.nupkg
  unzip -q -o um.nupkg -d um
fi
REFS=""
for f in "$WORK"/um/lib/net35/UnityEngine*.dll; do REFS="$REFS<Reference Include=\"$f\" />"; done
cat > Check.csproj <<EOF
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>netstandard2.1</TargetFramework><LangVersion>9.0</LangVersion>
    <NoWarn>CS0618;CS0649;CS0169;CS0414;CS1701;CS1702</NoWarn>
    <EnableDefaultCompileItems>false</EnableDefaultCompileItems><GenerateAssemblyInfo>false</GenerateAssemblyInfo>
  </PropertyGroup>
  <ItemGroup>
    $REFS
    <Compile Include="$ROOT/unity/AltopiaRoute/Assets/Scripts/**/*.cs" />
  </ItemGroup>
</Project>
EOF
dotnet build -nologo -v q 2>&1 | tee build.log | grep -E "error|Build succeeded" | sort -u
grep -q "Build succeeded" build.log && echo "Scripts du jeu : compilation OK" || { echo "Compilation ÉCHOUÉE"; exit 1; }

# Code Editor (fenêtre de test, build) : compilé contre UnityEditor 2020.2, la seule version publiée sur NuGet.
# Les API plus récentes (NamedBuildTarget, 2021.2+) n'existent pas dedans : ces erreurs-là sont attendues et ignorées.
if [ ! -d ue ]; then
  curl -sSL -o ue.nupkg https://api.nuget.org/v3-flatcontainer/unitytechnologies.unityeditor/2020.2.2.1/unitytechnologies.unityeditor.2020.2.2.1.nupkg
  unzip -q -o ue.nupkg -d ue
fi
mkdir -p ed
sed -e "s#</ItemGroup>#<Compile Include=\"$ROOT/unity/AltopiaRoute/Assets/Editor/**/*.cs\" /><Reference Include=\"$WORK/ue/lib/UnityEditor.dll\" /></ItemGroup>#" Check.csproj > ed/CheckEd.csproj
(cd ed && dotnet build -nologo -v q 2>&1 | grep -E "error" | grep -v "NamedBuildTarget" | sort -u > ../ed.log || true)
if [ -s ed.log ]; then cat ed.log; echo "Code Editor : compilation ÉCHOUÉE"; exit 1; else echo "Code Editor : compilation OK (hors API récentes)"; fi
