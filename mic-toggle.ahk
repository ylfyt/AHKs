#Requires AutoHotkey v2.0

iniFile := A_ScriptDir "\mic_config.ini"
selectedMic := IniRead(iniFile, "Settings", "Mic", "")

selGui := ""
selDDL := ""
selStatus := ""

iconLive := MakeStatusIcon(false)
iconMuted := MakeStatusIcon(true)

; Add "Select Microphone..." to the tray menu (also opens on tray double-click)
A_TrayMenu.Insert("1&", "Select Microphone...", (*) => OpenSelector())
A_TrayMenu.Insert("2&")
A_TrayMenu.Default := "Select Microphone..."

UpdateTrayStatus()
SetTimer(UpdateTrayStatus, 1000)

^!+m:: {  ; Ctrl + Alt + Shift + M: toggle mute
    if (selectedMic = "" || !DeviceExists(selectedMic)) {
        OpenSelector()
        return
    }
    try {
        SoundSetMute(-1, , selectedMic)
        isMuted := SoundGetMute(, selectedMic)
        UpdateTrayStatus()
        ToolTip(isMuted ? "Microphone Muted" : "Microphone Unmuted")
        SetTimer(() => ToolTip(), -1000)
    } catch TargetError {
        OpenSelector()
    }
}

OpenSelector() {
    global selectedMic, selGui, selDDL, selStatus

    if (selGui) {
        UpdateSelectorStatus()
        selGui.Show()
        return
    }

    devices := GetAudioDevices()
    if (devices.Length = 0) {
        MsgBox("No audio devices found.")
        return
    }

    chooseIdx := 1
    for i, dev in devices {
        if (dev = selectedMic) {
            chooseIdx := i
            break
        }
        if (selectedMic = "" && InStr(dev, "Mic")) {
            chooseIdx := i
            break
        }
    }

    selGui := Gui("+AlwaysOnTop", "Select Microphone")
    selGui.SetFont("s10", "Segoe UI")
    selGui.Add("Text", , "Choose your microphone device:")
    selDDL := selGui.Add("DropDownList", "w360 Choose" chooseIdx, devices)

    selGui.SetFont("s10 Bold", "Segoe UI")
    selStatus := selGui.Add("Text", "w360", "Status: ...")
    selGui.SetFont("s10 Norm", "Segoe UI")

    btnSave := selGui.Add("Button", "Default w90 xm y+12", "Save")
    btnToggle := selGui.Add("Button", "x+10 w110", "Toggle Mute")
    btnCancel := selGui.Add("Button", "x+10 w90", "Cancel")

    selDDL.OnEvent("Change", (*) => UpdateSelectorStatus())
    btnSave.OnEvent("Click", SaveChoice)
    btnToggle.OnEvent("Click", TestToggle)
    btnCancel.OnEvent("Click", CloseSelector)
    selGui.OnEvent("Close", CloseSelector)
    selGui.OnEvent("Escape", CloseSelector)

    UpdateSelectorStatus()
    selGui.Show()
}

TestToggle(*) {
    global selDDL
    if (!selDDL)
        return
    try {
        SoundSetMute(-1, , selDDL.Text)
        UpdateSelectorStatus()
        UpdateTrayStatus()
    } catch {
        MsgBox("This device does not support muting.")
    }
}

SaveChoice(*) {
    global selectedMic, selDDL
    selectedMic := selDDL.Text
    IniWrite(selectedMic, iniFile, "Settings", "Mic")
    CloseSelector()
    UpdateTrayStatus()
    ToolTip("Selected: " selectedMic)
    SetTimer(() => ToolTip(), -1500)
}

CloseSelector(*) {
    global selGui, selDDL, selStatus
    if (selGui) {
        selGui.Destroy()
        selGui := ""
        selDDL := ""
        selStatus := ""
    }
}

UpdateSelectorStatus() {
    global selGui, selDDL, selStatus
    if (!selGui || !selDDL || !selStatus)
        return
    try {
        isMuted := SoundGetMute(, selDDL.Text)
        newText := isMuted ? "Status: MUTED" : "Status: UNMUTED"
        if (selStatus.Value != newText) {
            selStatus.Value := newText
            selStatus.SetFont(isMuted ? "s10 Bold cC62828" : "s10 Bold c2E7D32")
        }
    } catch {
        newText := "Status: Mute not supported"
        if (selStatus.Value != newText) {
            selStatus.Value := newText
            selStatus.SetFont("s10 Norm cGray")
        }
    }
}

UpdateTrayStatus() {
    global selectedMic, iconMuted, iconLive
    static lastState := ""

    if (selectedMic = "") {
        A_IconTip := "No microphone selected"
        if (lastState != "none") {
            TraySetIcon("*")
            lastState := "none"
        }
        return
    }

    try {
        isMuted := SoundGetMute(, selectedMic)
        state := isMuted ? "muted" : "live"
        A_IconTip := selectedMic " — " (isMuted ? "MUTED" : "UNMUTED")
        if (state != lastState) {
            TraySetIcon("HICON:*" (isMuted ? iconMuted : iconLive))
            lastState := state
        }
        UpdateSelectorStatus()
    } catch {
        A_IconTip := selectedMic " (unavailable)"
        if (lastState != "none") {
            TraySetIcon("*")
            lastState := "none"
        }
    }
}

MakeStatusIcon(isMuted, size := 32) {
    bi := Buffer(40, 0)
    NumPut("UInt", 40, "Int", size, "Int", -size, "UShort", 1, "UShort", 32, bi, 0)

    hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
    hColor := DllCall("CreateDIBSection", "Ptr", hdc, "Ptr", bi, "UInt", 0, "Ptr*", &pBits := 0, "Ptr", 0, "UInt", 0, "Ptr")
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)

    rgb := isMuted ? 0xE53935 : 0x43A047
    rBase := (rgb >> 16) & 0xFF
    gBase := (rgb >> 8) & 0xFF
    bBase := rgb & 0xFF

    cx := (size - 1) / 2.0
    radius := size * 0.42

    loop size {
        y := A_Index - 1
        dy := y - cx
        loop size {
            x := A_Index - 1
            dx := x - cx
            dist := Sqrt(dx * dx + dy * dy)

            if (dist <= radius - 0.5) {
                if (isMuted && Abs(dx + dy) < 1.8 && dist <= radius - 3.5)
                    px := 0xFFFFFFFF
                else
                    px := 0xFF000000 | rgb
            } else if (dist < radius + 0.5) {
                alpha := Round((radius + 0.5 - dist) * 255)
                pr := Round(rBase * alpha / 255)
                pg := Round(gBase * alpha / 255)
                pb := Round(bBase * alpha / 255)
                px := (alpha << 24) | (pr << 16) | (pg << 8) | pb
            } else {
                px := 0
            }
            NumPut("UInt", px, pBits, (y * size + x) * 4)
        }
    }

    stride := ((size + 15) // 16) * 2
    maskBits := Buffer(size * stride, 0)
    hMask := DllCall("CreateBitmap", "Int", size, "Int", size, "UInt", 1, "UInt", 1, "Ptr", maskBits, "Ptr")

    off := (A_PtrSize = 8) ? 16 : 12
    ii := Buffer(off + 2 * A_PtrSize, 0)
    NumPut("Int", 1, ii, 0)
    NumPut("Ptr", hMask, ii, off)
    NumPut("Ptr", hColor, ii, off + A_PtrSize)

    hIcon := DllCall("CreateIconIndirect", "Ptr", ii, "Ptr")
    DllCall("DeleteObject", "Ptr", hMask)
    DllCall("DeleteObject", "Ptr", hColor)
    return hIcon
}

GetAudioDevices() {
    devices := []
    counts := Map()
    counts.CaseSense := false
    loop {
        try
            name := SoundGetName(, A_Index)
        catch
            break
        n := counts.Has(name) ? counts[name] + 1 : 1
        counts[name] := n
        devices.Push(n > 1 ? name ":" n : name)
    }
    return devices
}

DeviceExists(dev) {
    try {
        SoundGetName(, dev)
        return true
    } catch {
        return false
    }
}