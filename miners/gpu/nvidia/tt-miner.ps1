$Global:NVIDIATypes | ForEach-Object {
    
    $ConfigType = $_; $Num = $ConfigType -replace "NVIDIA", ""

    $CName = "tt-miner"

    ##Miner Path Information
    if ($Global:nvidia.$CName.$ConfigType -and $global:Config.Params.Platform -eq "windows") { $Path = "$($Global:nvidia.$CName.$ConfigType)" }
    else { $Path = "None" }
    if ($Global:nvidia.$CName.uri -and $global:Config.Params.Platform -eq "windows") { $Uri = "$($Global:nvidia.$CName.uri)" }
    else { $Uri = "None" }
    if ($Global:nvidia.$CName.minername) { $MinerName = "$($Global:nvidia.$CName.minername)" }
    else { $MinerName = "None" }

    $User = "User$Num"; $Pass = "Pass$Num"; $Name = "$CName-$Num"; $Port = "5100$Num";

    Switch ($Num) {
        1 { $Get_Devices = $Global:NVIDIADevices1 }
        2 { $Get_Devices = $Global:NVIDIADevices2 }
        3 { $Get_Devices = $Global:NVIDIADevices3 }
    }

    ##Log Directory
    $Log = Join-Path $($global:Dir) "logs\$ConfigType.log"

    ##Parse -GPUDevices
    if ($Get_Devices -ne "none") { $Devices = $Get_Devices }
    else { $Devices = $Get_Devices }

    ##Get Configuration File
    $MinerConfig = $Global:config.miners.$CName

    ##Export would be /path/to/[SWARMVERSION]/build/export##
    $ExportDir = Join-Path $($global:Dir) "build\export"

    ##Prestart actions before miner launch
    $BE = "/usr/lib/x86_64-linux-gnu/libcurl-compat.so.3.0.0"
    $Prestart = @()
    if (Test-Path $BE) { $Prestart += "export LD_PRELOAD=libcurl-compat.so.3.0.0" }
    $PreStart += "export LD_LIBRARY_PATH=$ExportDir"
    $MinerConfig.$ConfigType.prestart | ForEach-Object { $Prestart += "$($_)" }

    if ($Global:Coins -eq $true) { $Pools = $global:CoinPools }else { $Pools = $global:AlgoPools }

    ##Build Miner Settings
    $MinerConfig.$ConfigType.commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {

        $MinerAlgo = $_

        if ($MinerAlgo -in $global:Algorithm -and $Name -notin $global:Config.Pool_Algos.$MinerAlgo.exclusions -and $ConfigType -notin $global:Config.Pool_Algos.$MinerAlgo.exclusions -and $Name -notin $global:banhammer) {
            $StatAlgo = $MinerAlgo -replace "`_","`-"
            $Stat = Get-Stat -Name "$($Name)_$($StatAlgo)_hashrate" 
           $Check = $Global:Miner_HashTable | Where Miner -eq $Name | Where Algo -eq $MinerAlgo | Where Type -Eq $ConfigType

            if ($Check.RAW -ne "Bad") {
                $Pools | Where-Object Algorithm -eq $MinerAlgo | ForEach-Object {
                    if ($_.Worker) { $Worker = "-worker $($_.Worker) " }else { $Worker = $Null }
                    [PSCustomObject]@{
                        MName      = $Name
                        Coin       = $Global:Coins
                        Delay      = $MinerConfig.$ConfigType.delay
                        Fees       = $MinerConfig.$ConfigType.fee.$($_.Algorithm)
                        Symbol     = "$($_.Symbol)"
                        MinerName  = $MinerName
                        Prestart   = $PreStart
                        Type       = $ConfigType
                        Path       = $Path
                        Devices    = $Devices
                        Version    = "$($Global:nvidia.$CName.version)"
                        DeviceCall = "ttminer"
                        Arguments  = "-a $($MinerConfig.$ConfigType.naming.$($_.Algorithm)) --nvidia -o $($_.Protocol)://$($_.Host):$($_.Port) $Worker-b localhost:$Port -u $($_.$User) -p $($_.$Pass) $($MinerConfig.$ConfigType.commands.$($_.Algorithm))"
                        HashRates  = $Stat.Hour
                        Quote      = if ($Stat.Hour) { $Stat.Hour * ($_.Price) }else { 0 }
                        Power     =  if ($global:Watts.$($_.Algorithm)."$($ConfigType)_Watts") { $global:Watts.$($_.Algorithm)."$($ConfigType)_Watts" }elseif ($global:Watts.default."$($ConfigType)_Watts") { $global:Watts.default."$($ConfigType)_Watts" }else { 0 } 
                        MinerPool  = "$($_.Name)"
                        Port       = $Port
                        API        = "claymore"
                        Wallet     = "$($_.$User)"
                        URI        = $Uri
                        Server     = "localhost"
                        Algo       = "$($_.Algorithm)"                         
                        Log        = $Log 
                    }            
                }
            }
        }
    }
}