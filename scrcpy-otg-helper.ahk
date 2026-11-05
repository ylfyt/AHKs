#Requires AutoHotkey v2.0
#SingleInstance Force

DetectHiddenWindows true

scrcpyWindowCode := "scr_v510_otg ahk_class SDL_app"
scrcpyHwnd := 0
isScrcpyStarted := false
isScrcpyVisible := false
lastSelectedDevice := ""

; Register Windows foreground event hook
hookProc := CallbackCreate(ForegroundChanged, "F", 7)
hookHandle := DllCall(
    "SetWinEventHook",
    "UInt", 0x0003,  ; EVENT_SYSTEM_FOREGROUND
    "UInt", 0x0003,
    "Ptr", 0,
    "Ptr", hookProc,
    "UInt", 0,
    "UInt", 0,
    "UInt", 0,
    "Ptr"
)

if !hookHandle {
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

StartScrcpy(withAudio) {
    global scrcpyWindowCode, scrcpyHwnd, isScrcpyStarted, isScrcpyVisible, lastSelectedDevice

    ; Check if scrcpy already exists
    if WinExist(scrcpyWindowCode) {
        scrcpyHwnd := WinExist(scrcpyWindowCode)

        ; If visible and active, hide it
        if isScrcpyVisible && WinActive("ahk_id " scrcpyHwnd) {
            WinHide("ahk_id " scrcpyHwnd)
            isScrcpyVisible := false
        }
        ; Otherwise show and activate
        else {
            isScrcpyVisible := true
            WinShow("ahk_id " scrcpyHwnd)
            WinActivate("ahk_id " scrcpyHwnd)
            ControlClick "x1 y1", "ahk_id " scrcpyHwnd
        }
        return
    }

    isScrcpyVisible := false

    ; Start adb server
    Run("adb start-server", , "Hide")
    newPID := ProcessWait("adb.exe", 15)

    if not newPID {
        MsgBox "Cannot start adb server.", "Scrcpy error"
        return
    }

    ; Select Android device
    device := SelectAdbDevice()

    if !device
        return

    lastSelectedDevice := device

    ; Start scrcpy
    isScrcpyStarted := true
    audioArg := withAudio ? "" : " --no-audio"

    Run 'C:\Users\YA\scrcpy\scrcpy-noconsole.vbs --serial="' device '"' audioArg ' --no-video --keyboard=uhid --mouse=uhid --gamepad=uhid --window-title=scr_v510_otg'

    if WinWait(scrcpyWindowCode, , 10) {
        try {
            scrcpyHwnd := WinExist(scrcpyWindowCode)
            isScrcpyVisible := true

            WinShow("ahk_id " scrcpyHwnd)
            WinActivate("ahk_id " scrcpyHwnd)
            ControlClick "x1 y1", "ahk_id " scrcpyHwnd
        }
        catch Error as e {
            MsgBox "Scrcpy start failed!", "Scrcpy error"
        }

        isScrcpyStarted := false
        return
    }

    isScrcpyStarted := false
    MsgBox "Scrcpy start timeout", "Scrcpy error"
}

; Windows foreground event callback
ForegroundChanged(hHook, event, hwnd, idObject, idChild, eventThread, eventTime) {
    global scrcpyHwnd, isScrcpyStarted, isScrcpyVisible

    ; Ignore events while starting or already hidden
    if isScrcpyStarted || !isScrcpyVisible
        return

    ; Ignore if scrcpy is already foreground
    if hwnd = scrcpyHwnd
        return

    ; Another application became foreground
    try {
        WinHide("ahk_id " scrcpyHwnd)
        isScrcpyVisible := false
    }
}

; Cleanup Windows event hook
Cleanup(*) {
    global hookHandle, hookProc, scrcpyHwnd, lastSelectedDevice

    ; Close scrcpy window
    if scrcpyHwnd && WinExist("ahk_id " scrcpyHwnd)
        WinClose("ahk_id " scrcpyHwnd)

    ; Unregister Windows event hook
    if hookHandle
        DllCall("UnhookWinEvent", "Ptr", hookHandle)

    ; Free callback
    if hookProc
        CallbackFree(hookProc)
}

SelectAdbDevice() {
    global lastSelectedDevice

    shell := ComObject("WScript.Shell")
    exec := shell.Exec("adb devices")
    output := exec.StdOut.ReadAll()

    devices := []

    ; Parse connected devices
    loop parse output, "`n", "`r" {
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

        if (device = lastSelectedDevice)
            radio.Value := 1
    }

    connectBtn := dlg.AddButton("Default xm y+20 w100", "Connect")
    cancelBtn := dlg.AddButton("x+10 w100", "Cancel")

    connectBtn.OnEvent("Click", (*) => Submit())
    cancelBtn.OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())

    Submit() {
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
