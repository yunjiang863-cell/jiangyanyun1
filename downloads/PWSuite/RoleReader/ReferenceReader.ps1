$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'ReferenceProbe.cs')
[Windows.Forms.Application]::EnableVisualStyles()
$script:Input=$null;$script:Job=$null
$form=New-Object Windows.Forms.Form;$form.Text='角色读取诊断 · 第二步交叉核对';$form.Size=New-Object Drawing.Size(900,660);$form.MinimumSize=$form.Size;$form.StartPosition='CenterScreen'
function Text($s,$x,$y,$w=840,$h=30){$l=New-Object Windows.Forms.Label;$l.Text=$s;$l.SetBounds($x,$y,$w,$h);$form.Controls.Add($l);return $l}
[void](Text '请使用当前仍在运行的同一游戏进程的第一步报告。游戏重启后旧地址不能复用。' 15 15)
$info=Text '尚未载入第一步报告。' 15 55 840 50
$load=New-Object Windows.Forms.Button;$load.Text='载入第一步JSON报告';$load.SetBounds(15,110,210,32);$form.Controls.Add($load)
[void](Text '请让角色在安全位置回满生命与真气，再填写游戏显示的最大值。' 15 155)
[void](Text '最大生命' 15 200 120);$hp=New-Object Windows.Forms.NumericUpDown;$hp.Minimum=1;$hp.Maximum=1000000000;$hp.SetBounds(140,196,220,30);$form.Controls.Add($hp)
[void](Text '最大真气' 440 200 120);$mp=New-Object Windows.Forms.NumericUpDown;$mp.Minimum=1;$mp.Maximum=1000000000;$mp.SetBounds(565,196,220,30);$form.Controls.Add($mp)
$start=New-Object Windows.Forms.Button;$start.Text='开始只读交叉核对';$start.SetBounds(15,245,210,32);$form.Controls.Add($start)
$cancel=New-Object Windows.Forms.Button;$cancel.Text='取消';$cancel.SetBounds(240,245,130,32);$form.Controls.Add($cancel)
$save=New-Object Windows.Forms.Button;$save.Text='另存第二步报告';$save.SetBounds(385,245,210,32);$save.Enabled=$false;$form.Controls.Add($save)
$status=Text '待诊断。匹配生命/真气数字仍不能单独证明是角色结构，不会自动启用挂机。' 15 295 840 50
$list=New-Object Windows.Forms.ListBox;$list.SetBounds(15,355,840,200);$form.Controls.Add($list)
[void](Text '只导出指针地址、已知数值的命中位置和统计，不导出原始内存；请私下发送报告。' 15 575 840 40)
$load.Add_Click({$d=New-Object Windows.Forms.OpenFileDialog;$d.Filter='第一步报告|*.json';try{if($d.ShowDialog() -eq 'OK'){$r=Get-Content -LiteralPath $d.FileName -Raw -Encoding UTF8|ConvertFrom-Json;if($r.Executable -ine 'elementclient.exe' -or $r.Sha256 -ne '2f7f098806d965fea21d4206a201868d3e897b3dfd91c97caf93b28e91df1b3f' -or @($r.NameCandidates).Count -eq 0){throw '报告不是当前支持的游戏版本，或没有名字候选。'};$script:Input=$r;$info.Text='角色：'+$r.Name+'；进程：'+$r.ProcessId+'；名字候选：'+@($r.NameCandidates).Count}}catch{[void][Windows.Forms.MessageBox]::Show($_.Exception.Message)}finally{$d.Dispose()}})
$start.Add_Click({try{if(-not $script:Input){throw '请先载入报告。'};if($script:Job -and $script:Job.GetReport().State -in @('准备中','扫描中')){throw '诊断尚未结束。'};$r=$script:Input;$script:Job=[PWRoleReferenceProbe]::Start([int]$r.ProcessId,[long]$r.ProcessStartTicks,[string]$r.Name,[long[]]$r.NameCandidates,[int]$hp.Value,[int]$mp.Value);$list.Items.Clear();$start.Enabled=$false;$load.Enabled=$false;$hp.Enabled=$false;$mp.Enabled=$false;$save.Enabled=$false}catch{[void][Windows.Forms.MessageBox]::Show($_.Exception.Message)}})
$cancel.Add_Click({if($script:Job){$script:Job.Cancel()}})
$timer=New-Object Windows.Forms.Timer;$timer.Interval=300
$timer.Add_Tick({if(-not $script:Job){return};$r=$script:Job.GetReport();$status.Text=$r.State+'；读取 '+[Math]::Round($r.BytesRead/1MB,1)+'MB；引用 '+$r.References.Count+[Environment]::NewLine+$r.Error+$r.CompletedReason;if($list.Items.Count -ne $r.References.Count){$list.Items.Clear();foreach($item in $r.References|Sort-Object Score -Descending){[void]$list.Items.Add(('引用 0x{0:X8} → 名字 0x{1:X8}；已知生命命中 {2}；真气命中 {3}' -f $item.Address,$item.NameAddress,$item.HpValueMatches.Count,$item.MpValueMatches.Count))}};if($r.State -notin @('准备中','扫描中')){$start.Enabled=$true;$load.Enabled=$true;$hp.Enabled=$true;$mp.Enabled=$true;$save.Enabled=$true}})
$save.Add_Click({$d=New-Object Windows.Forms.SaveFileDialog;$d.Filter='第二步报告|*.json';$d.FileName='role-reference-report.json';try{if($d.ShowDialog() -eq 'OK'){if([IO.File]::Exists($d.FileName)){throw '请使用新的文件名。'};$text=$script:Job.GetReport()|ConvertTo-Json -Depth 8;$b=[Text.Encoding]::UTF8.GetBytes($text);$f=[IO.File]::Open($d.FileName,[IO.FileMode]::CreateNew);try{$f.Write($b,0,$b.Length)}finally{$f.Dispose()}}}catch{[void][Windows.Forms.MessageBox]::Show($_.Exception.Message)}finally{$d.Dispose()}})
$form.Add_FormClosing({if($script:Job){$script:Job.Cancel()};$timer.Stop()})
try{$timer.Start();[void]$form.ShowDialog()}finally{$timer.Dispose();$form.Dispose()}
