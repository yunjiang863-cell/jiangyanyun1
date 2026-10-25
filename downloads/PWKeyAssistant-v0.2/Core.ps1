$ErrorActionPreference='Stop'
function Get-KeyCode([string]$Name) {
    $n=$Name.ToUpperInvariant()
    if($n -match '^[1-9]$'){return [int][char]$n}
    if($n -match '^F([1-7]|1[0-2])$'){return (0x70+[int]$Matches[1]-1)}
    if($n -eq 'TAB'){return 9}
    if($n -eq 'SPACE'){return 32}
    throw '按键只支持 1-9、F1-F7、F10-F12、TAB、SPACE；F9 为停止键。'
}
function Assert-KeyConfig($Config) {
    if($null -eq $Config -or $Config.Version -ne 2){throw '不支持的配置版本。'}
    if(@($Config.Actions).Count -gt 12 -or @($Config.Actions).Count -eq 0){throw '配置应包含1到12项按键。'}
    $active=0
    foreach($a in @($Config.Actions)) {
        if($a.Enabled -isnot [bool]){throw '启用标记无效。'}
        [int]$interval=0
        if(-not [int]::TryParse([string]$a.IntervalMs,[ref]$interval) -or $interval -lt 200 -or $interval -gt 600000){throw '间隔必须为200到600000毫秒。'}
        [void](Get-KeyCode ([string]$a.Key))
        if([string]::IsNullOrWhiteSpace([string]$a.Name) -or ([string]$a.Name).Length -gt 60){throw '动作名称无效。'}
        if($a.Enabled){$active++}
    }
    if($active -eq 0){throw '请至少启用一项按键。'}
}
function New-KeySchedule($Config,[long]$NowMs){
    Assert-KeyConfig $Config
    $n=0;$items=@()
    foreach($a in @($Config.Actions)){
        if($a.Enabled){$items += [pscustomobject]@{Name=[string]$a.Name;Key=[string]$a.Key;Code=(Get-KeyCode $a.Key);IntervalMs=[int]$a.IntervalMs;DueMs=($NowMs+$n*200)};$n++}
    }
    return $items
}
function Get-DueKey($Schedule,[long]$NowMs){
    # Select one due action; never replay accumulated actions after a pause.
    $due=@($Schedule | Where-Object { $_.DueMs -le $NowMs } | Sort-Object DueMs | Select-Object -First 1)
    if($due.Count){$a=$due[0];$a.DueMs=$NowMs+$a.IntervalMs;return $a}
    return $null
}

function Get-ActivationDecision([bool]$Focused,[long]$NowMs,[long]$DeadlineMs){
    if($NowMs -ge $DeadlineMs){return 'Timeout'}
    if($Focused){return 'Ready'}
    return 'Waiting'
}
