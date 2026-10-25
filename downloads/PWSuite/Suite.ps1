$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Rules.ps1')
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'StatsReader.cs')
Add-Type -Path (Join-Path $PSScriptRoot 'WindowSync.cs')
[xml]$xaml=Get-Content (Join-Path $PSScriptRoot 'Suite.xaml') -Raw -Encoding UTF8
$window=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader($xaml)))
$ui=@{};foreach($name in @('DragArea','Minimize','Close','RoleName','ConnectionState','ConnectionDot','HpBar','MpBar','HpText','MpText','Connect','Pages','Load','Save','Demo','Log','Follow','Footer')){$ui[$name]=$window.FindName($name)}
$script:Fields=@{};$script:LiveReader=$null;$script:LiveInfo=$null;$script:AutoJob=$null;$script:Handle=[IntPtr]::Zero;$script:GameHandle=[IntPtr]::Zero;$script:ManualHidden=$false;$script:Dragging=$false
$script:CachePath=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'PWSuite\role-session-cache.json'
function Brush([string]$Hex){return [Windows.Media.BrushConverter]::new().ConvertFromString($Hex)}
function Log([string]$Text){if($ui.Log.Text.Length -gt 45000){$ui.Log.Clear()};$ui.Log.AppendText(('['+(Get-Date -Format 'HH:mm:ss')+'] '+$Text+[Environment]::NewLine));$ui.Log.ScrollToEnd()}
function Label($Parent,[string]$Text,[bool]$Hint=$false){$t=New-Object Windows.Controls.TextBlock;$t.Text=$Text;if($Hint){$t.Style=$window.Resources['Hint']}else{$t.Margin='0,0,0,8';$t.Foreground=Brush '#CFD8E5'};[void]$Parent.Children.Add($t);return $t}
function New-Card($Parent,[string]$Title,[string]$Hint=''){
 $b=New-Object Windows.Controls.Border;$b.Style=$window.Resources['Card'];$s=New-Object Windows.Controls.StackPanel;$b.Child=$s
 $t=New-Object Windows.Controls.TextBlock;$t.Text=$Title;$t.FontWeight='SemiBold';$t.FontSize=12;$t.Foreground=Brush '#D7BE92';$t.Margin='0,0,0,9';[void]$s.Children.Add($t)
 if($Hint){[void](Label $s $Hint $true)};[void]$Parent.Children.Add($b);return $s
}
function Row($Parent){$r=New-Object Windows.Controls.DockPanel;$r.LastChildFill=$true;$r.Margin='0,4,0,4';[void]$Parent.Children.Add($r);return $r}
function Check($Parent,[string]$Title,[string]$Path){$c=New-Object Windows.Controls.CheckBox;$c.Content=$Title;[void]$Parent.Children.Add($c);$script:Fields[$Path]=@{Kind='Bool';Control=$c};return $c}
function NumberRow($Parent,[string]$Title,[string]$Path,[string]$Unit=''){
 $r=Row $Parent;$t=New-Object Windows.Controls.TextBlock;$t.Text=$Title;$t.Width=175;[Windows.Controls.DockPanel]::SetDock($t,'Left');[void]$r.Children.Add($t)
 $unitText=New-Object Windows.Controls.TextBlock;$unitText.Text=$Unit;$unitText.Width=30;$unitText.Margin='8,0,0,0';$unitText.Foreground=Brush '#8392A9';[Windows.Controls.DockPanel]::SetDock($unitText,'Right');[void]$r.Children.Add($unitText)
 $v=New-Object Windows.Controls.TextBox;$v.TextAlignment='Center';$v.FontFamily='Consolas';[void]$r.Children.Add($v);$script:Fields[$Path]=@{Kind='Number';Control=$v};return $v
}
function Entry($Parent,[string]$Path,[string]$Hint=''){$c=New-Object Windows.Controls.TextBox;$c.Margin='0,3,0,7';$c.ToolTip=$Hint;[void]$Parent.Children.Add($c);$script:Fields[$Path]=@{Kind='String';Control=$c};return $c}
function Choice($Parent,[string]$Path,[string[]]$Values){$c=New-Object Windows.Controls.ComboBox;$c.Margin='0,4,0,7';foreach($v in $Values){[void]$c.Items.Add($v)};[void]$Parent.Children.Add($c);$script:Fields[$Path]=@{Kind='Choice';Control=$c};return $c}
function Button($Parent,[string]$Text,[scriptblock]$Click){$b=New-Object Windows.Controls.Button;$b.Content=$Text;$b.Margin='0,6,0,0';if($Click){$b.Add_Click($Click)};[void]$Parent.Children.Add($b);return $b}
function Names($Parent,[string]$Path,[int]$Height=145){
 $list=New-Object Windows.Controls.ListBox;$list.Height=$Height;$list.Margin='0,3,0,7';[void]$Parent.Children.Add($list)
 $r=Row $Parent;$add=New-Object Windows.Controls.Button;$add.Content='＋';$add.Width=37;$add.Padding='0,4';$add.Margin='6,0,0,0';[Windows.Controls.DockPanel]::SetDock($add,'Right');[void]$r.Children.Add($add)
 $remove=New-Object Windows.Controls.Button;$remove.Content='－';$remove.Width=37;$remove.Padding='0,4';$remove.Margin='6,0,0,0';[Windows.Controls.DockPanel]::SetDock($remove,'Right');[void]$r.Children.Add($remove)
 $entryBox=New-Object Windows.Controls.TextBox;$entryBox.ToolTip='填写名称后点击＋';[void]$r.Children.Add($entryBox)
 $add.Add_Click({$value=$entryBox.Text.Trim();if(-not $value){return};foreach($old in $list.Items){if([string]$old.Content -ceq $value){return}};$check=New-Object Windows.Controls.CheckBox;$check.Content=$value;$check.IsChecked=$true;[void]$list.Items.Add($check);$entryBox.Clear()}.GetNewClosure())
 $remove.Add_Click({if($list.SelectedIndex -ge 0){$list.Items.RemoveAt($list.SelectedIndex)}}.GetNewClosure())
 $script:Fields[$Path]=@{Kind='Names';Control=$list};return $list
}
$pages=@{}
foreach($title in @('控制','保护','技能','状态','选怪','拾取')){
 $tab=New-Object Windows.Controls.TabItem;$tab.Header=$title
 $scroll=New-Object Windows.Controls.ScrollViewer;$scroll.VerticalScrollBarVisibility='Auto';$scroll.HorizontalScrollBarVisibility='Disabled';$scroll.Padding='0,0,3,0';$stack=New-Object Windows.Controls.StackPanel;$scroll.Content=$stack;$tab.Content=$scroll
 [void]$ui.Pages.Items.Add($tab);$pages[$title]=$stack
}
$p=New-Card $pages['控制'] '功能开关';[void](Check $p '保护角色生命与真气' 'Control.Protection');[void](Check $p '保持自身增益状态' 'Control.Status');[void](Check $p '自动拾取物品' 'Control.Pickup')
$p=New-Card $pages['控制'] '范围与目标';[void](Check $p '启用超时换怪' 'Control.SwitchTimeout');[void](NumberRow $p '目标超时时间' 'Control.SwitchSeconds' '秒');[void](Check $p '限制挂机范围' 'Control.LimitRange');[void](NumberRow $p '中心范围' 'Control.Range' '米');[void](Check $p '忽略返回中心点' 'Control.IgnoreReturn')
$p=New-Card $pages['控制'] '运行状态';[void](Label $p '当前已接入角色名字、生命与真气。技能、目标、状态及物品执行接口仍待适配。' $true)
$run=Button $p '挂机执行 · 尚未接入' $null;$run.IsEnabled=$false
[void](Label $p '窗口跟随不等于后台游戏画面刷新；后者尚未接入。' $true)
$p=New-Card $pages['保护'] '保护规则' '生命或真气低于阈值时提出药品／技能建议。'
$rules=New-Object Windows.Controls.DataGrid;$rules.AutoGenerateColumns=$false;$rules.CanUserAddRows=$false;$rules.CanUserDeleteRows=$false;$rules.Height=185;$rules.Margin='0,6,0,3';$rules.SelectionMode='Single'
$col=New-Object Windows.Controls.DataGridCheckBoxColumn;$col.Header='开';$col.Binding=New-Object Windows.Data.Binding('Enabled');$col.Width=30;[void]$rules.Columns.Add($col)
foreach($spec in @(@('Attribute','属性',@('生命','真气')),@('Type','使用',@('药品','技能')))){$col=New-Object Windows.Controls.DataGridComboBoxColumn;$col.Header=$spec[1];$col.ItemsSource=[string[]]$spec[2];$binding=New-Object Windows.Data.Binding($spec[0]);$binding.Mode='TwoWay';$binding.UpdateSourceTrigger='PropertyChanged';$col.SelectedItemBinding=$binding;$col.Width=55;[void]$rules.Columns.Add($col)}
foreach($spec in @(@('Threshold','阈值%',50),@('Name','名称','*'))){$col=New-Object Windows.Controls.DataGridTextColumn;$col.Header=$spec[1];$binding=New-Object Windows.Data.Binding($spec[0]);$binding.Mode='TwoWay';$binding.UpdateSourceTrigger='PropertyChanged';$col.Binding=$binding;$col.Width=[Windows.Controls.DataGridLengthConverter]::new().ConvertFromString([string]$spec[2]);[void]$rules.Columns.Add($col)}
$script:ProtectionItems=New-Object 'Collections.ObjectModel.ObservableCollection[object]';$rules.ItemsSource=$script:ProtectionItems;[void]$p.Children.Add($rules)
[void](Button $p '＋ 添加保护规则' {if($script:ProtectionItems.Count -lt 20){$script:ProtectionItems.Add([pscustomobject]@{Enabled=$true;Attribute='生命';Type='药品';Threshold=50;Name='填写名称'})}})
[void](Button $p '删除选中规则' {if($rules.SelectedItem){[void]$script:ProtectionItems.Remove($rules.SelectedItem)}})
$p=New-Card $pages['保护'] '战宠';[void](Check $p '挂机时自动召唤战宠' 'Protection.SummonPet');[void](Entry $p 'Protection.PetName' '战宠名称')
$p=New-Card $pages['技能'] '条件技能';[void](Check $p '首次攻击使用指定技能' 'Skills.FirstEnabled');[void](Entry $p 'Skills.FirstName' '首次技能名称');[void](Check $p '远距离条件技能' 'Skills.FarEnabled');[void](NumberRow $p '目标距离大于' 'Skills.FarDistance' '米');[void](Entry $p 'Skills.FarName' '远距离技能名称');[void](Check $p '近距离条件技能' 'Skills.NearEnabled');[void](NumberRow $p '目标距离小于' 'Skills.NearDistance' '米');[void](Entry $p 'Skills.NearName' '近距离技能名称')
$p=New-Card $pages['技能'] '循环技能' '按顺序选择就绪技能，不修改游戏冷却。';[void](Names $p 'Skills.Loop' 120);[void](Check $p '技能未就绪时使用普通攻击' 'Skills.BasicAttack')
$p=New-Card $pages['状态'] '自身状态保持';[void](Names $p 'Status.Names' 155)
$p=New-Card $pages['状态'] '自动补充';[void](Check $p '自动更换红符' 'Status.RedCharm');[void](Check $p '自动更换蓝符' 'Status.BlueCharm');[void](Check $p '持续使用仙气' 'Status.FairyQi')
$p=New-Card $pages['状态'] '异常解除';[void](Check $p '昏迷时使用解除技能' 'Status.Cleanse');[void](Entry $p 'Status.CleanseName' '解除技能名称')
$p=New-Card $pages['选怪'] '目标名单';[void](Check $p '启用选怪过滤' 'Target.Enabled');[void](Choice $p 'Target.Mode' @('只选列表','不选列表'));[void](Names $p 'Target.Names' 145)
$p=New-Card $pages['选怪'] '等级与高差';[void](Check $p '排除高于指定等级的怪物' 'Target.AboveEnabled');[void](NumberRow $p '最高等级' 'Target.AboveLevel' '级');[void](Check $p '排除低于指定等级的怪物' 'Target.BelowEnabled');[void](NumberRow $p '最低等级' 'Target.BelowLevel' '级');[void](Check $p '限制怪物与角色高差' 'Target.HeightEnabled');[void](NumberRow $p '允许高差' 'Target.MaxHeight' '米')
$p=New-Card $pages['拾取'] '物品名单';[void](Check $p '启用拾取过滤' 'Pickup.Enabled');[void](Choice $p 'Pickup.Mode' @('不捡列表','只捡列表'));[void](Names $p 'Pickup.Names' 160)
$p=New-Card $pages['拾取'] '拾取方式';[void](Check $p '允许跑去拾取' 'Pickup.RunTo');[void](Check $p '忽略金币' 'Pickup.IgnoreCoins');[void](Label $p '未勾选跑去拾取时，仅规划原地范围内的物品。自动拾取总开关在控制页。' $true)
function Get-Value($c,[string]$path){$a=$path.Split('.');return $c.($a[0]).($a[1])}
function Set-Value($c,[string]$path,$value){$a=$path.Split('.');$c.($a[0]).($a[1])=$value}
function Show-Config($c){Assert-SuiteConfig $c;foreach($path in $script:Fields.Keys){$f=$script:Fields[$path];$v=Get-Value $c $path;switch($f.Kind){'Bool'{$f.Control.IsChecked=$v};'Number'{$f.Control.Text=[string]$v};'String'{$f.Control.Text=[string]$v};'Choice'{$f.Control.SelectedItem=$v};'Names'{$f.Control.Items.Clear();foreach($n in @($v)){$check=New-Object Windows.Controls.CheckBox;$check.Content=[string]$n;$check.IsChecked=$true;[void]$f.Control.Items.Add($check)}}}};$script:ProtectionItems.Clear();foreach($r in @($c.Protection.Rules)){$script:ProtectionItems.Add($r)}}
function Read-Config {
 $c=New-SuiteConfig
 foreach($path in $script:Fields.Keys){$f=$script:Fields[$path];switch($f.Kind){'Bool'{$value=[bool]$f.Control.IsChecked};'Number'{[int]$number=0;if(-not [int]::TryParse($f.Control.Text,[ref]$number)){throw '距离、等级和时间必须填整数。'};$value=$number};'String'{$value=$f.Control.Text.Trim()};'Choice'{$value=[string]$f.Control.SelectedItem};'Names'{$value=@($f.Control.Items|Where-Object{$_.IsChecked -eq $true}|ForEach-Object{[string]$_.Content})}};Set-Value $c $path $value}
 [void]$rules.CommitEdit([Windows.Controls.DataGridEditingUnit]::Cell,$true);[void]$rules.CommitEdit([Windows.Controls.DataGridEditingUnit]::Row,$true)
 $c.Protection.Rules=@($script:ProtectionItems | ForEach-Object { $_ });Assert-SuiteConfig $c;return $c
}
$ui.Load.Add_Click({$d=New-Object Microsoft.Win32.OpenFileDialog;$d.Filter='助手配置|*.json';try{if($d.ShowDialog($window)) {Show-Config (Get-Content -LiteralPath $d.FileName -Raw -Encoding UTF8|ConvertFrom-Json);Log '配置已读取。'}}catch{Log $_.Exception.Message}})
$ui.Save.Add_Click({$d=New-Object Microsoft.Win32.SaveFileDialog;$d.Filter='助手配置|*.json';$d.FileName='suite-config.json';try{$c=Read-Config;if($d.ShowDialog($window)){if([IO.File]::Exists($d.FileName)){throw '请使用新的文件名，原配置不会覆盖。'};$bytes=[Text.Encoding]::UTF8.GetBytes(($c|ConvertTo-Json -Depth 12));$f=[IO.File]::Open($d.FileName,[IO.FileMode]::CreateNew);try{$f.Write($bytes,0,$bytes.Length)}finally{$f.Dispose()};Log '配置已另存。'}}catch{Log $_.Exception.Message}})
$ui.Demo.Add_Click({try{$c=Read-Config;$snap=New-SuiteDemoState;$s=New-SuiteSession $c 'demo-role';$plan=@(Get-SuitePlan $s $snap 0);Log ('离线规则演练：'+$s.State);foreach($a in $plan){Log ('[未执行] '+$a.Kind+' / '+$a.Name)};if(-not $plan.Count){Log '无动作建议；没有操作游戏。'}}catch{Log $_.Exception.Message}})
function Reset-Display {
 $ui.RoleName.Text='等待连接角色';$ui.ConnectionState.Text='  未连接';$ui.ConnectionDot.Fill=Brush '#6F7A8B';$ui.HpText.Text='HP  — / —';$ui.MpText.Text='MP  — / —';$ui.HpBar.Value=0;$ui.MpBar.Value=0
}
function Disconnect-Live([string]$Reason){
 if($script:AutoJob){$script:AutoJob.Cancel();$script:AutoJob=$null};if($script:LiveReader){$script:LiveReader.Dispose();$script:LiveReader=$null}
 $script:LiveInfo=$null;$script:GameHandle=[IntPtr]::Zero;$ui.Connect.Content='连接';Reset-Display;$ui.Footer.Text='角色读取停止 · 操作接口待接入'
 if($script:Handle -ne [IntPtr]::Zero){[PWSuiteWindowSync]::Release($script:Handle);if(-not $script:ManualHidden){[void][PWSuiteWindowSync]::ShowWindow($script:Handle,4)}};Log $Reason
}
function Select-GamePid {
 $games=@(Get-Process -Name elementclient -ErrorAction SilentlyContinue);if($games.Count -eq 0){throw '未找到游戏，请先进入角色。'};if($games.Count -eq 1){return [int]$games[0].Id}
 $d=New-Object Windows.Window;$d.Title='选择游戏';$d.Width=390;$d.Height=180;$d.ResizeMode='NoResize';$d.WindowStartupLocation='CenterOwner';$d.Owner=$window;$d.Background=Brush '#171E29';$d.Foreground=Brush '#E6E9EF';$d.FontFamily='Microsoft YaHei UI'
 $panel=New-Object Windows.Controls.StackPanel;$panel.Margin=20;$d.Content=$panel;$list=New-Object Windows.Controls.ComboBox;$list.Style=$window.Resources[[Windows.Controls.ComboBox]];$list.DisplayMemberPath='Title';foreach($g in $games){[void]$list.Items.Add([pscustomobject]@{Title=([string]$g.Id+' | '+$g.MainWindowTitle);ProcessId=$g.Id})};$list.SelectedIndex=0;[void]$panel.Children.Add($list)
 $ok=New-Object Windows.Controls.Button;$ok.Content='连接所选游戏';$ok.Margin='0,14,0,0';$ok.Height=31;$ok.Style=$window.Resources['Primary'];$ok.Add_Click({$d.DialogResult=$true}.GetNewClosure());[void]$panel.Children.Add($ok)
 if($d.ShowDialog()){return [int]$list.SelectedItem.ProcessId};return 0
}
function Open-LiveInfo($info){
 $script:LiveReader=[PWStatsReader]::Open([int]$info.ProcessId,[long]$info.StartTicks,[string]$info.Name,[long]$info.NamePointer,[long]$info.NameAddress,[long[]]$info.HpAddresses,[long[]]$info.MpAddresses)
 $value=$script:LiveReader.Read();if(-not [PWAutoRoleConnector]::PlausibleStats($value.HpA,$value.MpA,$value.HpB,$value.MpB)){throw '当前值与上限关系不成立。'}
 $script:LiveInfo=$info;$process=Get-Process -Id $info.ProcessId -ErrorAction Stop;$script:GameHandle=$process.MainWindowHandle;[PWSuiteWindowSync]::AnchorX=-1;[PWSuiteWindowSync]::AnchorY=24
 $ui.ConnectionState.Text='  已连接';$ui.ConnectionDot.Fill=Brush '#86B6A0';$ui.Connect.Content='重连';$ui.Footer.Text='角色已连接 · 操作接口待接入';Update-LiveDisplay $value
}
function Update-LiveDisplay($v){$ui.RoleName.Text=$v.Name;$ui.HpText.Text='HP  '+$v.HpA+' / '+$v.HpB;$ui.MpText.Text='MP  '+$v.MpA+' / '+$v.MpB;$ui.HpBar.Value=100.0*$v.HpA/$v.HpB;$ui.MpBar.Value=100.0*$v.MpA/$v.MpB}
function Save-SessionCache($info){try{[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($script:CachePath));$json=[pscustomobject]@{Version=1;Info=$info}|ConvertTo-Json -Depth 8;[IO.File]::WriteAllText($script:CachePath,$json,[Text.Encoding]::UTF8)}catch{Log '已连接，本地缓存未能保存。'}}
$ui.Connect.Add_Click({try{
 if($script:AutoJob){Disconnect-Live '已取消连接';return};$selected=Select-GamePid;if(-not $selected){return};Disconnect-Live '正在连接游戏'
 if(Test-Path -LiteralPath $script:CachePath){try{$cache=Get-Content -LiteralPath $script:CachePath -Raw -Encoding UTF8|ConvertFrom-Json;if($cache.Version -eq 1 -and $cache.Info.ProcessId -eq $selected -and $cache.Info.Sha256 -eq '2f7f098806d965fea21d4206a201868d3e897b3dfd91c97caf93b28e91df1b3f'){Open-LiveInfo $cache.Info;Log '已复用本机当前会话缓存。';return}}catch{if($script:LiveReader){$script:LiveReader.Dispose();$script:LiveReader=$null};Log '旧缓存失效，自动重新定位。'}}
 $script:AutoJob=[PWAutoRoleConnector]::Start($selected);$ui.Connect.Content='取消';$ui.ConnectionState.Text='  定位中';Log '自动定位角色数据，无需加载文件。'
}catch{Disconnect-Live $_.Exception.Message}})
$liveTimer=New-Object Windows.Threading.DispatcherTimer;$liveTimer.Interval=[TimeSpan]::FromMilliseconds(400)
$liveTimer.Add_Tick({
 if($script:AutoJob){$p=$script:AutoJob.GetProgress();$ui.RoleName.Text=$p.State;$ui.ConnectionState.Text='  '+[Math]::Round($p.BytesRead/1MB,0)+'MB';if($p.State -eq '已连接'){try{$info=$p.Result;$script:AutoJob=$null;Open-LiveInfo $info;Save-SessionCache $info;Log '已自动连接。'}catch{Disconnect-Live $_.Exception.Message}}elseif($p.State -in @('失败','已取消')){Disconnect-Live ($p.State+' '+$p.Error)};return}
 if(-not $script:LiveReader){return};try{$v=$script:LiveReader.Read();if(-not [PWAutoRoleConnector]::PlausibleStats($v.HpA,$v.MpA,$v.HpB,$v.MpB)){throw '角色数值关系异常。'};Update-LiveDisplay $v}catch{Disconnect-Live $_.Exception.Message}
})
$followTimer=New-Object Windows.Threading.DispatcherTimer;$followTimer.Interval=[TimeSpan]::FromMilliseconds(100)
$followTimer.Add_Tick({if($script:Dragging -or $script:ManualHidden -or $script:Handle -eq [IntPtr]::Zero -or -not $script:LiveInfo){return};try{
 if($ui.Follow.IsChecked -ne $true){[PWSuiteWindowSync]::Release($script:Handle);return}
 $p=Get-Process -Id $script:LiveInfo.ProcessId -ErrorAction Stop;if($p.StartTime.ToUniversalTime().Ticks -ne $script:LiveInfo.StartTicks){throw '游戏进程已变化。'};$script:GameHandle=$p.MainWindowHandle
 $result=[PWSuiteWindowSync]::Follow($script:Handle,$script:GameHandle,[uint32]$script:LiveInfo.ProcessId,[uint32]$PID)
 if($result -eq -1){Disconnect-Live '游戏窗口关闭。'}
}catch{Disconnect-Live $_.Exception.Message}})
$ui.Follow.Add_Unchecked({if($script:Handle -ne [IntPtr]::Zero){[PWSuiteWindowSync]::Release($script:Handle);if(-not $script:ManualHidden){[void][PWSuiteWindowSync]::ShowWindow($script:Handle,4)}}})
$ui.DragArea.Add_MouseLeftButtonDown({if($_.ButtonState -eq 'Pressed'){$script:Dragging=$true;try{$window.DragMove()}catch{}finally{$script:Dragging=$false;if($script:GameHandle -ne [IntPtr]::Zero -and $ui.Follow.IsChecked){[PWSuiteWindowSync]::CaptureAnchor($script:Handle,$script:GameHandle)}}}})
$tray=New-Object Windows.Forms.NotifyIcon;$tray.Icon=[Drawing.SystemIcons]::Application;$tray.Text='山海助手 · 双击显示面板';$tray.Visible=$true
$tray.Add_DoubleClick({$script:ManualHidden=$false;$ui.Follow.IsChecked=$false;$window.Show();$window.Activate()|Out-Null})
$ui.Minimize.Add_Click({$script:ManualHidden=$true;$window.Hide()})
$ui.Close.Add_Click({$window.Close()})
$window.Add_SourceInitialized({$helper=New-Object Windows.Interop.WindowInteropHelper($window);$script:Handle=$helper.Handle})
$window.Add_Closed({[Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvokeShutdown([Windows.Threading.DispatcherPriority]::Background)})
$window.Add_Closing({$liveTimer.Stop();$followTimer.Stop();if($script:AutoJob){$script:AutoJob.Cancel();$script:AutoJob=$null};if($script:LiveReader){$script:LiveReader.Dispose();$script:LiveReader=$null};$tray.Visible=$false})
try{Show-Config (New-SuiteConfig);Log '原生悬浮面板已启动，点击连接即可自动定位角色。';$liveTimer.Start();$followTimer.Start();$window.Show();[Windows.Threading.Dispatcher]::Run()}finally{$liveTimer.Stop();$followTimer.Stop();if($script:AutoJob){$script:AutoJob.Cancel()};if($script:LiveReader){$script:LiveReader.Dispose()};$tray.Visible=$false;$tray.Dispose()}
