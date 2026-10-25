$ErrorActionPreference='Stop'
try {
 . (Join-Path $PSScriptRoot 'Core.ps1')
 Add-Type -AssemblyName System.Windows.Forms
 Add-Type -AssemblyName System.Drawing
 Add-Type -Path (Join-Path $PSScriptRoot 'Native.cs')
} catch {Write-Host $_.Exception.Message;Read-Host '启动失败，按回车关闭';exit 1}
[Windows.Forms.Application]::EnableVisualStyles()
$script:Bound=$null;$script:Running=$false;$script:Schedule=@();$script:NextTap=0
$clock=[Diagnostics.Stopwatch]::StartNew()
$form=New-Object Windows.Forms.Form;$form.Text='完美按键辅助 v0.2 · 测试版';$form.Size=New-Object Drawing.Size(1000,740);$form.MinimumSize=$form.Size;$form.StartPosition='CenterScreen'
function Label([string]$Text,[int]$X,[int]$Y,[int]$W,[int]$H=30){$l=New-Object Windows.Forms.Label;$l.Text=$Text;$l.SetBounds($X,$Y,$W,$H);$form.Controls.Add($l);return $l}
[void](Label '普通按键版：循环选怪、技能和拾取；仅在绑定的游戏窗口处于前台时操作。F9 紧急停止。' 15 15 950 30)
[void](Label '尚未实现：自动读取血量、死亡、背包、怪物名称。使用默认配置前请核对游戏快捷键。' 15 45 950 35)
$windows=New-Object Windows.Forms.ComboBox;$windows.DropDownStyle='DropDownList';$windows.SetBounds(15,90,655,30);$windows.DisplayMember='Label';$form.Controls.Add($windows)
$refresh=New-Object Windows.Forms.Button;$refresh.Text='刷新游戏窗口';$refresh.SetBounds(690,88,135,32);$form.Controls.Add($refresh)
$bind=New-Object Windows.Forms.Button;$bind.Text='绑定所选窗口';$bind.SetBounds(835,88,135,32);$form.Controls.Add($bind)
$state=Label '未绑定；只识别 elementclient.exe 的可见主窗口。' 15 135 950 35
$grid=New-Object Windows.Forms.DataGridView;$grid.SetBounds(15,180,955,245);$grid.AllowUserToAddRows=$false;$grid.AllowUserToDeleteRows=$false;$grid.RowHeadersVisible=$false;$grid.AutoSizeColumnsMode='Fill';$form.Controls.Add($grid)
$check=New-Object Windows.Forms.DataGridViewCheckBoxColumn;$check.Name='Enabled';$check.HeaderText='启用';$check.FillWeight=45;[void]$grid.Columns.Add($check)
[void]$grid.Columns.Add('Name','动作名称')
$keys=New-Object Windows.Forms.DataGridViewComboBoxColumn;$keys.Name='Key';$keys.HeaderText='游戏按键';[void]$keys.Items.AddRange([object[]]@('TAB','1','2','3','4','5','6','7','8','9','F1','F2','F3','F4','F5','F6','F7','F10','F11','F12','SPACE'));[void]$grid.Columns.Add($keys)
[void]$grid.Columns.Add('IntervalMs','间隔（毫秒）')
foreach($col in $grid.Columns){$col.SortMode='NotSortable'}
$grid.Columns['Name'].ReadOnly=$true
$log=New-Object Windows.Forms.TextBox;$log.Multiline=$true;$log.ReadOnly=$true;$log.ScrollBars='Vertical';$log.SetBounds(15,495,955,175);$log.Anchor='Top,Bottom,Left,Right';$form.Controls.Add($log)
function Log([string]$Text){if($log.TextLength -gt 60000){$log.Clear()};$log.AppendText(('['+(Get-Date -Format 'HH:mm:ss')+'] '+$Text+[Environment]::NewLine))}
function Stop-Run([string]$Reason){$wasRunning=$script:Running;$script:Running=$false;$grid.Enabled=$true;$windows.Enabled=$true;$refresh.Enabled=$true;$bind.Enabled=$true;$state.Text='已停止/暂停：'+$Reason;if($wasRunning){Log $Reason}}
function Display-Config($c){
 Assert-KeyConfig $c
 $grid.Rows.Clear()
 foreach($a in @($c.Actions)){[void]$grid.Rows.Add([object[]]@($a.Enabled,[string]$a.Name,([string]$a.Key).ToUpperInvariant(),[int]$a.IntervalMs))}
}
function Read-Config {
 [void]$grid.EndEdit();$actions=@()
 foreach($r in $grid.Rows){$actions += [pscustomobject]@{Enabled=$r.Cells['Enabled'].Value;Name=[string]$r.Cells['Name'].Value;Key=[string]$r.Cells['Key'].Value;IntervalMs=$r.Cells['IntervalMs'].Value}}
 $c=[pscustomobject]@{Version=2;Actions=$actions};Assert-KeyConfig $c;return $c
}
function Refresh-Windows {
 Stop-Run '刷新窗口列表';$script:Bound=$null;$windows.Items.Clear()
 foreach($p in Get-Process -Name elementclient -ErrorAction SilentlyContinue){try{if($p.MainWindowHandle -ne [IntPtr]::Zero){$o=[pscustomobject]@{Label=([string]$p.Id+' | '+$p.MainWindowTitle);PidValue=$p.Id;HandleValue=$p.MainWindowHandle;StartTicks=$p.StartTime.ToUniversalTime().Ticks};[void]$windows.Items.Add($o)}}catch{}}
 if($windows.Items.Count){$windows.SelectedIndex=0};Log ('发现 '+$windows.Items.Count+' 个游戏窗口。')
}
$refresh.Add_Click({try{Refresh-Windows}catch{Log $_.Exception.Message}})
$bind.Add_Click({try{Stop-Run '更换绑定';if($null -eq $windows.SelectedItem){throw '请先启动游戏并刷新列表。'};$script:Bound=$windows.SelectedItem;$state.Text='已绑定：'+$script:Bound.Label+'；点击开始后将切到该游戏。';Log $state.Text}catch{Log $_.Exception.Message}})
function Add-Button([string]$Text,[int]$X,[int]$Width,[scriptblock]$Click){$b=New-Object Windows.Forms.Button;$b.Text=$Text;$b.SetBounds($X,445,$Width,32);$b.Add_Click($Click);$form.Controls.Add($b);return $b}
$start=Add-Button '开始 / 重新开始' 15 165 {
 try {
  Stop-Run '准备启动'
  if($null -eq $script:Bound){throw '请先绑定游戏窗口。'}
  $p=Get-Process -Id $script:Bound.PidValue -ErrorAction Stop
  if($p.StartTime.ToUniversalTime().Ticks -ne $script:Bound.StartTicks -or $p.MainWindowHandle -ne $script:Bound.HandleValue){throw '游戏窗口或进程已变化，请重新绑定。'}
  $c=Read-Config;$script:Schedule=@(New-KeySchedule $c $clock.ElapsedMilliseconds)
  [void][PWKeyNative]::ShowWindow($script:Bound.HandleValue,9)
  [void][PWKeyNative]::SetForegroundWindow($script:Bound.HandleValue)
  if([PWKeyNative]::GetForegroundWindow() -ne $script:Bound.HandleValue){throw '未能切换到游戏前台，未启动。'}
  $script:Running=$true;$script:NextTap=$clock.ElapsedMilliseconds+500
  $grid.Enabled=$false;$windows.Enabled=$false;$refresh.Enabled=$false;$bind.Enabled=$false
  $state.Text='运行中：'+$script:Bound.Label+'；切到其他窗口会暂停，F9 停止。';Log '开始循环按键；首次操作延迟500毫秒。'
 } catch {Stop-Run $_.Exception.Message;Log $_.Exception.Message}
}
$stop=Add-Button '停止（F9）' 195 145 {Stop-Run '手动停止'}
$import=Add-Button '导入按键配置' 355 155 {
 $d=New-Object Windows.Forms.OpenFileDialog;$d.Filter='按键JSON配置|*.json'
 try{Stop-Run '导入配置';if($d.ShowDialog() -eq 'OK'){Display-Config (Get-Content -LiteralPath $d.FileName -Raw -Encoding UTF8|ConvertFrom-Json);Log '配置已导入。'}}catch{Log $_.Exception.Message}finally{$d.Dispose()}
}
$export=Add-Button '另存按键配置' 525 155 {
 $d=New-Object Windows.Forms.SaveFileDialog;$d.Filter='按键JSON配置|*.json';$d.FileName='key-config.json'
 try{Stop-Run '保存配置';$c=Read-Config;if($d.ShowDialog() -eq 'OK'){if([IO.File]::Exists($d.FileName)){throw '为保留旧配置，请使用新的文件名。'};$bytes=[Text.Encoding]::UTF8.GetBytes(($c|ConvertTo-Json -Depth 6));$f=[IO.File]::Open($d.FileName,[IO.FileMode]::CreateNew);try{$f.Write($bytes,0,$bytes.Length)}finally{$f.Dispose()};Log '配置已另存。'}}catch{Log $_.Exception.Message}finally{$d.Dispose()}
}
[void](Label '提示：按键会作用于游戏的聊天框或菜单。开始前关闭聊天输入框、背包和对话框；本版不能识别这些状态。' 15 680 950 35)
$timer=New-Object Windows.Forms.Timer;$timer.Interval=50
$timer.Add_Tick({
 try {
  if([PWKeyNative]::IsF9Down()){Stop-Run 'F9紧急停止';return}
  if(-not $script:Running){return}
  if($null -eq $script:Bound -or -not [PWKeyNative]::IsWindow($script:Bound.HandleValue)){Stop-Run '游戏窗口关闭';return}
  if([PWKeyNative]::GetForegroundWindow() -ne $script:Bound.HandleValue -or [PWKeyNative]::IsIconic($script:Bound.HandleValue)){Stop-Run '游戏失去焦点或最小化，请确认后重新开始';return}
  $p=Get-Process -Id $script:Bound.PidValue -ErrorAction Stop
  if($p.StartTime.ToUniversalTime().Ticks -ne $script:Bound.StartTicks){Stop-Run '游戏进程已变化';return}
  if($clock.ElapsedMilliseconds -lt $script:NextTap){return}
  $action=Get-DueKey $script:Schedule $clock.ElapsedMilliseconds
  if($null -eq $action){return}
  if(-not [PWKeyNative]::Tap($script:Bound.HandleValue,[uint32]$script:Bound.PidValue,[uint16]$action.Code)){Stop-Run '按键未发送或被系统阻止';return}
  $script:NextTap=$clock.ElapsedMilliseconds+200
  Log ('已发送按键：'+$action.Key+'（'+$action.Name+'）')
 } catch {Stop-Run ('运行异常：'+$_.Exception.Message)}
})
$form.Add_FormClosing({$script:Running=$false;$timer.Stop()})
try{Display-Config (Get-Content (Join-Path $PSScriptRoot 'default-config.json') -Raw -Encoding UTF8|ConvertFrom-Json);Refresh-Windows;$timer.Start();[void]$form.ShowDialog()}finally{$timer.Stop();$timer.Dispose();$form.Dispose()}
