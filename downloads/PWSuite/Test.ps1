$ErrorActionPreference='Stop'
$r=$PSScriptRoot
foreach($file in @('Rules.ps1','Suite.ps1')){$t=$null;$e=$null;[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $r $file),[ref]$t,[ref]$e);if($e.Count){throw($e|Out-String)}}
. "$r/Rules.ps1"
function Assert($Value,[string]$Text){if(-not $Value){throw $Text}}
function StateCopy{return (Get-Content "$r/example-state.json" -Raw -Encoding UTF8|ConvertFrom-Json)}
$c=New-SuiteConfig;Assert-SuiteConfig $c;$snap=StateCopy;$s=New-SuiteSession $c 'demo-role';$plan=@(Get-SuitePlan $s $snap 0)
Assert ($s.State -eq 'Running') ('Default config failed: '+$s.Reason)
Assert (@($plan|Where-Object{$_.Kind -eq 'Protection'}).Count -eq 2) 'Percentage protection failed'
Assert (@($plan|Where-Object{$_.Kind -eq 'MaintainStatus'}).Count -eq 3) 'Status maintenance failed'
Assert (@($plan|Where-Object{$_.Kind -eq 'CastSkill' -and $_.Name -eq '羽箭'}).Count -eq 1) 'Skill loop priority failed'
Assert (@($plan|Where-Object{$_.Executed -ne $false}).Count -eq 0) 'Plan claims executed action'
Assert (@(Get-SuitePlan $s $snap 1).Count -eq 0) 'Cooldown failed'
$c.Skills.FirstEnabled=$true;$c.Skills.FirstName='龙卷风';$s=New-SuiteSession $c 'demo-role';$plan=@(Get-SuitePlan $s $snap 0);Assert (($plan|Where-Object{$_.Kind -eq 'CastSkill'}).Name -eq '龙卷风') 'First skill failed'
$plan=@(Get-SuitePlan $s $snap 3);Assert (($plan|Where-Object{$_.Kind -eq 'CastSkill'}).Name -eq '羽箭') 'First skill repeated'
$c=New-SuiteConfig;$c.Skills.FarEnabled=$true;$c.Skills.FarDistance=3;$c.Skills.FarName='龙卷风';$s=New-SuiteSession $c 'demo-role';$plan=@(Get-SuitePlan $s $snap 0);Assert (($plan|Where-Object{$_.Kind -eq 'CastSkill'}).Name -eq '龙卷风') 'Far skill failed'
$c=New-SuiteConfig;$c.Target.HeightEnabled=$true;$c.Target.MaxHeight=3;$snap=StateCopy;$snap.Mobs[0].Y=110;$s=New-SuiteSession $c 'demo-role';$plan=@(Get-SuitePlan $s $snap 0);Assert (($plan|Where-Object{$_.Kind -eq 'SelectTarget'}).TargetId -eq 'mob-2') 'Height filter failed'
$c=New-SuiteConfig;$snap=StateCopy;$snap.Mobs[0].X=100;$s=New-SuiteSession $c 'demo-role';$plan=@(Get-SuitePlan $s $snap 0);Assert (($plan|Where-Object{$_.Kind -eq 'SelectTarget'}).TargetId -eq 'mob-2') 'Range filter failed'
$c=New-SuiteConfig;$snap=StateCopy;$s=New-SuiteSession $c 'demo-role';[void](Get-SuitePlan $s $snap 0);$plan=@(Get-SuitePlan $s $snap 31);Assert (($plan|Where-Object{$_.Kind -eq 'SelectTarget'}).TargetId -eq 'mob-2') 'Timeout retarget failed'
$c=New-SuiteConfig;$c.Control.Pickup=$true;$c.Pickup.Enabled=$true;$c.Pickup.Mode='只捡列表';$c.Pickup.Names=@('测试材料');$snap=StateCopy;$s=New-SuiteSession $c 'demo-role';$plan=@(Get-SuitePlan $s $snap 0);Assert (@($plan|Where-Object{$_.Kind -eq 'Pickup'}).Count -eq 1) 'Pickup whitelist failed'
$snap.GroundItems[0].X=10;$c.Pickup.RunTo=$true;$s=New-SuiteSession $c 'demo-role';$plan=@(Get-SuitePlan $s $snap 0);Assert (@($plan|Where-Object{$_.Kind -eq 'MoveToItem'}).Count -eq 1) 'Run-to-item plan failed'
$snap.BagFull=$true;$s=New-SuiteSession $c 'demo-role';$plan=@(Get-SuitePlan $s $snap 0);Assert (@($plan|Where-Object{$_.Kind -in @('Pickup','MoveToItem')}).Count -eq 0) 'Full bag permitted pickup'
foreach($case in @('disconnect','switch','dead','bad-coordinate','bad-health')){$c=New-SuiteConfig;$snap=StateCopy;$s=New-SuiteSession $c 'demo-role';switch($case){'disconnect'{$snap.Connected=$false};'switch'{$snap.Role.Id='other'};'dead'{$snap.Role.Hp=0};'bad-coordinate'{$snap.Role.X='NaN'};'bad-health'{$snap.Role.MaxHp=0}};$p=@(Get-SuitePlan $s $snap 0);Assert ($p.Count -eq 0 -and $s.State -eq 'Stopped') "Unsafe case not stopped: $case"}
$c=New-SuiteConfig;$c.Target.AboveEnabled=$true;$c.Target.BelowEnabled=$true;$c.Target.AboveLevel=5;$c.Target.BelowLevel=10;$fail=$false;try{Assert-SuiteConfig $c}catch{$fail=$true};Assert $fail 'Conflicting level range accepted'
$snap=StateCopy;$c=New-SuiteConfig;$s=New-SuiteSession $c 'demo-role';$s.State='Paused';Assert (@(Get-SuitePlan $s $snap 0).Count -eq 0) 'Paused session emitted actions'
$snap.Connected=$false;Assert (@(Get-SuitePlan $s $snap 0).Count -eq 0 -and $s.State -eq 'Stopped') 'Paused disconnect not stopped'
'PASS: syntax; percentage protection; state maintenance; first/far/loop skills; cooldown; height and range filters; timeout retarget; pickup whitelist and movement; full bag; disconnect; character switch; death; invalid data; conflicting settings; paused behavior. No game operations executed.'

$c=New-SuiteConfig;$snap=StateCopy;$s=New-SuiteSession $c 'demo-role';[void](Get-SuitePlan $s $snap 0);[void](Get-SuitePlan $s $snap 31);$p=@(Get-SuitePlan $s $snap 34);Assert (@($p|Where-Object{$_.Kind -eq 'CastSkill'}).Count -eq 0) 'Retarget proposal falsely treated as applied'
Assert ($s.TargetId -eq 'mob-1') 'Actual target overwritten by unexecuted proposal'
$c=New-SuiteConfig;$c.Target.Mode='不选列表';$c.Target.Names=@('白眼狼');$snap=StateCopy;$s=New-SuiteSession $c 'demo-role';$p=@(Get-SuitePlan $s $snap 0);Assert (($p|Where-Object{$_.Kind -eq 'SelectTarget'}).TargetId -eq 'mob-2') 'Blacklist failed'
$c=New-SuiteConfig;$c.Target.AboveEnabled=$true;$c.Target.AboveLevel=9;$s=New-SuiteSession $c 'demo-role';$p=@(Get-SuitePlan $s $snap 0);Assert (@($p|Where-Object{$_.Kind -in @('SelectTarget','CastSkill')}).Count -eq 0) 'Level filter failed'
$c=New-SuiteConfig;$c.Skills.NearEnabled=$true;$c.Skills.NearDistance=10;$c.Skills.NearName='龙卷风';$s=New-SuiteSession $c 'demo-role';$p=@(Get-SuitePlan $s $snap 0);Assert (($p|Where-Object{$_.Kind -eq 'CastSkill'}).Name -eq '龙卷风') 'Near skill failed'
$c=New-SuiteConfig;$c.Skills.Loop=@();$c.Skills.BasicAttack=$true;$s=New-SuiteSession $c 'demo-role';$p=@(Get-SuitePlan $s $snap 0);Assert (@($p|Where-Object{$_.Kind -eq 'BasicAttack'}).Count -eq 1) 'Basic attack fallback failed'
$c=New-SuiteConfig;$c.Protection.SummonPet=$true;$c.Protection.PetName='测试宠物';$c.Status.Cleanse=$true;$c.Status.CleanseName='解除昏迷';$c.Status.RedCharm=$true;$c.Status.BlueCharm=$true;$c.Status.FairyQi=$true;$snap=StateCopy;$snap.Stunned=$true;$snap.RedCharmNeedsReplace=$true;$snap.BlueCharmNeedsReplace=$true;$snap.ReadyActions+=@('测试宠物','更换红符','更换蓝符','仙气');$snap.ReadySkills+=@('解除昏迷');$s=New-SuiteSession $c 'demo-role';$p=@(Get-SuitePlan $s $snap 0);Assert (@($p|Where-Object{$_.Kind -eq 'SummonPet'}).Count -eq 1) 'Pet summon failed';Assert (@($p|Where-Object{$_.Kind -eq 'Cleanse'}).Count -eq 1) 'Cleanse failed';Assert (@($p|Where-Object{$_.Kind -eq 'MaintainStatus' -and $_.Name -in @('更换红符','更换蓝符','仙气')}).Count -eq 3) 'Charm/qi rules failed'
$c=New-SuiteConfig;$c.Control.Pickup=$true;$c.Pickup.IgnoreCoins=$true;$snap=StateCopy;$s=New-SuiteSession $c 'demo-role';$p=@(Get-SuitePlan $s $snap 0);Assert (@($p|Where-Object{$_.Kind -eq 'Pickup' -and $_.Name -eq '金币'}).Count -eq 0) 'Coin filter failed'
'PASS: retarget acknowledgement behavior; blacklist; level exclusion; near skills; basic attack; pet; cleanse; charm replacement; qi maintenance; coin filter.'
