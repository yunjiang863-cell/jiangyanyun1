using System;using System.Diagnostics;using System.Runtime.InteropServices;using System.Text;
public sealed class PWStatsSample {public string TimeUtc,Name;public int HpA,MpA,HpB,MpB;public bool NameVerified;}
public sealed class PWStatsReader:IDisposable {
 [DllImport("kernel32.dll",SetLastError=true)]static extern IntPtr OpenProcess(uint access,bool inherit,int pid);
 [DllImport("kernel32.dll")]static extern bool CloseHandle(IntPtr h);
 [DllImport("kernel32.dll")]static extern bool GetProcessTimes(IntPtr h,out long c,out long e,out long k,out long u);
 [DllImport("kernel32.dll")]static extern bool ReadProcessMemory(IntPtr h,IntPtr address,byte[] bytes,UIntPtr count,out UIntPtr read);
 IntPtr handle=IntPtr.Zero;long ticks,pointer,nameAddress,hpA,mpA,hpB,mpB;string name;bool disposed;
 public static void ValidateLayout(long pointer,long nameAddress,long[] hp,long[] mp){
  if(hp==null||mp==null||hp.Length!=2||mp.Length!=2)throw new ArgumentException("当前仅支持两组生命/真气候选。");
  foreach(long a in new long[]{pointer,nameAddress,hp[0],hp[1],mp[0],mp[1]})if(a<65536||a>0x7ffefff0L)throw new ArgumentException("地址超出支持范围。");
  if(hp[0]>=hp[1]||hp[0]%4!=0||hp[1]%4!=0||mp[0]!=hp[0]+4||mp[1]!=hp[1]+4||hp[1]-hp[0]>4096)throw new ArgumentException("候选字段没有形成两个相邻且有序的生命/真气对。");
 }
 public static bool ExactName(byte[] b,string name){byte[] expected=Encoding.Unicode.GetBytes(name);if(b==null||b.Length!=expected.Length)return false;for(int i=0;i<b.Length;i++)if(b[i]!=expected[i])return false;return true;}
 public static PWStatsReader Open(int pid,long startTicks,string roleName,long namePointer,long expectedName,long[] hp,long[] mp){return new PWStatsReader(pid,startTicks,roleName,namePointer,expectedName,hp,mp);}
 public PWStatsReader(int pid,long startTicks,string roleName,long namePointer,long expectedName,long[] hp,long[] mp){
  ValidateLayout(namePointer,expectedName,hp,mp);if(String.IsNullOrWhiteSpace(roleName)||roleName.Length>32)throw new ArgumentException("角色名无效。");
  ticks=startTicks;pointer=namePointer;nameAddress=expectedName;name=roleName;hpA=hp[0];hpB=hp[1];mpA=mp[0];mpB=mp[1];
  using(Process p=Process.GetProcessById(pid)){if(!String.Equals(p.ProcessName,"elementclient",StringComparison.OrdinalIgnoreCase)||p.StartTime.ToUniversalTime().Ticks!=ticks)throw new InvalidOperationException("报告对应游戏已退出或重启，请重新做前两步诊断。");}
  handle=OpenProcess(0x0410,false,pid);if(handle==IntPtr.Zero)throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(),"无法只读打开游戏。");
  try{ValidateProcess();Read();}catch{Dispose();throw;}
 }
 void ValidateProcess(){if(disposed||handle==IntPtr.Zero)throw new ObjectDisposedException("PWStatsReader");long c,e,k,u;if(!GetProcessTimes(handle,out c,out e,out k,out u)||DateTime.FromFileTimeUtc(c).Ticks!=ticks||e!=0)throw new InvalidOperationException("游戏进程已退出或变化，停止读取。");}
 byte[] ReadBytes(long address,int count){byte[] b=new byte[count];UIntPtr got;if(!ReadProcessMemory(handle,new IntPtr(address),b,new UIntPtr((uint)count),out got)||got.ToUInt64()!=(ulong)count)throw new InvalidOperationException("候选地址无法读取或已失效。");return b;}
 public PWStatsSample Read(){
  ValidateProcess();if(BitConverter.ToUInt32(ReadBytes(pointer,4),0)!=(uint)nameAddress)throw new InvalidOperationException("名字指针已变化，停止使用旧候选。");
  if(!ExactName(ReadBytes(nameAddress,Encoding.Unicode.GetByteCount(name)),name))throw new InvalidOperationException("角色名字已变化或候选失效。");
  int a=BitConverter.ToInt32(ReadBytes(hpA,4),0),b=BitConverter.ToInt32(ReadBytes(mpA,4),0),c=BitConverter.ToInt32(ReadBytes(hpB,4),0),d=BitConverter.ToInt32(ReadBytes(mpB,4),0);
  foreach(int n in new int[]{a,b,c,d})if(n<0||n>1000000000)throw new InvalidOperationException("候选字段超出合理数值范围。");
  return new PWStatsSample{TimeUtc=DateTime.UtcNow.ToString("o"),Name=name,HpA=a,MpA=b,HpB=c,MpB=d,NameVerified=true};
 }
 public void Dispose(){if(!disposed){disposed=true;if(handle!=IntPtr.Zero){CloseHandle(handle);handle=IntPtr.Zero;}}GC.SuppressFinalize(this);}
 ~PWStatsReader(){Dispose();}
}
