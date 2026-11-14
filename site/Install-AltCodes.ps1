# Install-AltCodes.ps1 - builds and installs "Alt Codes", a tray app that makes
# Left Alt + top-row digits act as numpad digits, so Alt codes work without a numpad.
# Uses only what ships with Windows (PowerShell + the .NET Framework C# compiler).
#
#   Install / update:  powershell -NoProfile -ExecutionPolicy Bypass -File Install-AltCodes.ps1
#   Uninstall:         powershell -NoProfile -ExecutionPolicy Bypass -File Install-AltCodes.ps1 -Uninstall

param([switch]$Uninstall)
$ErrorActionPreference = 'Stop'

$dir      = Join-Path $env:LOCALAPPDATA 'Programs\AltCodes'
$exe      = Join-Path $dir 'AltCodes.exe'
$ico      = Join-Path $dir 'AltCodes.ico'
$src      = Join-Path $dir 'AltCodes.cs'
$lnk      = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Alt Codes.lnk'
$runKey   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'

# Stop a running copy so the exe can be replaced or removed
Get-Process AltCodes -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500

if ($Uninstall) {
    Remove-ItemProperty $runKey   -Name AltCodes -ErrorAction SilentlyContinue
    Remove-ItemProperty $approved -Name AltCodes -ErrorAction SilentlyContinue
    Remove-Item $lnk, $dir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host 'Alt Codes removed.'
    return
}

New-Item -ItemType Directory -Path $dir -Force | Out-Null

# ---------------------------------------------------------------- icon
Add-Type -AssemblyName System.Drawing

function New-IconFrame([int]$s) {
    $bmp = New-Object System.Drawing.Bitmap $s, $s, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'

    # Rounded blue square
    $d = [Math]::Max(4, [int]($s * 0.4)); $m = $s - 1
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0, 0, $d, $d, 180, 90)
    $path.AddArc($m - $d, 0, $d, $d, 270, 90)
    $path.AddArc($m - $d, $m - $d, $d, $d, 0, 90)
    $path.AddArc(0, $m - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 37, 99, 235))), $path)

    # "Alt" when there is room, "A" on the smallest sizes
    if ($s -ge 24) { $text = 'Alt'; $em = $s * 0.40 } else { $text = 'A'; $em = $s * 0.72 }
    $font = New-Object System.Drawing.Font 'Segoe UI', $em, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
    $g.DrawString($text, $font, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF 0, 0, $s, $s), $fmt)
    $g.Dispose()
    $bmp
}

# One ICO frame as a 32-bit DIB (BITMAPINFOHEADER + bottom-up BGRA + empty AND mask)
function Get-DibBytes($bmp) {
    $s = $bmp.Width
    $data = $bmp.LockBits((New-Object System.Drawing.Rectangle 0, 0, $s, $s), 'ReadOnly', 'Format32bppArgb')
    $px = New-Object byte[] ($s * $s * 4)
    [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $px, 0, $px.Length)
    $bmp.UnlockBits($data)

    $ms = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter $ms
    $w.Write([int]40); $w.Write([int]$s); $w.Write([int]($s * 2)); $w.Write([int16]1); $w.Write([int16]32)
    1..6 | ForEach-Object { $w.Write([int]0) }
    for ($y = $s - 1; $y -ge 0; $y--) { $w.Write($px, $y * $s * 4, $s * 4) }
    $w.Write((New-Object byte[] ([int]([Math]::Ceiling($s / 32.0) * 4) * $s)))
    $w.Flush()
    return ,$ms.ToArray()
}

$sizes  = 16, 20, 24, 32, 40, 48, 64, 256
$frames = foreach ($s in $sizes) { $b = New-IconFrame $s; ,(Get-DibBytes $b); $b.Dispose() }

$ms = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter $ms
$w.Write([int16]0); $w.Write([int16]1); $w.Write([int16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $dim = [byte]($(if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }))
    $w.Write($dim); $w.Write($dim); $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([int16]1); $w.Write([int16]32); $w.Write([int]$frames[$i].Length); $w.Write([int]$offset)
    $offset += $frames[$i].Length
}
foreach ($f in $frames) { $w.Write($f) }
$w.Flush()
[IO.File]::WriteAllBytes($ico, $ms.ToArray())

# ---------------------------------------------------------------- app source (C# 5, for the built-in csc)
Set-Content -Path $src -Encoding UTF8 -Value @'
using System;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: AssemblyTitle("Alt Codes")]
[assembly: AssemblyProduct("Alt Codes")]
[assembly: AssemblyCompany("Alt Codes")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

static class Program
{
    const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    const string ApprovedKey = @"Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run";
    const string ValueName = "AltCodes";

    static NotifyIcon tray;
    static Control invoker;

    [DllImport("user32.dll")]
    static extern bool SetProcessDPIAware();

    [STAThread]
    static void Main(string[] args)
    {
        bool fromStartup = args.Length > 0 && args[0] == "--startup";
        bool first;
        using (var mutex = new Mutex(true, @"Local\AltCodesTray", out first))
        using (var showSignal = new EventWaitHandle(false, EventResetMode.AutoReset, @"Local\AltCodesShow"))
        {
            // Opened again from the Start menu: ask the running copy to say hello, then quit
            if (!first) { showSignal.Set(); return; }

            SetProcessDPIAware();
            Application.EnableVisualStyles();

            invoker = new Control();
            IntPtr forceHandle = invoker.Handle;
            ThreadPool.RegisterWaitForSingleObject(showSignal,
                delegate { invoker.BeginInvoke((MethodInvoker)ShowRunning); }, null, -1, false);

            RefreshStartupPath();

            var status = new ToolStripMenuItem("Alt Codes is running");
            status.Enabled = false;
            var startupItem = new ToolStripMenuItem("Run on startup");
            startupItem.Click += delegate { SetStartup(!IsStartupEnabled()); };

            var menu = new ContextMenuStrip();
            menu.Items.Add(status);
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add(startupItem);
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add("Exit", null, delegate { Application.Exit(); });
            // Re-read each time so a change made in Task Manager shows up here
            menu.Opening += delegate { startupItem.Checked = IsStartupEnabled(); };

            tray = new NotifyIcon();
            tray.Icon = LoadTrayIcon();
            tray.Text = "Alt Codes - running";
            tray.ContextMenuStrip = menu;
            tray.MouseClick += delegate(object s, MouseEventArgs e) { if (e.Button == MouseButtons.Left) ShowRunning(); };
            tray.Visible = true;

            KeyHook.Install();
            if (!fromStartup) ShowRunning();

            Application.Run();

            KeyHook.Uninstall();
            tray.Visible = false;
            tray.Dispose();
        }
    }

    static void ShowRunning()
    {
        tray.ShowBalloonTip(3000, "Alt Codes is running",
            "Hold Left Alt and type a code on the number row, e.g. 130 = é.", ToolTipIcon.None);
    }

    static Icon LoadTrayIcon()
    {
        string ico = Path.Combine(Path.GetDirectoryName(Application.ExecutablePath), "AltCodes.ico");
        try { return new Icon(ico, SystemInformation.SmallIconSize); }
        catch { return Icon.ExtractAssociatedIcon(Application.ExecutablePath); }
    }

    static string RunCommand()
    {
        return "\"" + Application.ExecutablePath + "\" --startup";
    }

    // Startup state uses the same registry values as Task Manager's Startup tab:
    // the Run value must exist, and StartupApproved (if present) must not be odd (= disabled).
    static bool IsStartupEnabled()
    {
        using (var run = Registry.CurrentUser.OpenSubKey(RunKey))
        {
            if (run == null || run.GetValue(ValueName) == null) return false;
        }
        using (var ap = Registry.CurrentUser.OpenSubKey(ApprovedKey))
        {
            byte[] b = ap == null ? null : ap.GetValue(ValueName) as byte[];
            return b == null || b.Length == 0 || (b[0] & 1) == 0;
        }
    }

    static void SetStartup(bool on)
    {
        using (var run = Registry.CurrentUser.CreateSubKey(RunKey))
        {
            run.SetValue(ValueName, RunCommand());
        }
        var b = new byte[12];
        b[0] = (byte)(on ? 2 : 3);
        if (!on) Array.Copy(BitConverter.GetBytes(DateTime.UtcNow.ToFileTimeUtc()), 0, b, 4, 8);
        using (var ap = Registry.CurrentUser.CreateSubKey(ApprovedKey))
        {
            ap.SetValue(ValueName, b, RegistryValueKind.Binary);
        }
    }

    // Keep the Run entry pointing at this exe without changing its enabled/disabled state
    static void RefreshStartupPath()
    {
        using (var run = Registry.CurrentUser.OpenSubKey(RunKey, true))
        {
            if (run != null && run.GetValue(ValueName) != null) run.SetValue(ValueName, RunCommand());
        }
    }
}

static class KeyHook
{
    const int WH_KEYBOARD_LL = 13;
    const int WM_KEYDOWN = 0x100, WM_KEYUP = 0x101, WM_SYSKEYDOWN = 0x104, WM_SYSKEYUP = 0x105;
    const uint LLKHF_INJECTED = 0x10;
    const uint VK_LMENU = 0xA4;
    const int VK_CONTROL = 0x11;
    const uint INPUT_KEYBOARD = 1, KEYEVENTF_KEYUP = 0x2;

    // Set-1 scan codes for Numpad 0..9
    static readonly ushort[] NumpadScan = { 0x52, 0x4F, 0x50, 0x51, 0x4B, 0x4C, 0x4D, 0x47, 0x48, 0x49 };

    [StructLayout(LayoutKind.Sequential)]
    struct KBDLLHOOKSTRUCT { public uint vkCode, scanCode, flags, time; public IntPtr dwExtraInfo; }

    [StructLayout(LayoutKind.Sequential)]
    struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr dwExtraInfo; }

    [StructLayout(LayoutKind.Sequential)]
    struct KEYBDINPUT { public ushort wVk, wScan; public uint dwFlags, time; public IntPtr dwExtraInfo; }

    [StructLayout(LayoutKind.Explicit)]
    struct InputUnion { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }

    [StructLayout(LayoutKind.Sequential)]
    struct INPUT { public uint type; public InputUnion u; }

    delegate IntPtr HookProc(int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    static extern IntPtr SetWindowsHookEx(int idHook, HookProc fn, IntPtr hMod, uint threadId);
    [DllImport("user32.dll")]
    static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")]
    static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll", SetLastError = true)]
    static extern uint SendInput(uint nInputs, INPUT[] inputs, int cbSize);
    [DllImport("user32.dll")]
    static extern short GetAsyncKeyState(int vKey);
    [DllImport("kernel32.dll")]
    static extern IntPtr GetModuleHandle(string name);

    static readonly HookProc proc = Callback;   // static so the GC never collects the delegate
    static IntPtr hook;
    static bool lAltDown;
    static readonly bool[] remapped = new bool[10];

    public static void Install()
    {
        hook = SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(null), 0);
        if (hook == IntPtr.Zero) throw new System.ComponentModel.Win32Exception();
    }

    public static void Uninstall()
    {
        if (hook != IntPtr.Zero) UnhookWindowsHookEx(hook);
        hook = IntPtr.Zero;
    }

    static IntPtr Callback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            var k = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));
            int msg = (int)wParam;
            bool down = msg == WM_KEYDOWN || msg == WM_SYSKEYDOWN;
            bool up = msg == WM_KEYUP || msg == WM_SYSKEYUP;

            if ((k.flags & LLKHF_INJECTED) == 0)
            {
                if (k.vkCode == VK_LMENU)
                {
                    if (down) lAltDown = true; else if (up) lAltDown = false;
                }
                else if (k.vkCode >= 0x30 && k.vkCode <= 0x39)
                {
                    int d = (int)k.vkCode - 0x30;
                    bool ctrl = (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0;   // leave AltGr combos alone
                    if (down && lAltDown && !ctrl) { remapped[d] = true; Send(d, false); return (IntPtr)1; }
                    if (up && remapped[d])         { remapped[d] = false; Send(d, true); return (IntPtr)1; }
                }
            }
        }
        return CallNextHookEx(hook, nCode, wParam, lParam);
    }

    static void Send(int d, bool keyUp)
    {
        var input = new INPUT();
        input.type = INPUT_KEYBOARD;
        input.u.ki.wVk = (ushort)(0x60 + d);      // VK_NUMPAD0..9
        input.u.ki.wScan = NumpadScan[d];
        input.u.ki.dwFlags = keyUp ? KEYEVENTF_KEYUP : 0;
        SendInput(1, new[] { input }, Marshal.SizeOf(typeof(INPUT)));
    }
}
'@

# ---------------------------------------------------------------- compile
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
& $csc /nologo /target:winexe /optimize+ "/out:$exe" "/win32icon:$ico" `
    /r:System.Windows.Forms.dll /r:System.Drawing.dll $src
if ($LASTEXITCODE -ne 0) { throw 'Compile failed (see errors above).' }
Remove-Item $src

# ---------------------------------------------------------------- Start menu shortcut
$sc = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
$sc.TargetPath = $exe
$sc.WorkingDirectory = $dir
$sc.IconLocation = "$exe,0"
$sc.Description = 'Alt codes from the number row'
$sc.Save()

# ---------------------------------------------------------------- run on startup (first install only; later
# installs keep whatever was chosen in the tray menu or Task Manager)
if ($null -eq (Get-ItemProperty $runKey -Name AltCodes -ErrorAction SilentlyContinue)) {
    Set-ItemProperty $runKey -Name AltCodes -Value "`"$exe`" --startup"
}

Start-Process $exe
Write-Host "Alt Codes installed to $dir and started. Look for the blue 'Alt' icon in the tray."
