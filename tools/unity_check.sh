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
cat > Check.csproj <<EOF
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>netstandard2.1</TargetFramework><LangVersion>9.0</LangVersion>
    <NoWarn>CS0618;CS0649;CS0169;CS0414;CS1701;CS1702</NoWarn>
    <EnableDefaultCompileItems>false</EnableDefaultCompileItems><GenerateAssemblyInfo>false</GenerateAssemblyInfo>
  </PropertyGroup>
  <ItemGroup>
    <Reference Include="$WORK/um/lib/net35/UnityEngine*.dll" />
    <Compile Include="$ROOT/unity/AltopiaRoute/Assets/Scripts/**/*.cs" />
  </ItemGroup>
</Project>
EOF
dotnet build -nologo -v q 2>&1 | tee build.log | grep -E "error|Build succeeded" | sort -u
grep -q "Build succeeded" build.log && echo "Compilation OK" || { echo "Compilation ÉCHOUÉE"; exit 1; }
