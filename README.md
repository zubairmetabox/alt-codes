<img src="docs/icon.png" width="64" align="right" alt="Alt Codes icon">

# Alt Codes

Use Windows Alt codes on a laptop without a numpad.

Hold **Left Alt**, type the code on the **number row** above the letters, and release Alt. For example, `Alt` + `1` `3` `0` gives **é**, just like on a full keyboard's numpad.

- Tiny tray app: hover shows it's running, right-click to **Exit** or tick **Run on startup**
- Listed in **Task Manager → Startup apps**, where you can enable or disable it
- Shows up in the **Start menu**, so you can open it again anytime
- No downloads besides one script: the installer compiles the app with the C# compiler that is already part of Windows (.NET Framework 4.x)
- No admin rights needed; installs for the current user only

## Install

Open **PowerShell** (no admin needed) and paste:

```powershell
irm https://raw.githubusercontent.com/zubairmetabox/alt-codes/main/Install-AltCodes.ps1 -OutFile "$env:TEMP\Install-AltCodes.ps1"; powershell -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\Install-AltCodes.ps1"
```

Or download [`Install-AltCodes.ps1`](Install-AltCodes.ps1) and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-AltCodes.ps1
```

A blue **Alt** icon appears in the tray. If you don't see it, it's under the **^** arrow; drag it onto the taskbar to keep it visible.

The app is installed to `%LOCALAPPDATA%\Programs\AltCodes`. Running the installer again updates it and keeps your startup choice.

## Uninstall

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-AltCodes.ps1 -Uninstall
```

This removes the app, the Start menu shortcut and the startup entry.

## Some codes

| Code | Char | Code | Char | Code | Char |
|------|------|------|------|------|------|
| 130 | é | 0233 | é | 0128 | € |
| 133 | à | 0224 | à | 0163 | £ |
| 135 | ç | 0231 | ç | 0169 | © |
| 138 | è | 0232 | è | 0176 | ° |
| 0150 | – | 0151 | — | 0177 | ± |

Codes without a leading `0` use the old DOS (OEM) code page; codes with a leading `0` use the Windows (ANSI) code page.

## How it works

The app installs a low-level keyboard hook. While **Left Alt** is held, each top-row digit is swallowed and replaced by the matching numpad key (`VK_NUMPAD0`-`9` with the numpad scan code). Windows then sees exactly what a real numpad produces, and its own Alt-code handling inserts the character.

- **Ctrl + Alt + digit** is left alone, so AltGr shortcuts on layouts like AZERTY still work.
- **Right Alt** is never remapped, if you need Alt + digit shortcuts in an app.
- **Startup:** uses the same registry entries as Task Manager's Startup tab (`HKCU\...\Run` plus `StartupApproved\Run`). The tray tick box and Task Manager stay in sync.

## Limitations

- **Admin windows:** it doesn't work inside apps running as administrator, because Windows blocks a normal app from sending keys to elevated windows.
- **Antivirus:** some antivirus tools flag new, unsigned apps that watch the keyboard. If yours does, allow `%LOCALAPPDATA%\Programs\AltCodes`. The full source is in the installer script, so you can read exactly what it does.

## License

[MIT](LICENSE)
