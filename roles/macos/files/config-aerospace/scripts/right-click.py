#!/usr/bin/env python3
import Quartz
pos = Quartz.CGEventGetLocation(Quartz.CGEventCreate(None))
down = Quartz.CGEventCreateMouseEvent(None, Quartz.kCGEventRightMouseDown, pos, Quartz.kCGMouseButtonRight)
Quartz.CGEventPost(Quartz.kCGHIDEventTap, down)
up = Quartz.CGEventCreateMouseEvent(None, Quartz.kCGEventRightMouseUp, pos, Quartz.kCGMouseButtonRight)
Quartz.CGEventPost(Quartz.kCGHIDEventTap, up)
