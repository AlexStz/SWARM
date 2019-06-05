function Global:Get-Watts {
    if (-not $Global:Watts) { $global:Watts = Get-Content ".\config\power\power.json" | ConvertFrom-Json }
    if($global:Config.params.kwh -ne "") {
        $global:WattHour = $global:Config.Params.kwh
    } else { $global:WattHour = $global:Watts.KWh.$((Get-Date | Select-Object hour).Hour) }
}

function Global:Get-Pricing {
    $AllProtocols = [System.Net.SecurityProtocolType]'Tls,Tls11,Tls12' 
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
    try {
        Global:Write-Log "SWARM Is Building The Database. Auto-Coin Switching: $($global:Config.Params.Auto_Coin)" -foreground "yellow"
        $global:Rates = Invoke-RestMethod "https://api.coinbase.com/v2/exchange-rates?currency=BTC" -UseBasicParsing | Select-Object -ExpandProperty data | Select-Object -ExpandProperty rates | Select-Object "$($global:Config.Params.Currency)"
        $global:WattEX = [Double](((1 / $global:Rates.$($global:Config.Params.Currency)) * $global:WattHour))
    }
    catch {
        Global:Write-Log "WARNING: Coinbase Unreachable. " -ForeGroundColor Yellow
    }
}

function Global:Clear-Timeouts {
    if ($global:TimeoutTimer.Elapsed.TotalSeconds -gt $global:TimeoutTime -and $global:Config.Params.Timeout -ne 0) {
        Global:Write-Log "Clearing Timeouts" -ForegroundColor Magenta; 
        if (Test-Path ".\timeout") { 
            Remove-Item ".\timeout" -Recurse -Force
        }
        $global:TimeoutTimer.Restart()  
    }
}