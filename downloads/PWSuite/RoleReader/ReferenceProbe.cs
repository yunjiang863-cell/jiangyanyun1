using System;using System.Collections.Generic;using System.Diagnostics;using System.Runtime.InteropServices;using System.Text;using System.Threading;
public sealed class PWRoleReference {public long Address,NameAddress;public long ImageRva=-1;public long[] HpValueMatches=new long[0],MpValueMatches=new long[0];public int Score;}
public sealed class PWReferenceReport {public string State="准备中",Error="",Name="",CompletedReason="";public int ProcessId,KnownMaxHp,KnownMaxMp;public long ProcessStartTicks,BytesRead;public long[] ValidNameCandidates=new long[0];public PWRoleReference[] References=new PWRoleReference[0];}
public sealed class PWReferenceJob {
 internal volatile bool Cancelled;internal object Sync=new object();internal PWReferenceReport Data=new PWReferenceReport();
 public void Cancel(){Cancelled=true;}
 public PWReferenceReport GetReport(){lock(Sync){var a=Data;return new PWReferenceReport{State=a.State,Error=a.Error,Name=a.Name,CompletedReason=a.CompletedReason,ProcessId=a.ProcessId,KnownMaxHp=a.KnownMaxHp,KnownMaxMp=a.KnownMaxMp,ProcessStartTicks=a.ProcessStartTicks,BytesRead=a.BytesRead,ValidNameCandidates=(long[])a.ValidNameCandidates.Clone(),References=(PWRoleReference[])a.References.Clone()};}}
}
public static class PWRoleReferenceProbe {
 [StructLayout(LayoutKind.Sequential)]struct MBI{public IntPtr Base,AllocationBase;public uint AllocationProtect;public UIntPtr Size;public uint State,Protect,Type;}
 [DllImport("kernel32.dll",SetLastError=true)]static extern IntPtr OpenProcess(uint access,bool inherit,int pid);
 [DllImport("kernel32.dll")]static extern bool CloseHandle(IntPtr h);
 [DllImport("kernel32.dll")]static extern bool GetProcessTimes(IntPtr h,out long c,out long e,out long k,out long u);
 [DllImport("kernel32.dll")]static extern UIntPtr VirtualQueryEx(IntPtr h,IntPtr address,out MBI info,UIntPtr size);
 [DllImport("kernel32.dll")]static extern bool ReadProcessMemory(IntPtr h,IntPtr address,byte[] bytes,UIntPtr size,out UIntPtr read);
 public static long[] ValueMatches(byte[] bytes,int n,long start,int value){List<long> a=new List<long>();int initial=(int)((4-(start&3))&3);for(int i=initial;i+4<=n;i+=4){if(BitConverter.ToInt32(bytes,i)==value){a.Add(start+i);if(a.Count>=16)break;}}return a.ToArray();}
 public static bool ExactName(byte[] bytes,int n,string name){byte[] p=Encoding.Unicode.GetBytes(name);if(n!=p.Length||bytes.Length<n)return false;for(int i=0;i<n;i++)if(bytes[i]!=p[i])return false;return true;}
 public static PWReferenceJob Start(int pid,long ticks,string name,long[] candidates,int hp,int mp){
  if(pid<=0||ticks<=0||String.IsNullOrWhiteSpace(name)||name.Length>32||candidates==null||candidates.Length==0||candidates.Length>32||hp<=0||mp<=0||hp>1000000000||mp>1000000000)throw new ArgumentException("报告或生命/真气数字无效。");
  long[] names=(long[])candidates.Clone();foreach(long a in names)if(a<65536||a>0x7fff0000L)throw new ArgumentException("名字候选不在支持的32位地址范围。");
  PWReferenceJob job=new PWReferenceJob();job.Data.ProcessId=pid;job.Data.ProcessStartTicks=ticks;job.Data.Name=name;job.Data.KnownMaxHp=hp;job.Data.KnownMaxMp=mp;
  Thread thread=new Thread(delegate(){Scan(job,names);});thread.IsBackground=true;thread.Start();return job;
 }
 static byte[] Read(IntPtr handle,long address,int count,out int n){byte[] b=new byte[count];UIntPtr read;ReadProcessMemory(handle,new IntPtr(address),b,new UIntPtr((uint)count),out read);n=(int)Math.Min((ulong)count,read.ToUInt64());return b;}
 static void Scan(PWReferenceJob job,long[] candidates){IntPtr handle=IntPtr.Zero;try{
  var d=job.Data;long imageBase,imageEnd;using(Process p=Process.GetProcessById(d.ProcessId)){if(!String.Equals(p.ProcessName,"elementclient",StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("只支持elementclient.exe测试进程。");if(p.StartTime.ToUniversalTime().Ticks!=d.ProcessStartTicks)throw new InvalidOperationException("游戏已重启，旧地址无效，请重新运行第一步诊断。");imageBase=p.MainModule.BaseAddress.ToInt64();imageEnd=imageBase+p.MainModule.ModuleMemorySize;}
  handle=OpenProcess(0x0410,false,d.ProcessId);if(handle==IntPtr.Zero)throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(),"无法只读访问游戏。");
  long c,e,k,u;if(!GetProcessTimes(handle,out c,out e,out k,out u)||DateTime.FromFileTimeUtc(c).Ticks!=d.ProcessStartTicks)throw new InvalidOperationException("游戏进程已变化。");
  Dictionary<uint,long> valid=new Dictionary<uint,long>();foreach(long a in candidates){int n;byte[] b=Read(handle,a,Encoding.Unicode.GetByteCount(d.Name),out n);if(ExactName(b,n,d.Name))valid[(uint)a]=a;}
  if(valid.Count==0)throw new InvalidOperationException("旧候选已失效或名字不匹配，请先重新生成第一步报告。");
  long[] validNames=new long[valid.Count];valid.Values.CopyTo(validNames,0);lock(job.Sync){d.ValidNameCandidates=validNames;d.State="扫描中";}
  List<PWRoleReference> refs=new List<PWRoleReference>();long cursor=65536,total=0,requested=0;const long limit=536870912;Stopwatch timer=Stopwatch.StartNew();string reason="地址范围结束";
  while(cursor<0x7fff0000L){
   if(job.Cancelled){reason="用户取消";break;}if(timer.ElapsedMilliseconds>30000){reason="达到30秒限制，扫描不完整";break;}if(requested>=limit){reason="达到512MB限制，扫描不完整";break;}if(refs.Count>=256){reason="达到256个指针引用限制，扫描不完整";break;}
   MBI info;if(VirtualQueryEx(handle,new IntPtr(cursor),out info,new UIntPtr((uint)Marshal.SizeOf(typeof(MBI))))==UIntPtr.Zero){reason="查询结束或被拒绝，扫描可能不完整";break;}
   long start=info.Base.ToInt64(),size=(long)info.Size.ToUInt64(),end=Math.Min(start+size,0x7fff0000L);if(size<=0||end<=cursor)throw new InvalidOperationException("区域范围无效。");uint protection=info.Protect&0xff;
   if(info.State==0x1000&&(info.Protect&0x100)==0&&(protection==2||protection==4||protection==8||protection==0x20||protection==0x40||protection==0x80)){
    for(long address=Math.Max(start,cursor);address<end;){
     if(job.Cancelled||timer.ElapsedMilliseconds>30000||requested>=limit||refs.Count>=256)break;
     int want=(int)Math.Min(262144,Math.Min(end-address,limit-requested)),n;byte[] bytes=Read(handle,address,want,out n);total+=n;requested+=want;
     int initial=(int)((4-(address&3))&3);
     for(int i=initial;i+4<=n;i+=4){uint value=BitConverter.ToUInt32(bytes,i);long nameAddress;if(!valid.TryGetValue(value,out nameAddress))continue;
      long storage=address+i,contextStart=Math.Max(start,storage-4096);int contextSize=(int)(Math.Min(end,storage+1024)-contextStart),got;
      byte[] context=Read(handle,contextStart,contextSize,out got);
      var item=new PWRoleReference{Address=storage,NameAddress=nameAddress,ImageRva=(storage>=imageBase&&storage<imageEnd)?storage-imageBase:-1,HpValueMatches=ValueMatches(context,got,contextStart,d.KnownMaxHp),MpValueMatches=ValueMatches(context,got,contextStart,d.KnownMaxMp)};
      item.Score=(item.HpValueMatches.Length>0?1:0)+(item.MpValueMatches.Length>0?1:0);refs.Add(item);if(refs.Count>=256)break;
     }
     address+=want;lock(job.Sync){d.BytesRead=total;d.References=refs.ToArray();}
    }
   }
   cursor=end;
  }
  lock(job.Sync){d.State=job.Cancelled?"已取消":"已完成";d.CompletedReason=reason;}
 }catch(Exception ex){lock(job.Sync){job.Data.State="失败";job.Data.Error=ex.Message;}}finally{if(handle!=IntPtr.Zero)CloseHandle(handle);}}
}
