using System;using System.Collections.Generic;using System.IO;using System.Security.Cryptography;using System.Threading;using System.Diagnostics;using System.Runtime.InteropServices;using System.Text;
public sealed class PWStatsSample {public string TimeUtc,Name;public int HpA,MpA,HpB,MpB;public bool NameVerified;}
public sealed class PWStatsReader:IDisposable {
 [DllImport("kernel32.dll",SetLastError=true)]static extern IntPtr OpenProcess(uint access,bool inherit,int pid);
 [DllImport("kernel32.dll")]static extern bool CloseHandle(IntPtr h);
 [DllImport("kernel32.dll")]static extern bool GetProcessTimes(IntPtr h,out long c,out long e,out long k,out long u);
 [DllImport("kernel32.dll",SetLastError=true)]static extern bool ReadProcessMemory(IntPtr h,IntPtr address,byte[] bytes,UIntPtr count,out UIntPtr read);
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
  using(Process p=Process.GetProcessById(pid)){if(!String.Equals(p.ProcessName,"elementclient",StringComparison.OrdinalIgnoreCase)||p.StartTime.ToUniversalTime().Ticks!=ticks)throw new InvalidOperationException("游戏进程已变化，请重新点击连接角色。");}
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

public sealed class PWAutoRoleInfo {
 public int ProcessId;public long StartTicks,NamePointer,NameAddress;public string Name,Sha256;public long[] HpAddresses,MpAddresses;
}
public sealed class PWAutoRoleProgress {public string State="准备中",Error="";public long BytesRead;public PWAutoRoleInfo Result;}
public sealed class PWAutoRoleJob {
 internal volatile bool Cancelled;internal object Sync=new object();internal PWAutoRoleProgress Data=new PWAutoRoleProgress();public void Cancel(){Cancelled=true;}
 public PWAutoRoleProgress GetProgress(){lock(Sync){return new PWAutoRoleProgress{State=Data.State,Error=Data.Error,BytesRead=Data.BytesRead,Result=Data.Result};}}
}
public static class PWAutoRoleConnector {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern bool QueryFullProcessImageName(IntPtr handle,uint flags,StringBuilder path,ref int size);
 [StructLayout(LayoutKind.Sequential)]struct MBI{public IntPtr Base,AllocationBase;public uint AllocationProtect;public UIntPtr Size;public uint State,Protect,Type;}
 [DllImport("kernel32.dll",SetLastError=true)]static extern IntPtr OpenProcess(uint access,bool inherit,int pid);
 [DllImport("kernel32.dll")]static extern bool CloseHandle(IntPtr h);
 [DllImport("kernel32.dll")]static extern bool GetProcessTimes(IntPtr h,out long c,out long e,out long k,out long u);
 [DllImport("kernel32.dll")]static extern UIntPtr VirtualQueryEx(IntPtr h,IntPtr address,out MBI info,UIntPtr size);
 [DllImport("kernel32.dll",SetLastError=true)]static extern bool ReadProcessMemory(IntPtr h,IntPtr address,byte[] bytes,UIntPtr size,out UIntPtr read);
 const string SupportedHash="2f7f098806d965fea21d4206a201868d3e897b3dfd91c97caf93b28e91df1b3f";
 // Client-version profile derived from supplied reports; no private names, PIDs or heap addresses.
 const long NameRootRva=0x642230;const int HpRelative=-424,MpRelative=-420,MaxHpRelative=-360,MaxMpRelative=-356;
 public static long PreferredBase(string fileName){
  using(BinaryReader r=new BinaryReader(File.OpenRead(fileName))){
   if(r.BaseStream.Length<256||r.ReadUInt16()!=0x5a4d)throw new InvalidOperationException("游戏PE文件头无效。");
   r.BaseStream.Position=0x3c;int pe=r.ReadInt32();if(pe<64||pe>r.BaseStream.Length-128)throw new InvalidOperationException("PE头位置无效。");
   r.BaseStream.Position=pe;if(r.ReadUInt32()!=0x4550||r.ReadUInt16()!=0x14c)throw new InvalidOperationException("当前仅支持32位客户端。");
   long opt=pe+24;r.BaseStream.Position=opt;if(r.ReadUInt16()!=0x10b)throw new InvalidOperationException("客户端不是PE32格式。");
   r.BaseStream.Position=opt+28;long imageBase=r.ReadUInt32();r.BaseStream.Position=opt+70;ushort flags=r.ReadUInt16();
   if((flags&0x40)!=0)throw new InvalidOperationException("该客户端开启了地址随机化，需要独立适配，未猜测加载地址。");
   if(imageBase<65536||imageBase>=0x7fff0000L)throw new InvalidOperationException("客户端映像地址无效。");return imageBase;
  }
 }
 public static bool PlausibleStats(int hp,int mp,int maxHp,int maxMp){return hp>=0&&mp>=0&&maxHp>0&&maxMp>0&&maxHp<=1000000000&&maxMp<=1000000000&&hp<=maxHp&&mp<=maxMp;}
 public static PWAutoRoleJob Start(int pid){if(pid<=0)throw new ArgumentException("游戏进程无效。");PWAutoRoleJob job=new PWAutoRoleJob();Thread t=new Thread(delegate(){Locate(job,pid);});t.IsBackground=true;t.Start();return job;}
 static byte[] Read(IntPtr h,long a,int size,out int got){byte[] b=new byte[size];UIntPtr n;ReadProcessMemory(h,new IntPtr(a),b,new UIntPtr((uint)size),out n);got=(int)Math.Min((ulong)size,n.ToUInt64());return b;}
 static int ReadInt(IntPtr h,long a){int n;byte[] b=Read(h,a,4,out n);if(n!=4)throw new InvalidOperationException("角色字段无法读取：0x"+a.ToString("X")+"，需要4字节，实际"+n+"，Windows错误"+Marshal.GetLastWin32Error()+"。");return BitConverter.ToInt32(b,0);}
 static string ReadName(IntPtr h,long a){StringBuilder s=new StringBuilder();for(int i=0;i<=32;i++){int n;byte[] b=Read(h,a+i*2,2,out n);if(n!=2)throw new InvalidOperationException("名字无法读取。");char c=(char)BitConverter.ToUInt16(b,0);if(c==0){if(s.Length<2)throw new InvalidOperationException("请先进入游戏角色。");return s.ToString();}if(Char.IsControl(c))throw new InvalidOperationException("名字字段与适配版本不符。");s.Append(c);}throw new InvalidOperationException("名字字段未通过长度校验。");}
 public static int[] FindName(byte[] b,int n,byte[] p){int[] skip=new int[256];for(int i=0;i<256;i++)skip[i]=p.Length;for(int i=0;i<p.Length-1;i++)skip[p[i]]=p.Length-1-i;List<int> hits=new List<int>();for(int i=0;i<=n-p.Length;){int j=p.Length-1;while(j>=0&&b[i+j]==p[j])j--;if(j<0){hits.Add(i);i++;}else i+=skip[b[i+p.Length-1]];}return hits.ToArray();}
 static void Walk(IntPtr handle,PWAutoRoleJob job,Action<long,byte[],int> visit){long cursor=65536,total=0;Stopwatch clock=Stopwatch.StartNew();while(cursor<0x7fff0000L){
  if(job.Cancelled)throw new OperationCanceledException();if(clock.ElapsedMilliseconds>30000||total>=536870912)break;
  MBI info;if(VirtualQueryEx(handle,new IntPtr(cursor),out info,new UIntPtr((uint)Marshal.SizeOf(typeof(MBI))))==UIntPtr.Zero)break;
  long size=(long)info.Size.ToUInt64(),begin=info.Base.ToInt64(),end=Math.Min(begin+size,0x7fff0000L);if(size<=0||end<=cursor)break;uint p=info.Protect&0xff;
  if(info.State==0x1000&&(info.Protect&0x100)==0&&(p==2||p==4||p==8||p==0x20||p==0x40||p==0x80)){
   for(long a=Math.Max(cursor,begin);a<end;){if(job.Cancelled)throw new OperationCanceledException();if(clock.ElapsedMilliseconds>30000||total>=536870912)break;int sizeRead=(int)Math.Min(262144,Math.Min(end-a,536870912-total)),n;byte[] b=Read(handle,a,sizeRead,out n);total+=sizeRead;visit(a,b,n);a+=sizeRead;lock(job.Sync)job.Data.BytesRead+=n;}
  }cursor=end;
 }}
 static void Locate(PWAutoRoleJob job,int pid){IntPtr handle=IntPtr.Zero;try{
  lock(job.Sync)job.Data.State="打开只读连接";
  handle=OpenProcess(0x0410,false,pid);if(handle==IntPtr.Zero)throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(),"无法只读连接游戏。");
  long c,e,k,u;if(!GetProcessTimes(handle,out c,out e,out k,out u)||e!=0)throw new InvalidOperationException("游戏进程已退出或无法读取启动时间。");long ticks=DateTime.FromFileTimeUtc(c).Ticks;
  lock(job.Sync)job.Data.State="校验游戏版本";
  StringBuilder path=new StringBuilder(32768);int capacity=path.Capacity;if(!QueryFullProcessImageName(handle,0,path,ref capacity))throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(),"无法读取游戏文件路径。");
  string fileName=path.ToString();if(!String.Equals(Path.GetFileName(fileName),"elementclient.exe",StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("只支持elementclient.exe。");
  string hash;using(FileStream f=File.OpenRead(fileName))using(SHA256 sha=SHA256.Create())hash=BitConverter.ToString(sha.ComputeHash(f)).Replace("-","").ToLowerInvariant();
  if(hash!=SupportedHash)throw new InvalidOperationException("当前主程序版本不在已适配范围，未读取其他版本。");
  long imageBase=PreferredBase(fileName);
  lock(job.Sync)job.Data.State="读取角色名字入口";
  long root=imageBase+NameRootRva;uint namePointer=unchecked((uint)ReadInt(handle,root));if(namePointer<65536||namePointer>0x7ffeff00)throw new InvalidOperationException("角色名字入口尚未就绪，请先进入游戏。");
  string name=ReadName(handle,namePointer);byte[] pattern=Encoding.Unicode.GetBytes(name);List<long> names=new List<long>();names.Add(namePointer);
  lock(job.Sync)job.Data.State="自动定位角色名字";
  byte[] tail=new byte[0];long next=-1;
  Walk(handle,job,delegate(long a,byte[] b,int n){if(a!=next)tail=new byte[0];if(n==0){tail=new byte[0];next=-1;return;}byte[] joined=new byte[tail.Length+n];Buffer.BlockCopy(tail,0,joined,0,tail.Length);Buffer.BlockCopy(b,0,joined,tail.Length,n);foreach(int off in FindName(joined,joined.Length,pattern)){long at=a-tail.Length+off;if(at+pattern.Length<=a)continue;if(!names.Contains(at)){if(names.Count>=64)throw new InvalidOperationException("角色名候选过多，无法唯一连接。");names.Add(at);}}int keep=Math.Min(pattern.Length-1,joined.Length);tail=new byte[keep];Buffer.BlockCopy(joined,joined.Length-keep,tail,0,keep);next=n==b.Length?a+n:-1;});
  Dictionary<uint,bool> wanted=new Dictionary<uint,bool>();foreach(long a in names)wanted[(uint)a]=true;List<PWAutoRoleInfo> matches=new List<PWAutoRoleInfo>();lock(job.Sync)job.Data.State="自动定位生命与真气";
  Walk(handle,job,delegate(long a,byte[] b,int n){int align=(int)((4-(a&3))&3);for(int i=align;i+4<=n;i+=4){uint value=BitConverter.ToUInt32(b,i);if(!wanted.ContainsKey(value))continue;long field=a+i;if(field<65536-HpRelative)continue;
   try{int hp=ReadInt(handle,field+HpRelative),mp=ReadInt(handle,field+MpRelative),maxHp=ReadInt(handle,field+MaxHpRelative),maxMp=ReadInt(handle,field+MaxMpRelative);if(!PlausibleStats(hp,mp,maxHp,maxMp))continue;int read;byte[] exact=Read(handle,value,pattern.Length,out read);if(read!=pattern.Length||!PWStatsReader.ExactName(exact,name))continue;
    matches.Add(new PWAutoRoleInfo{ProcessId=pid,StartTicks=ticks,Name=name,Sha256=hash,NamePointer=field,NameAddress=value,HpAddresses=new long[]{field+HpRelative,field+MaxHpRelative},MpAddresses=new long[]{field+MpRelative,field+MaxMpRelative}});
   }catch(InvalidOperationException){}
   if(matches.Count>1)throw new InvalidOperationException("出现多个符合结构的角色对象，未自动选择。");
  }});
  if(matches.Count!=1)throw new InvalidOperationException("未找到唯一角色数据。自动扫描有30秒/512MB分阶段上限，未使用猜测地址。");
  var result=matches[0];using(PWStatsReader reader=PWStatsReader.Open(pid,ticks,name,result.NamePointer,result.NameAddress,result.HpAddresses,result.MpAddresses)){var sample=reader.Read();if(!PlausibleStats(sample.HpA,sample.MpA,sample.HpB,sample.MpB))throw new InvalidOperationException("角色数据在连接过程中发生变化。");}
  lock(job.Sync){job.Data.Result=result;job.Data.State="已连接";}
 }catch(OperationCanceledException){lock(job.Sync)job.Data.State="已取消";}catch(Exception ex){lock(job.Sync){string stage=job.Data.State;job.Data.State="失败";job.Data.Error="步骤："+stage+"；"+ex.Message;}}finally{if(handle!=IntPtr.Zero)CloseHandle(handle);}}
}
