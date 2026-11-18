import AppKit
@main struct MouseInputTests {
 static func main() {
  for type:NSEvent.EventType in [.rightMouseDown,.rightMouseUp,.rightMouseDragged] {
   assert(MouseButtons.index(type:type,reported:0,control:false)==1)
  }
  assert(MouseButtons.index(type:.leftMouseDown,reported:1,control:false)==0)
  assert(MouseButtons.index(type:.leftMouseDown,reported:0,control:true)==1)
  assert(MouseButtons.index(type:.otherMouseDown,reported:2,control:false)==2)
  assert(MouseButtons.index(type:.otherMouseDown,reported:99,control:false)==4)
  var c=ClickTracker();let p=NSPoint(x:40,y:50)
  assert(c.down(button:0,point:p,time:10,systemCount:1,interval:0.5)==1)
  assert(c.down(button:1,point:p,time:10.1,systemCount:1,interval:0.5)==1)
  assert(c.down(button:0,point:p,time:10.2,systemCount:1,interval:0.5)==2)
  assert(c.count(button:0)==2)
  assert(c.down(button:0,point:p,time:10.3,systemCount:3,interval:0.5)==1)
  assert(c.down(button:0,point:NSPoint(x:100,y:50),time:10.4,systemCount:1,interval:0.5)==1)
  assert(c.down(button:0,point:p,time:11,systemCount:1,interval:0.5)==1)
  assert(c.down(button:2,point:p,time:12,systemCount:2,interval:0.5)==2)
  print("PASS: button mapping, independent double-click timing, distance, triple-click reset, OS counts")
 }
}
