using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
public sealed class PWReadReport {
 public string State="准备中", Error="", Name="", Executable="", Sha256="";
 public int ProcessId; public long ProcessStartTicks, ImageBase, BytesRead, BytesRequested; public int Regions;
 public long[] NameCandidates=new long[0]; public string CompletedReason="";
}
public sealed class PWReadJob {
 internal volatile bool Cancelled; internal readonly object Sync=new object();internal PWReadReport Report=new PWReadReport();
 public void Cancel(){Cancelled=true;}
 public PWReadReport GetReport(){lock(Sync){var a=Report;return new PWReadReport{State=a.State,Error=a.Error,Name=a.Name,Executable=a.Executable,Sha256=a.Sha256,ProcessId=a.ProcessId,ProcessStartTicks=a.ProcessStartTicks,ImageBase=a.ImageBase,BytesRead=a.BytesRead,BytesRequested=a.BytesRequested,Regions=a.Regions,NameCandidates=(long[])a.NameCandidates.Clone(),CompletedReason=a.CompletedReason};}}
}
public static class PWReadOnlyProbe {
 [StructLayout(LayoutKind.Sequential)] public struct MBI {public IntPtr BaseAddress,AllocationBase;public uint AllocationProtect;public UIntPtr RegionSize;public uint State,Protect,Type;}
 [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr OpenProcess(uint access,bool inherit,int pid);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool CloseHandle(IntPtr process);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetProcessTimes(IntPtr process,out long created,out long exited,out long kernel,out long user);
 [DllImport("kernel32.dll",SetLastError=true)] static extern UIntPtr VirtualQueryEx(IntPtr process,IntPtr address,out MBI info,UIntPtr size);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool ReadProcessMemory(IntPtr process,IntPtr address,byte[] buffer,UIntPtr size,out UIntPtr read);
 public static int MbiSize(){return Marshal.SizeOf(typeof(MBI));}
 // Testable byte matcher. It returns matches without modifying or executing target data.
 public static int[] Find(byte[] buffer,int count,byte[] pattern){
  if(buffer==null||pattern==null||pattern.Length==0||count<0||count>buffer.Length)throw new ArgumentException();
  int[] skip=new int[256];for(int k=0;k<256;k++)skip[k]=pattern.Length;
  for(int k=0;k<pattern.Length-1;k++)skip[pattern[k]]=pattern.Length-1-k;
  List<int> hits=new List<int>();int i=0;
  while(i<=count-pattern.Length){int j=pattern.Length-1;while(j>=0&&buffer[i+j]==pattern[j])j--;if(j<0){hits.Add(i);i++;}else i+=skip[buffer[i+pattern.Length-1]];}
  return hits.ToArray();
 }
 public static PWReadJob Start(int pid,string name){
  if(String.IsNullOrWhiteSpace(name)||name.Length<2||name.Length>32||name.IndexOf('\0')>=0)throw new ArgumentException("角色名应为2到32个字符。");
  PWReadJob job=new PWReadJob();job.Report.ProcessId=pid;job.Report.Name=name;
  Thread t=new Thread(delegate(){Scan(job);});t.IsBackground=true;t.Start();return job;
 }
 static void Scan(PWReadJob job){IntPtr handle=IntPtr.Zero;
  try{
   int pid=job.Report.ProcessId;byte[] pattern=Encoding.Unicode.GetBytes(job.Report.Name);Process target=Process.GetProcessById(pid);
   try{
    if(!String.Equals(target.ProcessName,"elementclient",StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("只允许读取 elementclient.exe 测试客户端。");
    var module=target.MainModule;
    string sha;using(FileStream file=File.OpenRead(module.FileName))using(SHA256 h=SHA256.Create())sha=BitConverter.ToString(h.ComputeHash(file)).Replace("-","").ToLowerInvariant();
    lock(job.Sync){job.Report.ProcessStartTicks=target.StartTime.ToUniversalTime().Ticks;job.Report.Executable=Path.GetFileName(module.FileName);job.Report.ImageBase=module.BaseAddress.ToInt64();job.Report.Sha256=sha;}
    // Verify a 32-bit PE, as this collector is intentionally scoped to the supplied client generation.
    using(BinaryReader reader=new BinaryReader(File.OpenRead(module.FileName))){if(reader.ReadUInt16()!=0x5a4d)throw new InvalidOperationException("不是PE文件。");reader.BaseStream.Position=0x3c;int off=reader.ReadInt32();reader.BaseStream.Position=off;if(reader.ReadUInt32()!=0x4550||reader.ReadUInt16()!=0x14c)throw new InvalidOperationException("当前诊断器只适配32位客户端。");}
   }finally{target.Dispose();}
   handle=OpenProcess(0x0410,false,pid); // QUERY_INFORMATION | VM_READ. No write, injection or debug privilege.
   if(handle==IntPtr.Zero)throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(),"无法只读访问游戏进程。");
   long created,exited,kernel,user;if(!GetProcessTimes(handle,out created,out exited,out kernel,out user)||DateTime.FromFileTimeUtc(created).Ticks!=job.Report.ProcessStartTicks)throw new InvalidOperationException("游戏进程在绑定期间发生变化，请重新诊断。");
   lock(job.Sync)job.Report.State="扫描中";
   const long budget=536870912;const int chunk=262144;long cursor=65536,requested=0,readTotal=0;int regions=0;List<long> hits=new List<long>();Stopwatch clock=Stopwatch.StartNew();string reason="已扫描可访问的32位地址范围";
   while(cursor<0x7fff0000L){
    if(job.Cancelled){reason="用户取消";break;}if(clock.ElapsedMilliseconds>30000){reason="达到30秒时间限制，扫描不完整";break;}if(requested>=budget){reason="达到512MB读取限制，扫描不完整";break;}if(hits.Count>=32){reason="达到32处候选限制，扫描不完整";break;}
    MBI info;if(VirtualQueryEx(handle,new IntPtr(cursor),out info,new UIntPtr((uint)MbiSize()))==UIntPtr.Zero){reason="地址查询结束或被拒绝，扫描可能不完整";break;}
    long start=info.BaseAddress.ToInt64(),size=(long)info.RegionSize.ToUInt64();if(size<=0||start+size<=cursor)throw new InvalidOperationException("内存区域范围无效。");
    long end=Math.Min(start+size,0x7fff0000L);uint p=info.Protect&0xff;
    bool readable=info.State==0x1000&&(info.Protect&0x100)==0&&(p==2||p==4||p==8||p==0x20||p==0x40||p==0x80);
    if(readable){regions++;byte[] tail=new byte[0];
     for(long address=Math.Max(start,cursor);address<end;){
      if(job.Cancelled||clock.ElapsedMilliseconds>30000||requested>=budget||hits.Count>=32)break;
      int want=(int)Math.Min(chunk,Math.Min(end-address,budget-requested));if(want<=0)break;
      byte[] bytes=new byte[want];UIntPtr got;ReadProcessMemory(handle,new IntPtr(address),bytes,new UIntPtr((uint)want),out got);int n=(int)Math.Min((ulong)want,got.ToUInt64());requested+=want;readTotal+=n;
      if(n>0){byte[] joined=new byte[tail.Length+n];Buffer.BlockCopy(tail,0,joined,0,tail.Length);Buffer.BlockCopy(bytes,0,joined,tail.Length,n);
       foreach(int offset in Find(joined,joined.Length,pattern)){long hit=address-tail.Length+offset;if(hit+pattern.Length<=address)continue;if(!hits.Contains(hit))hits.Add(hit);if(hits.Count>=32)break;}
       int keep=Math.Min(pattern.Length-1,joined.Length);tail=new byte[keep];Buffer.BlockCopy(joined,joined.Length-keep,tail,0,keep);
      }else tail=new byte[0];
      // Do not bridge over an unread portion of a memory region.
      if(n<want)tail=new byte[0];address+=want;
      lock(job.Sync){job.Report.BytesRequested=requested;job.Report.BytesRead=readTotal;job.Report.Regions=regions;job.Report.NameCandidates=hits.ToArray();}
     }
    }
    cursor=end;
   }
   lock(job.Sync){job.Report.State=job.Cancelled?"已取消":"已完成";job.Report.CompletedReason=reason;}
  }catch(Exception ex){lock(job.Sync){job.Report.State="失败";job.Report.Error=ex.Message;}}
  finally{if(handle!=IntPtr.Zero)CloseHandle(handle);}
 }
}
