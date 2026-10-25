$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'MemoryProbe.cs')
[Windows.Forms.Application]::EnableVisualStyles()
$script:Job=$null
$form=New-Object Windows.Forms.Form;$form.Text='完美角色读取诊断 v0.1 · 只读';$form.Size=New-Object Drawing.Size(900,650);$form.MinimumSize=$form.Size;$form.StartPosition='CenterScreen'
function Label($Text,$X,$Y,$W,$H=30){$l=New-Object Windows.Forms.Label;$l.Text=$Text;$l.SetBounds($X,$Y,$W,$H);$form.Controls.Add($l)}
Label '第一步：定位角色名候选。此工具不会写内存、注入、发包或控制游戏。' 15 15 850
Label '候选地址可能来自聊天记录、界面缓存或其他对象；找到名字不等于已找到角色结构。' 15 45 850 35
$games=New-Object Windows.Forms.ComboBox;$games.DropDownStyle='DropDownList';$games.DisplayMember='Title';$games.SetBounds(15,90,640,30);$form.Controls.Add($games)
$refresh=New-Object Windows.Forms.Button;$refresh.Text='刷新游戏';$refresh.SetBounds(675,88,180,32);$form.Controls.Add($refresh)
Label '测试角色的准确名字' 15 140 240
$name=New-Object Windows.Forms.TextBox;$name.SetBounds(260,135,360,30);$form.Controls.Add($name)
$start=New-Object Windows.Forms.Button;$start.Text='开始只读诊断';$start.SetBounds(15,185,180,35);$form.Controls.Add($start)
$cancel=New-Object Windows.Forms.Button;$cancel.Text='取消';$cancel.SetBounds(210,185,140,35);$form.Controls.Add($cancel)
$save=New-Object Windows.Forms.Button;$save.Text='另存诊断报告';$save.SetBounds(365,185,180,35);$save.Enabled=$false;$form.Controls.Add($save)
$status=New-Object Windows.Forms.Label;$status.SetBounds(15,235,850,55);$status.Text='请进入游戏角色，选择正确的进程，再输入准确角色名。';$form.Controls.Add($status)
$list=New-Object Windows.Forms.ListBox;$list.SetBounds(15,300,840,230);$form.Controls.Add($list)
Label '报告只含进程版本、名字候选地址与扫描统计，不保存原始内存。扫描最多30秒、512MB；结果可能不完整。' 15 545 850 50
function Refresh-Games {
 $games.Items.Clear()
 foreach($p in Get-Process -Name elementclient -ErrorAction SilentlyContinue){try{$x=[pscustomobject]@{Title=([string]$p.Id+' | '+$p.MainWindowTitle);PidValue=$p.Id};[void]$games.Items.Add($x)}catch{}}
 if($games.Items.Count){$games.SelectedIndex=0}
}
$refresh.Add_Click({Refresh-Games})
$start.Add_Click({try{
 if($null -eq $games.SelectedItem){throw '请先启动游戏并刷新。'}
 if($script:Job -and $script:Job.GetReport().State -in @('准备中','扫描中')){throw '当前诊断尚未结束。'}
 $script:Job=[PWReadOnlyProbe]::Start($games.SelectedItem.PidValue,$name.Text)
 $list.Items.Clear();$save.Enabled=$false;$start.Enabled=$false;$refresh.Enabled=$false;$games.Enabled=$false;$name.Enabled=$false
}catch{[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'无法开始')}})
$cancel.Add_Click({if($script:Job){$script:Job.Cancel()}})
$timer=New-Object Windows.Forms.Timer;$timer.Interval=250
$timer.Add_Tick({if(-not $script:Job){return};$r=$script:Job.GetReport();$status.Text=($r.State+'；读取 '+[Math]::Round($r.BytesRead/1MB,1)+' MB；区域 '+$r.Regions+'；候选 '+$r.NameCandidates.Count+[Environment]::NewLine+$r.Error+$r.CompletedReason)
 if($list.Items.Count -ne $r.NameCandidates.Count){$list.Items.Clear();foreach($a in $r.NameCandidates){[void]$list.Items.Add(('0x{0:X8}  角色名候选，未确认角色对象' -f $a))}}
 if($r.State -notin @('准备中','扫描中')){$start.Enabled=$true;$refresh.Enabled=$true;$games.Enabled=$true;$name.Enabled=$true;$save.Enabled=$true}
})
$save.Add_Click({$d=New-Object Windows.Forms.SaveFileDialog;$d.Filter='诊断JSON|*.json';$d.FileName='role-read-report.json';try{if($d.ShowDialog() -eq 'OK'){
 if([IO.File]::Exists($d.FileName)){throw '请另选一个未使用的文件名。'}
 $report=$script:Job.GetReport();$text=$report|ConvertTo-Json -Depth 5
 $bytes=[Text.Encoding]::UTF8.GetBytes($text);$f=[IO.File]::Open($d.FileName,[IO.FileMode]::CreateNew);try{$f.Write($bytes,0,$bytes.Length)}finally{$f.Dispose()}
 [void][Windows.Forms.MessageBox]::Show('已另存报告。该文件包含角色名与进程信息，请只发给你信任的分析者。','已保存')
}}catch{[void][Windows.Forms.MessageBox]::Show($_.Exception.Message)}finally{$d.Dispose()}})
$form.Add_FormClosing({if($script:Job){$script:Job.Cancel()};$timer.Stop()})
try{Refresh-Games;$timer.Start();[void]$form.ShowDialog()}finally{$timer.Dispose();$form.Dispose()}
