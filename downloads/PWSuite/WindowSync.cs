using System;using System.Runtime.InteropServices;
public static class PWSuiteWindowSync {
 [StructLayout(LayoutKind.Sequential)]public struct RECT{public int Left,Top,Right,Bottom;}
 [StructLayout(LayoutKind.Sequential)]public struct POINT{public int X,Y;}
 [DllImport("user32.dll")]public static extern bool IsWindow(IntPtr h);
 [DllImport("user32.dll")]public static extern bool IsIconic(IntPtr h);
 [DllImport("user32.dll")]public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")]public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")]static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
 [DllImport("user32.dll")]static extern bool GetClientRect(IntPtr h,out RECT r);
 [DllImport("user32.dll")]static extern bool GetWindowRect(IntPtr h,out RECT r);
 [DllImport("user32.dll")]static extern bool ClientToScreen(IntPtr h,ref POINT p);
 [DllImport("user32.dll")]static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int w,int height,uint flags);
 [DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr h,int cmd);
 public static int AnchorX=-1,AnchorY=24;static int PreferredHeight=0;
 static bool Client(IntPtr game,out RECT r){r=new RECT();RECT c;if(!GetClientRect(game,out c))return false;POINT p=new POINT();if(!ClientToScreen(game,ref p))return false;r.Left=p.X;r.Top=p.Y;r.Right=p.X+c.Right;r.Bottom=p.Y+c.Bottom;return r.Right>r.Left&&r.Bottom>r.Top;}
 public static void CaptureAnchor(IntPtr panel,IntPtr game){RECT p,g;if(GetWindowRect(panel,out p)&&Client(game,out g)){AnchorX=p.Left-g.Left;AnchorY=p.Top-g.Top;}}
 // Returns: -1 game closed; 0 hidden; 1 synchronized; 2 panel minimized.
 public static int Follow(IntPtr panel,IntPtr game,uint gamePid,uint appPid){
  if(game==IntPtr.Zero){if(IsWindowVisible(panel))ShowWindow(panel,0);return 0;}
  if(!IsWindow(game))return -1;
  uint foregroundPid;GetWindowThreadProcessId(GetForegroundWindow(),out foregroundPid);
  if(IsIconic(game)||(foregroundPid!=gamePid&&foregroundPid!=appPid)){if(IsWindowVisible(panel))ShowWindow(panel,0);return 0;}
  if(IsIconic(panel))return 2;
  RECT g,p;if(!Client(game,out g)||!GetWindowRect(panel,out p))return 0;
  int w=p.Right-p.Left,h=p.Bottom-p.Top;PreferredHeight=Math.Max(PreferredHeight,h);int desired=Math.Min(PreferredHeight,Math.Max(520,g.Bottom-g.Top-24));
  int x=AnchorX<0?g.Right-w-12:g.Left+AnchorX,y=g.Top+AnchorY;
  x=Math.Max(g.Left+8,Math.Min(x,g.Right-w-8));y=Math.Max(g.Top+8,Math.Min(y,g.Bottom-desired-8));
  if(!IsWindowVisible(panel)||p.Left!=x||p.Top!=y||h!=desired){SetWindowPos(panel,new IntPtr(-1),x,y,w,desired,0x0010|0x0040);}else SetWindowPos(panel,new IntPtr(-1),0,0,0,0,0x0001|0x0002|0x0010);
  return 1;
 }
 public static void Release(IntPtr panel){SetWindowPos(panel,new IntPtr(-2),0,0,0,0,0x0001|0x0002|0x0010);}
}
