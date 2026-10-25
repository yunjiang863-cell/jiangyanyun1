$ErrorActionPreference='Stop'
function New-SuiteConfig {
 [pscustomobject]@{
  Version=3
  Control=[pscustomobject]@{Protection=$true;Status=$true;Pickup=$false;SwitchTimeout=$true;SwitchSeconds=30;LimitRange=$true;Range=45;IgnoreReturn=$false}
  Protection=[pscustomobject]@{Rules=@([pscustomobject]@{Enabled=$true;Attribute='生命';Threshold=80;Type='药品';Name='多寿饺子'},[pscustomobject]@{Enabled=$true;Attribute='真气';Threshold=30;Type='药品';Name='多福饺子'});SummonPet=$false;PetName=''}
  Skills=[pscustomobject]@{FirstEnabled=$false;FirstName='';FarEnabled=$false;FarDistance=20;FarName='';NearEnabled=$false;NearDistance=10;NearName='';Loop=@('羽箭','龙卷风');BasicAttack=$false}
  Status=[pscustomobject]@{Names=@('坚甲符','聚神符','仙守符','灵助符');RedCharm=$false;BlueCharm=$false;FairyQi=$false;Cleanse=$false;CleanseName=''}
  Target=[pscustomobject]@{Enabled=$true;Mode='只选列表';Names=@('猛毒行尸','白眼狼','中山狼');AboveEnabled=$false;AboveLevel=5;BelowEnabled=$false;BelowLevel=10;HeightEnabled=$false;MaxHeight=3}
  Pickup=[pscustomobject]@{Enabled=$false;Mode='不捡列表';Names=@();RunTo=$false;IgnoreCoins=$false}
 }
}
function Assert-SuiteConfig($c) {
 if($null -eq $c -or $c.Version -ne 3){throw '不支持的配置版本。'}
 foreach($section in @('Control','Protection','Skills','Status','Target','Pickup')){if($null -eq $c.$section){throw "缺少配置分组：$section"}}
 foreach($pair in @(@($c.Control.SwitchSeconds,1,3600),@($c.Control.Range,1,1000),@($c.Skills.FarDistance,0,1000),@($c.Skills.NearDistance,0,1000),@($c.Target.AboveLevel,0,200),@($c.Target.BelowLevel,0,200),@($c.Target.MaxHeight,0,1000))){[double]$v=0;if(-not [double]::TryParse([string]$pair[0],[ref]$v) -or [double]::IsNaN($v) -or $v -lt $pair[1] -or $v -gt $pair[2]){throw '配置中的距离、等级或时间超出允许范围。'}}
 if($c.Target.Mode -notin @('只选列表','不选列表') -or $c.Pickup.Mode -notin @('只捡列表','不捡列表')){throw '名单模式无效。'}
 if(@($c.Protection.Rules).Count -gt 20){throw '保护规则最多20条。'}
 foreach($r in @($c.Protection.Rules)){
  if($r.Attribute -notin @('生命','真气') -or $r.Type -notin @('药品','技能') -or [string]::IsNullOrWhiteSpace([string]$r.Name)){throw '保护规则中的属性、类型或名称无效。'}
  [double]$v=0;if(-not [double]::TryParse([string]$r.Threshold,[ref]$v) -or [double]::IsNaN($v) -or $v -lt 0 -or $v -gt 100){throw '保护阈值应在0到100之间。'}
 }
 foreach($names in @(@($c.Skills.Loop),@($c.Status.Names),@($c.Target.Names),@($c.Pickup.Names))){if($names.Count -gt 500){throw '名单超过500项。'};foreach($n in $names){if([string]::IsNullOrWhiteSpace([string]$n) -or ([string]$n).Length -gt 100){throw '名单含无效名称。'}}}
 foreach($section in @('Control','Protection','Skills','Status','Target','Pickup')){
  $fields=@{Control=@('Protection','Status','Pickup','SwitchTimeout','LimitRange','IgnoreReturn');Protection=@('SummonPet');Skills=@('FirstEnabled','FarEnabled','NearEnabled','BasicAttack');Status=@('RedCharm','BlueCharm','FairyQi','Cleanse');Target=@('Enabled','AboveEnabled','BelowEnabled','HeightEnabled');Pickup=@('Enabled','RunTo','IgnoreCoins')}
  foreach($key in $fields[$section]){if($c.$section.$key -isnot [bool]){throw "配置中的 $section.$key 必须为布尔值。"}}
 }
 foreach($r in @($c.Protection.Rules)){if($r.Enabled -isnot [bool]){throw '保护规则启用标记无效。'}}
 if($c.Target.AboveEnabled -and $c.Target.BelowEnabled -and $c.Target.BelowLevel -gt $c.Target.AboveLevel){throw '怪物等级范围互相冲突。'}
}
function Read-Number($Object,[string]$Name) {
 if($null -eq $Object -or $null -eq $Object.$Name){throw "状态缺少数值：$Name"}
 [double]$v=0;if(-not [double]::TryParse([string]$Object.$Name,[ref]$v) -or [double]::IsNaN($v) -or [double]::IsInfinity($v)){throw "状态数值无效：$Name"};return $v
}
function Get-Range($a,$b){$dx=(Read-Number $a 'X')-(Read-Number $b 'X');$dz=(Read-Number $a 'Z')-(Read-Number $b 'Z');return [Math]::Sqrt($dx*$dx+$dz*$dz)}
function New-SuiteSession($c,[string]$RoleId){Assert-SuiteConfig $c;if([string]::IsNullOrWhiteSpace($RoleId)){throw '缺少角色ID。'};return [pscustomobject]@{RoleId=$RoleId;State='Running';Reason='离线规则验证';Config=($c|ConvertTo-Json -Depth 12|ConvertFrom-Json);TargetId='';TargetSince=0;FirstDone=$false;LastAt=@{}}}
function Stop-SuiteSession($s,[string]$Reason){$s.State='Stopped';$s.Reason=$Reason}
function Add-SuiteAction($s,$list,[string]$Kind,[string]$Name,[string]$TargetId,[string]$Reason,[long]$Now,[int]$Cooldown=2){
 $key=$Kind+'|'+$Name+'|'+$TargetId
 if($s.LastAt.ContainsKey($key) -and $Now-$s.LastAt[$key] -lt $Cooldown){return $false}
 $s.LastAt[$key]=$Now;[void]$list.Add([pscustomobject]@{Kind=$Kind;Name=$Name;TargetId=$TargetId;Reason=$Reason;Executed=$false});return $true
}
function Get-SuitePlan($s,$snap,[long]$Now=0){
 $out=New-Object 'Collections.Generic.List[object]'
 if($s.State -eq 'Stopped'){return @()}
 try {
  if($null -eq $snap -or $snap.Connected -isnot [bool] -or -not $snap.Connected){Stop-SuiteSession $s '连接中断';return @()}
  if([string]$snap.Role.Id -cne $s.RoleId){Stop-SuiteSession $s '角色切换';return @()}
  $role=$snap.Role;$hp=Read-Number $role 'Hp';$maxHp=Read-Number $role 'MaxHp';$mp=Read-Number $role 'Mp';$maxMp=Read-Number $role 'MaxMp'
  if($maxHp -le 0 -or $maxMp -le 0 -or $hp -lt 0 -or $hp -gt $maxHp -or $mp -lt 0 -or $mp -gt $maxMp){throw '生命/真气范围无效。'}
  if($hp -eq 0 -or $snap.Dead -eq $true){Stop-SuiteSession $s '角色死亡';return @()}
  foreach($axis in @('X','Y','Z')){[void](Read-Number $role $axis)}
  if($s.State -ne 'Running'){return @()}
  $c=$s.Config;$ready=@($snap.ReadyActions);$readySkills=@($snap.ReadySkills)
  if($c.Control.Protection){foreach($r in @($c.Protection.Rules)){if(-not $r.Enabled){continue};$percent=if($r.Attribute -eq '生命'){100*$hp/$maxHp}else{100*$mp/$maxMp};$available=if($r.Type -eq '技能'){$r.Name -in $readySkills}else{$r.Name -in $ready};if($percent -lt $r.Threshold -and $available){[void](Add-SuiteAction $s $out 'Protection' $r.Name '' ($r.Attribute+'低于'+$r.Threshold+'%') $Now)}}}
  if($c.Protection.SummonPet -and $snap.PetSummoned -eq $false -and $c.Protection.PetName -in $ready){[void](Add-SuiteAction $s $out 'SummonPet' $c.Protection.PetName '' '战宠未召唤' $Now 5)}
  if($c.Control.Status){
   foreach($name in @($c.Status.Names)){if($name -notin @($snap.ActiveStatuses) -and $name -in $readySkills){[void](Add-SuiteAction $s $out 'MaintainStatus' $name '' '状态缺失且技能就绪' $Now 5)}}
   foreach($pair in @(@($c.Status.RedCharm,$snap.RedCharmNeedsReplace,'更换红符'),@($c.Status.BlueCharm,$snap.BlueCharmNeedsReplace,'更换蓝符'),@($c.Status.FairyQi,$true,'仙气'))){if($pair[0] -eq $true -and $pair[1] -eq $true -and $pair[2] -in $ready){[void](Add-SuiteAction $s $out 'MaintainStatus' $pair[2] '' '已启用且动作就绪' $Now 5)}}
  }
  if($c.Status.Cleanse -and $snap.Stunned -eq $true -and $c.Status.CleanseName -in $readySkills){[void](Add-SuiteAction $s $out 'Cleanse' $c.Status.CleanseName '' '角色处于昏迷状态' $Now)}
  $actualTarget=[string]$snap.TargetId
  if($actualTarget -cne $s.TargetId){$s.TargetId=$actualTarget;$s.TargetSince=$Now;$s.FirstDone=$false}
  $eligible=@()
  foreach($mob in @($snap.Mobs)){
   if($null -eq $mob -or [string]::IsNullOrWhiteSpace([string]$mob.Id) -or $mob.Alive -ne $true){continue}
   $distance=Get-Range $role $mob;$height=[Math]::Abs((Read-Number $role 'Y')-(Read-Number $mob 'Y'));$level=Read-Number $mob 'Level'
   if($c.Control.LimitRange -and $distance -gt $c.Control.Range){continue}
   if($c.Target.Enabled){$listed=$mob.Name -in @($c.Target.Names);if(($c.Target.Mode -eq '只选列表' -and -not $listed) -or ($c.Target.Mode -eq '不选列表' -and $listed)){continue};if($c.Target.AboveEnabled -and $level -gt $c.Target.AboveLevel){continue};if($c.Target.BelowEnabled -and $level -lt $c.Target.BelowLevel){continue};if($c.Target.HeightEnabled -and $height -gt $c.Target.MaxHeight){continue}}
   $eligible += [pscustomobject]@{Mob=$mob;Distance=$distance}
  }
  $timedOut=$false
  if($s.TargetId -and $c.Control.SwitchTimeout -and $Now-$s.TargetSince -ge $c.Control.SwitchSeconds){$timedOut=$true;$eligible=@($eligible|Where-Object{$_.Mob.Id -ne $s.TargetId})}
  $target=@($eligible|Where-Object{$_.Mob.Id -eq [string]$snap.TargetId}|Select-Object -First 1)
  if(-not $target.Count){$target=@($eligible|Sort-Object Distance|Select-Object -First 1)}
  if($target.Count){
   $t=$target[0];$id=[string]$t.Mob.Id
   if([string]$snap.TargetId -cne $id){[void](Add-SuiteAction $s $out 'SelectTarget' $t.Mob.Name $id '通过名称、等级、距离和高度过滤' $Now)}
   else {
    $skill=''
    if($c.Skills.FirstEnabled -and -not $s.FirstDone -and $c.Skills.FirstName -in $readySkills){$skill=$c.Skills.FirstName;$s.FirstDone=$true}
    elseif($c.Skills.FarEnabled -and $t.Distance -gt $c.Skills.FarDistance -and $c.Skills.FarName -in $readySkills){$skill=$c.Skills.FarName}
    elseif($c.Skills.NearEnabled -and $t.Distance -lt $c.Skills.NearDistance -and $c.Skills.NearName -in $readySkills){$skill=$c.Skills.NearName}
    else{foreach($name in @($c.Skills.Loop)){if($name -in $readySkills){$skill=$name;break}}}
    if($skill){[void](Add-SuiteAction $s $out 'CastSkill' $skill $id '按条件与优先级选择就绪技能' $Now)}elseif($c.Skills.BasicAttack -and '普通攻击' -in $ready){[void](Add-SuiteAction $s $out 'BasicAttack' '普通攻击' $id '技能未就绪，允许普通攻击' $Now)}
   }
  }else{$s.TargetId='';$s.FirstDone=$false}
  if(-not $target.Count -and -not $c.Control.IgnoreReturn -and $snap.ReturnToCenterNeeded -eq $true){[void](Add-SuiteAction $s $out 'ReturnToCenter' '返回中心点' '' '无合格目标且状态报告偏离中心' $Now 5)}
  if($c.Control.Pickup -and $snap.BagFull -eq $false){foreach($item in @($snap.GroundItems)){
   if($null -eq $item -or [string]::IsNullOrWhiteSpace([string]$item.Id)){continue};if($c.Pickup.IgnoreCoins -and $item.IsCoin -eq $true){continue}
   if($c.Pickup.Enabled){$listed=$item.Name -in @($c.Pickup.Names);if(($c.Pickup.Mode -eq '只捡列表' -and -not $listed) -or ($c.Pickup.Mode -eq '不捡列表' -and $listed)){continue}}
   $distance=Get-Range $role $item
   if($distance -le 2){[void](Add-SuiteAction $s $out 'Pickup' $item.Name ([string]$item.Id) '在原地拾取距离内' $Now)}elseif($c.Pickup.RunTo -and (-not $c.Control.LimitRange -or $distance -le $c.Control.Range)){[void](Add-SuiteAction $s $out 'MoveToItem' $item.Name ([string]$item.Id) '允许跑去拾取，需导航接口' $Now 5)}
  }}
 }catch{Stop-SuiteSession $s ('状态不完整或无效：'+$_.Exception.Message);return @()}
 return $out.ToArray()
}

function New-SuiteDemoState {
    return (@'
{
  "Connected": true,
  "Role": {
    "Id": "demo-role",
    "Name": "测试角色",
    "Hp": 700,
    "MaxHp": 1000,
    "Mp": 20,
    "MaxMp": 100,
    "X": 0,
    "Y": 100,
    "Z": 0
  },
  "Dead": false,
  "BagFull": false,
  "PetSummoned": false,
  "Stunned": false,
  "RedCharmNeedsReplace": false,
  "BlueCharmNeedsReplace": false,
  "ReturnToCenterNeeded": false,
  "TargetId": "mob-1",
  "Mobs": [
    {
      "Id": "mob-1",
      "Name": "白眼狼",
      "Level": 10,
      "Alive": true,
      "X": 5,
      "Y": 100,
      "Z": 0
    },
    {
      "Id": "mob-2",
      "Name": "中山狼",
      "Level": 12,
      "Alive": true,
      "X": 10,
      "Y": 100,
      "Z": 0
    }
  ],
  "GroundItems": [
    {
      "Id": "item-1",
      "Name": "测试材料",
      "IsCoin": false,
      "X": 1,
      "Y": 100,
      "Z": 0
    },
    {
      "Id": "coin-1",
      "Name": "金币",
      "IsCoin": true,
      "X": 1,
      "Y": 100,
      "Z": 0
    }
  ],
  "ReadyActions": [
    "多寿饺子",
    "多福饺子",
    "普通攻击"
  ],
  "ReadySkills": [
    "羽箭",
    "龙卷风",
    "聚神符",
    "仙守符",
    "灵助符"
  ],
  "ActiveStatuses": [
    "坚甲符"
  ]
}
'@ | ConvertFrom-Json)
}
