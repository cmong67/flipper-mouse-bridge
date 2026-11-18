import AppKit
@main struct Tests {
 static func main() {
  supportTests()
  assert(FlipperCommands.translate("click")==nil)
  assert(FlipperCommands.translate("double")==nil)
  assert(FlipperCommands.translate("click right")==MouseCommand.click(2,1))
  assert(FlipperCommands.translate("double left")==MouseCommand.click(1,2))
  assert(FlipperCommands.translate("move 128 0")==nil)
  assert(FlipperCommands.translate("scroll 2 3")==nil)
  assert(FlipperCommands.translate("down left")==nil)
  assert(FlipperCommands.translate("drag right 10 0")==nil)
  assert(FlipperCommands.translate("move -127 127")==MouseCommand.move(-127,127))
  assert(FlipperCommands.translate("stop")==MouseCommand.raw("SAFE"))
  assert(!MouseCommand.raw("host 0 0 1 App").needsArm)
  assert(MouseButtons.index(type:.rightMouseDown,reported:0,control:false)==1)
  var c=ClickTracker()
  assert(c.down(button:1,point:.zero,time:1,systemCount:1,interval:0.5)==1)
  assert(c.down(button:1,point:.zero,time:1.2,systemCount:1,interval:0.5)==2)
  print("PASS: unified command mapping, capabilities, right-button identity, double-click fallback")
 }
}
