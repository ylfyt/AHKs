
#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================
; Configuration
; =========================
widgetW := 86
widgetH := 46

; =========================
; Create Widget
; =========================
widget := Gui("+ToolWindow -Caption +AlwaysOnTop")
widget.BackColor := "1E293B"

; Font
widget.SetFont("s8 Bold cFFFFFF", "Segoe UI")

; Buttons
btn1 := widget.AddButton(
    "x4 y3 w78 h18",
    "⚡  Hello 1"
)

btn2 := widget.AddButton(
    "x4 y25 w78 h18",
    "●  Hello 2"
)

; =========================
; Button Events
; =========================
btn1.OnEvent("Click", (*) => MsgBox("hello1"))
btn2.OnEvent("Click", (*) => MsgBox("hello2"))

; =========================
; Find Windows Taskbar
; =========================
taskbar := WinExist("ahk_class Shell_TrayWnd")

if !taskbar {
    MsgBox("Windows taskbar not found!")
    ExitApp()
}

; =========================
; Show and Embed Widget
; =========================
widget.Show("NA w" widgetW " h" widgetH)

DllCall("SetParent", "Ptr", widget.Hwnd, "Ptr", taskbar)

; =========================
; Center Widget
; =========================
CenterWidget() {
    global widget, widgetW, widgetH, taskbar

    if !WinExist("ahk_id " taskbar)
        return

    WinGetPos(&taskX, &taskY, &taskW, &taskH, "ahk_id " taskbar)

    x := (taskW - widgetW) // 2
    y := (taskH - widgetH) // 2

    DllCall("SetWindowPos",
        "Ptr", widget.Hwnd,
        "Ptr", 0,
        "Int", x,
        "Int", y,
        "Int", widgetW,
        "Int", widgetH,
        "UInt", 0x10)
}

CenterWidget()

; =========================
; Keep Position Updated
; =========================
SetTimer(CenterWidget, 2000)

