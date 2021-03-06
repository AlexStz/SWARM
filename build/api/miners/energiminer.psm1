function Global:Get-StatsEnergiminer {
    try { $Request = Get-Content ".\logs\$MinerType.log" -ErrorAction Stop }catch { }
    if ($Request) {
        $Data = $Request | Select-String "Mh/s" | Select-Object -Last 1
        $Data = $Data -split " ";
        $MHS = $Data | Select-String -Pattern "Mh/s" -AllMatches -Context 1, 0 | ForEach-Object { $_.Context.PreContext[0] }
        $MHS = $MHS -replace '\x1b\[[0-9;]*m', ''
        $global:RAW = [Double]$MHS * 1000000
        Global:Write-MinerData2;
        $global:GPUKHS += [Double]$MHS * 1000
        $Hash = $Data | Select-String -Pattern "GPU/" -AllMatches -Context 0, 1
        $Hash = $Hash -replace '\x1b\[[0-9;]*m', '' | ForEach-Object { $_ -split ' ' | Select-Object -skip 3 -first 1 }
        try { for ($global:i = 0; $global:i -lt $Devices.Count; $global:i++) { $global:GPUHashrates.$(Global:Get-GPUs) = (Global:Set-Array $Hash $global:i) } }catch { Write-Host "Failed To parse GPU Threads" -ForegroundColor Red };
        $global:MinerACC = $($Request | Select-String "Accepted").count
        $global:MinerREJ = $($Request | Select-String "Rejected").count
        $global:ALLACC += $global:MinerACC
        $global:ALLREJ += $global:MinerREJ
    }
    else { Global:Set-APIFailure }
}