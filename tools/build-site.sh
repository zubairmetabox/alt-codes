#!/usr/bin/env bash
# Builds the static download site into site/ :
#   site/Install-AltCodes.cmd   double-click installer (batch wrapper + embedded PowerShell)
#   site/Uninstall-AltCodes.cmd double-click uninstaller
#   site/AltCodes-Installer.zip both .cmd files, for browsers that block .cmd downloads
#   site/Install-AltCodes.ps1   the raw script
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/site"
ps1="$root/Install-AltCodes.ps1"

make_cmd() { # $1 = output file, $2 = 1 for uninstall
  {
    printf '@echo off\r\n'
    printf 'rem Alt Codes installer - https://github.com/zubairmetabox/alt-codes\r\n'
    printf 'rem This file is a small launcher followed by the PowerShell installer script.\r\n'
    printf 'setlocal\r\n'
    printf 'title Alt Codes\r\n'
    printf 'set "ALTCODES_SELF=%%~f0"\r\n'
    printf 'set "ALTCODES_UNINSTALL=%s"\r\n' "$2"
    printf 'powershell -NoProfile -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText($env:ALTCODES_SELF,[Text.Encoding]::UTF8); $i=$t.LastIndexOf([char]35+[char]35+%s); & ([scriptblock]::Create($t.Substring($i))) -Uninstall:($env:ALTCODES_UNINSTALL -eq %s)"\r\n' "'PS1'" "'1'"
    printf 'echo.\r\n'
    printf 'pause\r\n'
    printf 'exit /b\r\n'
    printf '##PS1\r\n'
    cat "$ps1"
  } > "$1"
}

make_cmd "$out/Install-AltCodes.cmd" 0
make_cmd "$out/Uninstall-AltCodes.cmd" 1
cp "$ps1" "$out/Install-AltCodes.ps1"
cp "$root/docs/icon.png" "$out/icon.png"
rm -f "$out/AltCodes-Installer.zip"
python3 -I -c 'import sys,zipfile,os
z=zipfile.ZipFile(sys.argv[1],"w",zipfile.ZIP_DEFLATED)
for f in sys.argv[2:]: z.write(f, os.path.basename(f))' "$out/AltCodes-Installer.zip" "$out/Install-AltCodes.cmd" "$out/Uninstall-AltCodes.cmd"
ls -la "$out"
