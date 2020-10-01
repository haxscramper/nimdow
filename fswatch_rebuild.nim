import libfswatch, libfswatch/fswatch
import bitops, osproc, strtabs, os
import hmisc/helpers
import hmisc/other/[hshell, pathwrap, oswrap, colorlogger]

import x11/[xlib, xutil, x, keysym]

startColorLogger()

type
  FsEventFlag = fsw_event_flag
  FsEvent = fsw_cevent

func `$`(fl: FsEventFlag): string =
  case fl:
    of NoOp: "NoOp"
    of PlatformSpecific: "PlatformSpecific"
    of Created: "Created"
    of Updated: "Updated"
    of Removed: "Removed"
    of Renamed: "Renamed"
    of OwnerModified: "OwnerModified"
    of AttributeModified: "AttributeModified"
    of MovedFrom: "MovedFrom"
    of MovedTo: "MovedTo"
    of IsFile: "IsFile"
    of IsDir: "IsDir"
    of IsSymLink: "IsSymLink"
    of Link: "Link"
    of Overflow: "Overflow"

func contains[T](superset: set[T], subset: set[T]): bool =
  len(subset - superset) == 0

proc getFlags(ev: FsEvent): set[FsEventFlag] =
  let flags = ev.flags[]
  for i in 0 .. 13:
    if bitand(1 shl i, cast[int](flags)) != 0:
      result.incl FsEventFlag(1 shl i)

proc newMonitor(path: AnyPath, cb: proc(event: FsEvent)): Monitor =
  result = newMonitor()
  result.addPath(path.string)
  result.setCallback do(event: FsEvent, num: cuint):
    cb(event)




let cmd = makeX11Cmd("Xephyr").withIt do:
  it.flag "resizeable"
  it.flag "retro"
  it.flag "sw-cursor"
  it.flag "softCursor"
  it.flag "ac"
  it.raw ":1"

if false:
  let xephyr = startShell(cmd, {poEvalCommand, poParentStreams})

setEnv("DISPLAY", ":1")

let build = makeNimCmd("nimble").withIt do:
  it.cmd "build"

let nimdow = makeX11Cmd("./nimdow config.default.toml")

var
  display = XOpenDisplay(nil)
  root: Window

if display == nil:
  err "Failed to to open display"
else:
  info "Display open op"


let
  screen = XDefaultScreen(display)
  rootWindow = XRootWindow(display, screen)

# var
#   subw: ptr[Window]
#   rootRet: Window
#   parentWindow: Window
#   cnt: cuint

# let status = XQueryTree(
#   display, rootWindow,
#   addr rootRet, addr parentWindow, addr subw, addr cnt)

# echo cnt


proc makeEvent(): XKeyEvent =
  result.display = display
  result.x = 1
  result.y = 1
  result.xRoot = 1
  result.yRoot = 1
  result.sameScreen = XBool(1)
  result.theType = KeyPress
  result.keycode = cuint(XK_2)
  result.state = cuint(XK_Super_L)

proc sendEvents =
  var ev = makeEvent()
  discard XSendEvent(display, rootWindow, XBool(1),
                     ButtonPressMask, cast[ptr XEvent](addr ev))

  info "Events send"


var nimdowProc: Process

proc updateRun =
  discard runShell(
    build,
    options = {poEvalCommand, poParentStreams},
    discardOut = true
  )

  info "Build complete"
  if nimdowProc != nil:
    nimdowProc.close()

  nimdowProc = startShell(nimdow)
  sleep 200
  sendEvents()

setEnv("DISPLAY", ":1")

updateRun()

var mon = newMonitor("src".RelDir) do(event: FsEvent):
  if Updated in event.getFlags():
    try:
      updateRun()
    except ShellError:
      printShellError()

mon.start()
