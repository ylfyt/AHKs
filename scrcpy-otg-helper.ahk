#Requires AutoHotkey v2.0
#SingleInstance Force

DetectHiddenWindows true

Scrcpy := "scr_v510_otg ahk_class SDL_app"
ScrcpyHwnd := 0
ScrcpyStarting := false
ScrcpyVisible := false
LastSelectedDevice := ""

; Register Windows foreground event hook
HookProc := CallbackCreate(ForegroundChanged, "F", 7)

HookHandle := DllCall(
    "SetWinEventHook",
    "UInt", 0x0003,  ; EVENT_SYSTEM_FOREGROUND
    "UInt", 0x0003,
    "Ptr", 0,
    "Ptr", HookProc,
    "UInt", 0,
    "UInt", 0,
    "UInt", 0,
    "Ptr"
)

if !HookHandle {
    MsgBox "Cannot register Windows event hook.", "Scrcpy error"
    ExitApp
}

OnExit Cleanup

^!+p::  ; Ctrl+Alt+P
{
    StartScrcpy(false)
}
 
^!+o::  ; Ctrl+Alt+O
{
    StartScrcpy(true)
}

StartScrcpy(withAudio)
{
    global Scrcpy, ScrcpyHwnd, ScrcpyStarting, ScrcpyVisible, LastSelectedDevice

    ; Check if scrcpy already exists
    if WinExist(Scrcpy) {
        ScrcpyHwnd := WinExist(Scrcpy)

        ; If visible and active, hide it
        if ScrcpyVisible && WinActive("ahk_id " ScrcpyHwnd) {
            WinHide("ahk_id " ScrcpyHwnd)
            ScrcpyVisible := false
        }
        ; Otherwise show and activate
        else {
            ScrcpyVisible := true
            WinShow("ahk_id " ScrcpyHwnd)
            WinActivate("ahk_id " ScrcpyHwnd)
            ControlClick "x1 y1", "ahk_id " ScrcpyHwnd
        }
        return
    }

    ScrcpyVisible := false

    ; Start adb server
    Run("adb start-server", , "Hide")
    NewPID := ProcessWait("adb.exe", 15)

    if not NewPID {
        MsgBox "Cannot start adb server.", "Scrcpy error"
        return
    }

    ; Select Android device
    Device := SelectAdbDevice()

    if !Device
        return
		
	LastSelectedDevice := Device

    ; Start scrcpy
    SetWorkingDir "C:\Users\YA\scrcpy"

    ScrcpyStarting := true

    AudioArg := withAudio ? "" : " --no-audio"

    Run 'scrcpy-noconsole.vbs --serial="' Device '"' AudioArg ' --no-video --keyboard=uhid --mouse=uhid --gamepad=uhid --window-title=scr_v510_otg'

    if WinWait(Scrcpy, , 10) {
        try {
            ScrcpyHwnd := WinExist(Scrcpy)
            ScrcpyVisible := true

            WinShow("ahk_id " ScrcpyHwnd)
            WinActivate("ahk_id " ScrcpyHwnd)
            ControlClick "x1 y1", "ahk_id " ScrcpyHwnd
        }
        catch Error as e {
            MsgBox "Scrcpy start failed!", "Scrcpy error"
        }

        ScrcpyStarting := false
        return
    }

    ScrcpyStarting := false
    MsgBox "Scrcpy start timeout", "Scrcpy error"
}


; Windows foreground event callback
ForegroundChanged(hHook, event, hwnd, idObject, idChild, eventThread, eventTime)
{
    global ScrcpyHwnd, ScrcpyStarting, ScrcpyVisible

    ; Ignore events while starting or already hidden
    if ScrcpyStarting || !ScrcpyVisible
        return

    ; Ignore if scrcpy is already foreground
    if hwnd = ScrcpyHwnd
        return

    ; Another application became foreground
    try {
        WinHide("ahk_id " ScrcpyHwnd)
        ScrcpyVisible := false
    }
}


; Cleanup Windows event hook
Cleanup(*)
{
    global HookHandle, HookProc, ScrcpyHwnd, LastSelectedDevice

    ; Close scrcpy window
    if ScrcpyHwnd && WinExist("ahk_id " ScrcpyHwnd)
        WinClose("ahk_id " ScrcpyHwnd)

    ; Unregister Windows event hook
    if HookHandle
        DllCall("UnhookWinEvent", "Ptr", HookHandle)

    ; Free callback
    if HookProc
        CallbackFree(HookProc)
}


SelectAdbDevice()
{
	global LastSelectedDevice
	
    shell := ComObject("WScript.Shell")
    exec := shell.Exec("adb devices")
    output := exec.StdOut.ReadAll()

    devices := []

    ; Parse connected devices
    Loop Parse output, "`n", "`r"
    {
        if RegExMatch(A_LoopField, "^\s*(\S+)\s+device\s*$", &m)
            devices.Push(m[1])
    }

    ; No devices
    if devices.Length = 0 {
        MsgBox "No Android devices connected.", "Scrcpy error"
        return ""
    }

    ; Only one device: automatic selection
    if devices.Length = 1
        return devices[1]

    ; Multiple devices: show radio selection
    selected := ""

    dlg := Gui("+AlwaysOnTop", "Select Android device")
    dlg.MarginX := 15
    dlg.MarginY := 15

    dlg.AddText("w300", "Multiple devices detected. Select one:")

    radios := []

    for i, device in devices {
        radio := dlg.AddRadio(
            (i = 1 ? "Checked " : "") "xm y+10",
            device
        )
        radios.Push(radio)
		
		if (device = LastSelectedDevice)
			radio.Value := 1
    }

    connectBtn := dlg.AddButton("Default xm y+20 w100", "Connect")
    cancelBtn := dlg.AddButton("x+10 w100", "Cancel")

    connectBtn.OnEvent("Click", (*) => Submit())
    cancelBtn.OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())

    Submit()
    {
        for i, radio in radios {
            if radio.Value {
                selected := devices[i]
                break
            }
        }

        dlg.Destroy()
    }

    dlg.Show("AutoSize Center")

    WinWaitClose("ahk_id " dlg.Hwnd)

    return selected
}
