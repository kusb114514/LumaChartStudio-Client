if ($env:LUMACHART_FOREGROUND_AUTOMATION_CONSENT -cne
    "USER_CONFIRMED_DESKTOP_AVAILABLE") {
    throw (
        "Foreground GUI automation is disabled. Set " +
        "LUMACHART_FOREGROUND_AUTOMATION_CONSENT=" +
        "USER_CONFIRMED_DESKTOP_AVAILABLE only after the user explicitly " +
        "confirms that the desktop is available.")
}

if (-not ("LumaChartForegroundAutomationConsentNative" -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class LumaChartForegroundAutomationConsentNative
{
    public const long MinimumIdleMilliseconds = 3000;

    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO
    {
        public uint Size;
        public uint Time;
    }

    [DllImport("user32.dll")]
    public static extern bool GetLastInputInfo(ref LASTINPUTINFO input);

    [DllImport("kernel32.dll")]
    public static extern ulong GetTickCount64();

    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int virtualKey);

    public static long GetIdleMilliseconds()
    {
        var input = new LASTINPUTINFO
        {
            Size = (uint)Marshal.SizeOf<LASTINPUTINFO>()
        };
        if (!GetLastInputInfo(ref input))
            throw new InvalidOperationException("GetLastInputInfo failed.");

        var now = unchecked((uint)GetTickCount64());
        return unchecked((uint)(now - input.Time));
    }

    public static bool IsKeyDown(int virtualKey) =>
        (GetAsyncKeyState(virtualKey) & 0x8000) != 0;
}
'@
}

$script:WindowsAvaloniaForegroundAutomationIdleMilliseconds =
    [LumaChartForegroundAutomationConsentNative]::GetIdleMilliseconds()
$script:WindowsAvaloniaForegroundAutomationReservedDesktopConsentUsed = $false
if ($script:WindowsAvaloniaForegroundAutomationIdleMilliseconds -lt
    [LumaChartForegroundAutomationConsentNative]::MinimumIdleMilliseconds) {
    if ($env:LUMACHART_FOREGROUND_AUTOMATION_RESERVED_DESKTOP_CONSENT -cne
        "USER_CONFIRMED_ALL_DESKTOP_INPUT_RESERVED") {
        throw (
            "Foreground GUI automation requires at least " +
            "$([LumaChartForegroundAutomationConsentNative]::MinimumIdleMilliseconds) " +
            "ms of system idle time; observed " +
            "$script:WindowsAvaloniaForegroundAutomationIdleMilliseconds ms. " +
            "A continuously injected remote-input channel may proceed only after " +
            "the user explicitly reserves all desktop input.")
    }
    $script:WindowsAvaloniaForegroundAutomationReservedDesktopConsentUsed = $true
}

$heldModifiers = @(
    [ordered]@{ Name = "Shift"; VirtualKey = 0x10 }
    [ordered]@{ Name = "Ctrl"; VirtualKey = 0x11 }
    [ordered]@{ Name = "Alt"; VirtualKey = 0x12 }
    [ordered]@{ Name = "LeftWin"; VirtualKey = 0x5B }
    [ordered]@{ Name = "RightWin"; VirtualKey = 0x5C }
) | Where-Object {
    [LumaChartForegroundAutomationConsentNative]::IsKeyDown(
        [int]$_.VirtualKey)
}
if (@($heldModifiers).Count -ne 0) {
    throw (
        "Foreground GUI automation cannot start while modifiers are held: " +
        ((@($heldModifiers) | ForEach-Object Name) -join ", "))
}
