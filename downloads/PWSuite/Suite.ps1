$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Rules.ps1')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'Skin.cs') -ReferencedAssemblies System.Windows.Forms,System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'StatsReader.cs')
$script:LiveReader=$null;$script:LiveInfo=$null
[Windows.Forms.Application]::EnableVisualStyles()
$script:Fields=@{};$script:Config=New-SuiteConfig
$form=New-Object Windows.Forms.Form;$form.Text='山海助手 v0.3.1 · 当前会话角色读取';$form.ClientSize=New-Object Drawing.Size(410,750);$form.FormBorderStyle='FixedSingle';$form.MaximizeBox=$false;$form.StartPosition='CenterScreen';$form.Font=New-Object Drawing.Font('Microsoft YaHei',9)
$bg=New-Object SuiteBackdrop;$bg.Dock='Fill';$form.Controls.Add($bg)
$gold=[Drawing.Color]::FromArgb(255,224,122);$light=[Drawing.Color]::FromArgb(225,232,244);$purple=[Drawing.Color]::FromArgb(225,112,255)
function Text($Parent,[string]$Value,[int]$X,[int]$Y,[int]$W=350,[int]$H=25){$l=New-Object Windows.Forms.Label;$l.Text=$Value;$l.SetBounds($X,$Y,$W,$H);$l.ForeColor=$gold;$l.BackColor=[Drawing.Color]::Transparent;$Parent.Controls.Add($l);return $l}
function Button($Parent,[string]$Value,[int]$X,[int]$Y,[int]$W,[scriptblock]$Click){$b=New-Object GoldButton;$b.Text=$Value;$b.SetBounds($X,$Y,$W,29);if($null -ne $Click){$b.Add_Click($Click)};$Parent.Controls.Add($b);return $b}
function Check($Parent,[string]$Title,[string]$Path,[int]$X,[int]$Y,[int]$W=340){$c=New-Object Windows.Forms.CheckBox;$c.Text=$Title;$c.SetBounds($X,$Y,$W,25);$c.ForeColor=$gold;$c.BackColor=[Drawing.Color]::Transparent;$Parent.Controls.Add($c);$script:Fields[$Path]=@{Kind='Bool';Control=$c};return $c}
function Number($Parent,[string]$Path,[int]$X,[int]$Y,[int]$Min=0,[int]$Max=1000,[int]$W=65){$c=New-Object Windows.Forms.NumericUpDown;$c.SetBounds($X,$Y,$W,25);$c.Minimum=$Min;$c.Maximum=$Max;$c.BackColor=[Drawing.Color]::FromArgb(27,33,45);$c.ForeColor=[Drawing.Color]::Lime;$Parent.Controls.Add($c);$script:Fields[$Path]=@{Kind='Number';Control=$c};return $c}
function Entry($Parent,[string]$Path,[int]$X,[int]$Y,[int]$W=170){$c=New-Object Windows.Forms.TextBox;$c.SetBounds($X,$Y,$W,25);$c.BackColor=[Drawing.Color]::FromArgb(20,24,33);$c.ForeColor=$light;$Parent.Controls.Add($c);$script:Fields[$Path]=@{Kind='String';Control=$c};return $c}
function Choice($Parent,[string]$Path,[object[]]$Options,[int]$X,[int]$Y,[int]$W=160){$c=New-Object Windows.Forms.ComboBox;$c.DropDownStyle='DropDownList';[void]$c.Items.AddRange($Options);$c.SetBounds($X,$Y,$W,25);$c.BackColor=[Drawing.Color]::FromArgb(27,33,45);$c.ForeColor=$gold;$Parent.Controls.Add($c);$script:Fields[$Path]=@{Kind='Choice';Control=$c};return $c}
function Names($Parent,[string]$Path,[int]$X,[int]$Y,[int]$W,[int]$H){
 $list=New-Object Windows.Forms.CheckedListBox;$list.CheckOnClick=$true;$list.SetBounds($X,$Y,$W,$H);$list.BackColor=[Drawing.Color]::FromArgb(12,17,24);$list.ForeColor=[Drawing.Color]::FromArgb(90,255,139);$list.BorderStyle='FixedSingle';$Parent.Controls.Add($list)
 $input=New-Object Windows.Forms.TextBox;$input.SetBounds($X,($Y+$H+8),($W-110),25);$input.BackColor=[Drawing.Color]::FromArgb(20,24,33);$input.ForeColor=$light;$Parent.Controls.Add($input)
 $add={ $value=$input.Text.Trim();if($value -and -not $list.Items.Contains($value)){[void]$list.Items.Add($value,$true);$input.Clear()} }.GetNewClosure()
 $delete={if($list.SelectedIndex -ge 0){$list.Items.RemoveAt($list.SelectedIndex)}}.GetNewClosure()
 [void](Button $Parent '添加' ($X+$W-105) ($Y+$H+5) 50 $add);[void](Button $Parent '删除' ($X+$W-50) ($Y+$H+5) 50 $delete)
 $script:Fields[$Path]=@{Kind='Names';Control=$list};return $list
}
$brand=Text $bg '山 海 助 手' 10 7 390 31;$brand.Font=New-Object Drawing.Font('Microsoft YaHei',17,[Drawing.FontStyle]::Bold);$brand.TextAlign='MiddleCenter'
$top=New-Object Windows.Forms.CheckBox;$top.Text='置顶';$top.ForeColor=$gold;$top.SetBounds(335,43,65,25);$top.BackColor=[Drawing.Color]::Transparent;$top.Add_CheckedChanged({$form.TopMost=$top.Checked});$bg.Controls.Add($top)
$connection=Text $bg '角色实时数据：未连接' 12 43 260 55
$tabs=New-Object GoldTabs;$tabs.SetBounds(10,105,390,443);$bg.Controls.Add($tabs)
$pages=@{}
foreach($title in @('控制','保护','技能','状态','选怪','拾物')){$p=New-Object Windows.Forms.TabPage;$p.Text=$title;$p.BackColor=[Drawing.Color]::FromArgb(48,55,75);$tabs.TabPages.Add($p);$panel=New-Object SuiteBackdrop;$panel.Dock='Fill';$p.Controls.Add($panel);$pages[$title]=$panel}
$p=$pages['控制'];[void](Text $p '挂机控制' 12 8 350);[void](Check $p '开启保护功能' 'Control.Protection' 16 43);[void](Check $p '开启自身状态保持' 'Control.Status' 16 79);[void](Check $p '开启自动拾取' 'Control.Pickup' 16 115)
[void](Check $p '超时换怪' 'Control.SwitchTimeout' 16 155 130);[void](Number $p 'Control.SwitchSeconds' 158 155 1 3600);[void](Text $p '秒' 233 157 40)
[void](Check $p '挂机范围' 'Control.LimitRange' 16 193 130);[void](Number $p 'Control.Range' 158 193 1 1000);[void](Text $p '米' 233 195 40)
[void](Check $p '无视返回中心点' 'Control.IgnoreReturn' 16 232)
$render=New-Object Windows.Forms.CheckBox;$render.Text='游戏后台画面刷新（未接入）';$render.Enabled=$false;$render.SetBounds(16,269,350,25);$p.Controls.Add($render)
[void](Text $p '以上为规则开关，需实时状态和执行接口才能生效。' 16 315 345 48)
[void](Button $p '示例演练' 16 369 96 {
 try{$c=Read-Config;$snap=New-SuiteDemoState;$session=New-SuiteSession $c 'demo-role';$plan=@(Get-SuitePlan $session $snap 0);Log ('[示例] '+$session.State+'；'+$session.Reason);foreach($a in $plan){Log ('[未执行] '+$a.Kind+' / '+$a.Name+' / '+$a.Reason)};if(-not $plan.Count){Log '[示例] 没有动作建议。'}}catch{Log $_.Exception.Message}
})
$run=Button $p '开始挂机 F12 · 待适配' 118 369 245 $null;$run.Enabled=$false
$p=$pages['保护'];[void](Text $p '保护设置：生命 / 真气百分比' 12 8 350)
$rules=New-Object Windows.Forms.DataGridView;$rules.SetBounds(12,39,354,165);$rules.RowHeadersVisible=$false;$rules.AllowUserToAddRows=$false;$rules.AllowUserToDeleteRows=$false;$rules.AutoSizeColumnsMode='Fill';$rules.BackgroundColor=[Drawing.Color]::FromArgb(15,20,28);$rules.DefaultCellStyle.BackColor=[Drawing.Color]::FromArgb(22,29,38);$rules.DefaultCellStyle.ForeColor=[Drawing.Color]::Lime;$rules.DefaultCellStyle.SelectionBackColor=[Drawing.Color]::FromArgb(63,79,101)
$c=New-Object Windows.Forms.DataGridViewCheckBoxColumn;$c.Name='Enabled';$c.HeaderText='开';$c.FillWeight=35;[void]$rules.Columns.Add($c)
foreach($spec in @(@('Attribute','保护类',@('生命','真气')),@('Type','使用',@('药品','技能')))){$col=New-Object Windows.Forms.DataGridViewComboBoxColumn;$col.Name=$spec[0];$col.HeaderText=$spec[1];[void]$col.Items.AddRange([object[]]$spec[2]);[void]$rules.Columns.Add($col)}
[void]$rules.Columns.Add('Threshold','阈值%');[void]$rules.Columns.Add('Name','药品/技能名');$rules.Columns['Name'].FillWeight=160;foreach($col in $rules.Columns){$col.SortMode='NotSortable'};$p.Controls.Add($rules)
[void](Button $p '添加规则' 12 213 110 {if($rules.Rows.Count -lt 20){[void]$rules.Rows.Add([object[]]@($true,'生命','药品',50,'填写名称'))}})
[void](Button $p '删除选中' 133 213 110 {if($rules.CurrentRow){$index=$rules.CurrentRow.Index;$rules.EndEdit()|Out-Null;$rules.Rows.RemoveAt($index)}})
[void](Check $p '挂机时召唤战宠' 'Protection.SummonPet' 16 275 190);[void](Entry $p 'Protection.PetName' 16 310 338)
[void](Text $p '药品需要库存和就绪状态，技能需要真实冷却信息。' 16 354 340 48)
$p=$pages['技能'];[void](Text $p '条件技能' 12 8 350)
[void](Check $p '首次打怪技能' 'Skills.FirstEnabled' 12 40 155);[void](Entry $p 'Skills.FirstName' 177 40 183)
[void](Check $p '怪距离 >' 'Skills.FarEnabled' 12 76 118);[void](Number $p 'Skills.FarDistance' 130 76 0 1000 50);[void](Entry $p 'Skills.FarName' 191 76 169)
[void](Check $p '怪距离 <' 'Skills.NearEnabled' 12 112 118);[void](Number $p 'Skills.NearDistance' 130 112 0 1000 50);[void](Entry $p 'Skills.NearName' 191 112 169)
[void](Text $p '循环技能（按列表顺序，跳过未就绪技能）' 12 155 350);[void](Names $p 'Skills.Loop' 12 188 348 145)
[void](Check $p '技能未就绪时使用普通攻击' 'Skills.BasicAttack' 12 380 348)
$p=$pages['状态'];[void](Text $p '自身状态保持（勾选需要保持的状态）' 12 8 350);[void](Names $p 'Status.Names' 12 42 348 163)
[void](Check $p '自动换红符' 'Status.RedCharm' 12 255 170);[void](Check $p '自动换蓝符' 'Status.BlueCharm' 190 255 170)
[void](Check $p '持续使用仙气' 'Status.FairyQi' 12 292 348);[void](Check $p '挂机时昏迷自动解除' 'Status.Cleanse' 12 330 348);[void](Entry $p 'Status.CleanseName' 12 366 348)
$p=$pages['选怪'];[void](Text $p '选怪过滤' 12 8 350);[void](Names $p 'Target.Names' 12 42 348 140)
[void](Choice $p 'Target.Mode' @('只选列表','不选列表') 12 235 348)
[void](Check $p '怪级 >' 'Target.AboveEnabled' 12 274 125);[void](Number $p 'Target.AboveLevel' 145 274 0 200);[void](Text $p '不选' 230 276 80)
[void](Check $p '怪级 <' 'Target.BelowEnabled' 12 309 125);[void](Number $p 'Target.BelowLevel' 145 309 0 200);[void](Text $p '不选' 230 311 80)
[void](Check $p '高差 >' 'Target.HeightEnabled' 12 344 125);[void](Number $p 'Target.MaxHeight' 145 344 0 1000);[void](Text $p '米不选' 230 346 100)
[void](Check $p '启用选怪过滤' 'Target.Enabled' 12 383 348)
$p=$pages['拾物'];[void](Text $p '拾取过滤' 12 8 350);[void](Names $p 'Pickup.Names' 12 42 348 180)
[void](Choice $p 'Pickup.Mode' @('不捡列表','只捡列表') 12 275 348)
[void](Check $p '跑去拾取（未勾选则只原地拾取）' 'Pickup.RunTo' 12 314 348)
[void](Check $p '忽略金币' 'Pickup.IgnoreCoins' 12 350 348);[void](Check $p '启用拾取过滤' 'Pickup.Enabled' 12 385 348)
$log=New-Object Windows.Forms.TextBox;$log.Multiline=$true;$log.ReadOnly=$true;$log.ScrollBars='Vertical';$log.SetBounds(10,600,390,105);$log.BackColor=[Drawing.Color]::Black;$log.ForeColor=[Drawing.Color]::FromArgb(100,255,126);$log.Font=New-Object Drawing.Font('Consolas',9);$bg.Controls.Add($log)
function Log([string]$Value){if($log.TextLength -gt 50000){$log.Clear()};$log.AppendText(('['+(Get-Date -Format 'HH:mm:ss')+'] '+$Value+[Environment]::NewLine))}
function Get-Value($c,[string]$Path){$x=$Path.Split('.');return $c.($x[0]).($x[1])}
function Set-Value($c,[string]$Path,$Value){$x=$Path.Split('.');$c.($x[0]).($x[1])=$Value}
function Show-Config($c){
 Assert-SuiteConfig $c
 foreach($path in $script:Fields.Keys){$f=$script:Fields[$path];$value=Get-Value $c $path;switch($f.Kind){'Bool'{$f.Control.Checked=$value};'Number'{$f.Control.Value=$value};'String'{$f.Control.Text=[string]$value};'Choice'{$f.Control.SelectedItem=$value};'Names'{$f.Control.Items.Clear();foreach($name in @($value)){[void]$f.Control.Items.Add([string]$name,$true)}}}}
 $rules.Rows.Clear();foreach($r in @($c.Protection.Rules)){[void]$rules.Rows.Add([object[]]@($r.Enabled,$r.Attribute,$r.Type,$r.Threshold,$r.Name))}
 $script:Config=$c
}
function Read-Config {
 $c=New-SuiteConfig
 foreach($path in $script:Fields.Keys){$f=$script:Fields[$path];switch($f.Kind){'Bool'{$value=$f.Control.Checked};'Number'{$value=[int]$f.Control.Value};'String'{$value=$f.Control.Text.Trim()};'Choice'{$value=[string]$f.Control.SelectedItem};'Names'{$value=@($f.Control.CheckedItems|ForEach-Object{[string]$_})}};Set-Value $c $path $value}
 [void]$rules.EndEdit();$entries=@();foreach($r in $rules.Rows){$entries += [pscustomobject]@{Enabled=$r.Cells['Enabled'].Value;Attribute=$r.Cells['Attribute'].Value;Type=$r.Cells['Type'].Value;Threshold=$r.Cells['Threshold'].Value;Name=$r.Cells['Name'].Value}}
 $c.Protection.Rules=$entries;Assert-SuiteConfig $c;return $c
}
[void](Button $bg '读取配置' 10 560 92 {
 $d=New-Object Windows.Forms.OpenFileDialog;$d.Filter='助手配置JSON|*.json';try{if($d.ShowDialog() -eq 'OK'){Show-Config (Get-Content -LiteralPath $d.FileName -Raw -Encoding UTF8|ConvertFrom-Json);Log '配置已读取。'}}catch{Log $_.Exception.Message}finally{$d.Dispose()}
})
[void](Button $bg '另存配置' 108 560 92 {
 $d=New-Object Windows.Forms.SaveFileDialog;$d.Filter='助手配置JSON|*.json';$d.FileName='suite-config.json';try{$c=Read-Config;if($d.ShowDialog() -eq 'OK'){if([IO.File]::Exists($d.FileName)){throw '请使用新的文件名，不覆盖原配置。'};$bytes=[Text.Encoding]::UTF8.GetBytes(($c|ConvertTo-Json -Depth 12));$f=[IO.File]::Open($d.FileName,[IO.FileMode]::CreateNew);try{$f.Write($bytes,0,$bytes.Length)}finally{$f.Dispose()};Log '已另存配置。'}}catch{Log $_.Exception.Message}finally{$d.Dispose()}
})
[void](Button $bg '状态演练' 206 560 92 {
 $d=New-Object Windows.Forms.OpenFileDialog;$d.Filter='离线状态JSON|*.json';try{$c=Read-Config;if($d.ShowDialog() -eq 'OK'){$snap=Get-Content -LiteralPath $d.FileName -Raw -Encoding UTF8|ConvertFrom-Json;$session=New-SuiteSession $c ([string]$snap.Role.Id);$plan=@(Get-SuitePlan $session $snap 0);Log ('状态：'+$session.State+'；'+$session.Reason);foreach($a in $plan){Log ('[未执行] '+$a.Kind+' / '+$a.Name+' / '+$a.Reason)};if(-not $plan.Count){Log '无动作建议；没有向游戏发送操作。'}}}catch{Log $_.Exception.Message}finally{$d.Dispose()}
})
[void](Button $bg '读取诊断' 304 560 96 {
 $path=Join-Path $PSScriptRoot 'RoleReader\OpenRoleReader.cmd';if(Test-Path -LiteralPath $path){Start-Process -FilePath $path}else{Log '请使用已提供的RoleReader诊断器；实时适配尚未完成。'}
})
$foot=Text $bg '角色读取待连接 · 操作接口尚未接入' 10 714 390 25;$foot.TextAlign='MiddleCenter';$foot.ForeColor=$light
function Disconnect-Live([string]$Reason){
 if($script:LiveReader){$script:LiveReader.Dispose();$script:LiveReader=$null}
 $script:LiveInfo=$null;$connection.Text='角色数据：未连接';$foot.Text='角色读取停止 · 操作接口尚未接入';Log $Reason
}
[void](Button $bg '连接角色数据' 278 72 120 {
 $d=New-Object Windows.Forms.OpenFileDialog;$d.Filter='第二步引用报告|*.json'
 try{
  if($d.ShowDialog() -ne 'OK'){return}
  $r=Get-Content -LiteralPath $d.FileName -Raw -Encoding UTF8|ConvertFrom-Json
  if($r.Error){throw '该报告包含诊断错误。'}
  $candidates=@($r.References|Where-Object{$_.Score -eq 2 -and @($_.HpValueMatches).Count -eq 2 -and @($_.MpValueMatches).Count -eq 2})
  if($candidates.Count -ne 1){throw '报告中没有唯一的两组生命/真气候选，不能直接连接。'}
  $candidate=$candidates[0];[long[]]$hpAddress=@($candidate.HpValueMatches|Sort-Object);[long[]]$mpAddress=@($candidate.MpValueMatches|Sort-Object)
  Disconnect-Live '切换读取会话'
  $script:LiveReader=[PWStatsReader]::Open([int]$r.ProcessId,[long]$r.ProcessStartTicks,[string]$r.Name,[long]$candidate.Address,[long]$candidate.NameAddress,$hpAddress,$mpAddress)
  $script:LiveInfo=[pscustomobject]@{Name=[string]$r.Name;PidValue=[int]$r.ProcessId}
  $foot.Text='当前会话：A当前值 / B上限（按现有报告接入）'
  Log '已连接角色数据；未写内存，未发送游戏操作。'
 }catch{Disconnect-Live $_.Exception.Message}finally{$d.Dispose()}
})
$liveTimer=New-Object Windows.Forms.Timer;$liveTimer.Interval=500
$liveTimer.Add_Tick({
 if(-not $script:LiveReader){return}
 try{
  $value=$script:LiveReader.Read()
  if($value.HpB -le 0 -or $value.MpB -le 0 -or $value.HpA -gt $value.HpB -or $value.MpA -gt $value.MpB){throw '当前值/上限关系不成立，已停止使用这组数据。'}
  $connection.Text='角色：'+$value.Name+[Environment]::NewLine+'生命 '+$value.HpA+'/'+$value.HpB+'  真气 '+$value.MpA+'/'+$value.MpB
 }catch{Disconnect-Live $_.Exception.Message}
})
$form.Add_FormClosing({$liveTimer.Stop();if($script:LiveReader){$script:LiveReader.Dispose();$script:LiveReader=$null}})
try{Show-Config (New-SuiteConfig);Log '六页配置已加载；点击上方连接角色数据，载入已有第二步报告。';$liveTimer.Start();[void]$form.ShowDialog()}finally{$liveTimer.Stop();$liveTimer.Dispose();if($script:LiveReader){$script:LiveReader.Dispose()};$form.Dispose()}

