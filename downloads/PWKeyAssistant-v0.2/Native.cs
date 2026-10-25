using System;
using System.Runtime.InteropServices;
public static class PWKeyNative {
 [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT {public ushort wVk;public ushort wScan;public uint dwFlags;public uint time;public UIntPtr dwExtraInfo;}
 [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT {public int dx;public int dy;public uint mouseData;public uint dwFlags;public uint time;public UIntPtr dwExtraInfo;}
 [StructLayout(LayoutKind.Explicit)] public struct UNION {[FieldOffset(0)]public KEYBDINPUT ki;[FieldOffset(0)]public MOUSEINPUT mi;}
 [StructLayout(LayoutKind.Sequential)] public struct INPUT {public uint type;public UNION u;}
 [DllImport("user32.dll",SetLastError=true)] static extern uint SendInput(uint n,INPUT[] input,int cb);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int cmd);
 [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
 [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int key);
 public static bool IsF9Down(){return (GetAsyncKeyState(0x78)&0x8000)!=0;}
 public static bool Tap(IntPtr window,uint pid,ushort vk){
  uint owner;GetWindowThreadProcessId(window,out owner);
  if(owner!=pid||!IsWindow(window)||IsIconic(window)||GetForegroundWindow()!=window||IsF9Down())return false;
  INPUT down=new INPUT();down.type=1;down.u.ki.wVk=vk;
  INPUT up=down;up.u.ki.dwFlags=2;
  uint sent=SendInput(2,new INPUT[]{down,up},Marshal.SizeOf(typeof(INPUT)));
  if(sent!=2){SendInput(1,new INPUT[]{up},Marshal.SizeOf(typeof(INPUT)));return false;}
  return true;
 }
 public static int InputSize(){return Marshal.SizeOf(typeof(INPUT));}
}
