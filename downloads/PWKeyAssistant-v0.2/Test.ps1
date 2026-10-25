$ErrorActionPreference='Stop'
$r=$PSScriptRoot
foreach($name in @('Assistant.ps1','Core.ps1')){$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $r $name),[ref]$tokens,[ref]$errors);if($errors.Count){throw ($errors|Out-String)}}
. "$r/Core.ps1"
function Assert($Value,$Text){if(-not $Value){throw $Text}}
$config=Get-Content "$r/default-config.json" -Raw|ConvertFrom-Json
Assert-KeyConfig $config
Assert ((Get-KeyCode 'TAB') -eq 9) 'TAB mapping failed'
Assert ((Get-KeyCode '1') -eq 49) 'Digit mapping failed'
Assert ((Get-KeyCode 'f12') -eq 123) 'Function key mapping failed'
foreach($name in @('F9','F8','ENTER','ALT','A')){$fail=$false;try{Get-KeyCode $name|Out-Null}catch{$fail=$true};Assert $fail "Reserved/unsupported key accepted: $name"}
$s=@(New-KeySchedule $config 0);Assert ($s.Count -eq 2) 'Disabled action scheduled'
$a=Get-DueKey $s 500;Assert ($a.Key -eq 'TAB') 'First action wrong'
$a=Get-DueKey $s 700;Assert ($a.Key -eq '1') 'Second action wrong'
$a=Get-DueKey $s 100000;Assert ($a.DueMs -gt 100000) 'Late tick generated catch-up backlog'
$config.Actions=@([pscustomobject]@{Enabled=$true;Name='fast';Key='1';IntervalMs=200},[pscustomobject]@{Enabled=$true;Name='slow';Key='2';IntervalMs=200})
$s=@(New-KeySchedule $config 0);$seen=@();for($time=0;$time -le 1000;$time+=200){$a=Get-DueKey $s $time;$seen+=$a.Key};Assert ($seen -contains '1' -and $seen -contains '2') 'Scheduler starved an action'
$config.Actions[0].IntervalMs=0;$fail=$false;try{Assert-KeyConfig $config}catch{$fail=$true};Assert $fail 'Zero interval accepted'
Add-Type -Path "$r/Native.cs"
$expected=if([IntPtr]::Size -eq 8){40}else{28}
Assert ([PWKeyNative]::InputSize() -eq $expected) 'INPUT structure ABI size mismatch'
'PASS: PowerShell syntax; C# compile; INPUT ABI size; key whitelist; emergency key reserved; disabled actions; scheduler priority/fairness; no catch-up bursts; invalid interval rejection. No native Windows APIs executed.'

Assert ((Get-ActivationDecision $false 10 30000) -eq 'Waiting') 'Background window activated'
Assert ((Get-ActivationDecision $true 10 30000) -eq 'Ready') 'Focused window did not activate'
Assert ((Get-ActivationDecision $true 30000 30000) -eq 'Timeout') 'Expired start request activated'
'PASS: manual foreground activation; pending timeout.'
