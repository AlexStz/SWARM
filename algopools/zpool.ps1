$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName 
$Zpool_Request = [PSCustomObject]@{ } 
$Meets_Threshold = $true

if($(arg).xnsub -eq "Yes"){$X = "#xnsub"} 
 
if ($Name -in $(arg).PoolName) {
    try { $Zpool_Request = Invoke-RestMethod "http://www.zpool.ca/api/status" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop } 
    catch { log "SWARM contacted ($Name) but there was no response."; return }
  
    if (($Zpool_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) { 
        log "SWARM contacted ($Name) but ($Name) the response was empty." 
        return
    } 
   
    Switch ($(arg).Location) {
        "US" { $region = "na" }
        "EUROPE" { $region = "eu" }
        "ASIA" { $region = "sea" }
    }
  
    $Zpool_Request | 
    Get-Member -MemberType NoteProperty -ErrorAction Ignore | 
    Select-Object -ExpandProperty Name | 
    Where-Object { [Double]$Zpool_Request.$_.estimate_current -gt 0 } |
    Where-Object {
        $Algo = $Zpool_Request.$_.name.ToLower();
        $local:Zpool_Algorithm = $global:Config.Pool_Algos.PSObject.Properties.Name | Where { $Algo -in $global:Config.Pool_Algos.$_.alt_names }
        return $Zpool_Algorithm
    } |
    ForEach-Object {
        if ($(vars).Algorithm -contains $Zpool_Algorithm -or $(arg).ASIC_ALGO -contains $Zpool_Algorithm) {
            if ($Name -notin $global:Config.Pool_Algos.$Zpool_Algorithm.exclusions -and $Zpool_Algorithm -notin $(vars).BanHammer) {

                $StatAlgo = $Zpool_Algorithm -replace "`_", "`-"
                $StatPath = ".\stats\($Name)_$($StatAlgo)_profit.txt"
                if(Test-Path $StatPath) { $Estimate = [Double]$Zpool_Request.$_.estimate_current }
                $Estimate = [Double]$Zpool_Request.$_.estimate_current

                if ($(arg).mode -eq "easy") {
                    if( $Zpool_Request.$_.actual_last24h -eq 0 ){ $Meets_Threshold = $false } else {$Meets_Threshold = $True}
                    $Shuffle = Shuffle $Zpool_Request.$_.estimate_current $Zpool_Request.$_.actual_last24h
                } else {$Meets_Threshold = $true}

                $Zpool_Port = $Zpool_Request.$_.port
                $Zpool_Host = "$($Zpool_Request.$_.name.ToLower()).$($region).mine.zpool.ca$X"
                $Divisor = 1000000 * $Zpool_Request.$_.mbtc_mh_factor
                $(vars).divisortable.zpool.Add($Zpool_Algorithm, $Zpool_Request.$_.mbtc_mh_factor)
                $(vars).FeeTable.zpool.Add($Zpool_Algorithm, $Zpool_Request.$_.fees)
                $Hashrate = $zpool_Request.$_.hashrate_shared
                $previous = [Math]::Max(([Double]$zpool_Request.$_.actual_last24h * 0.001)  / $Divisor * (1 - ($zpool_Request.$_.fees / 100)),$SmallestValue)

                $Stat = Global:Set-Stat -Name "$($Name)_$($StatAlgo)_profit" -HashRate $HashRate -Value ( $Estimate / $Divisor * (1 - ($Zpool_Request.$_.fees / 100))) -Shuffle $Shuffle
                if (-not $(vars).Pool_Hashrates.$Zpool_Algorithm) { $(vars).Pool_Hashrates.Add("$Zpool_Algorithm", @{ }) }
                if (-not $(vars).Pool_Hashrates.$Zpool_Algorithm.$Name) { $(vars).Pool_Hashrates.$Zpool_Algorithm.Add("$Name", @{HashRate = "$($Stat.HashRate)"; Percent = "" }) }

                $Level = $Stat.$($(arg).Stat_Algo)
                if($(arg).mode -eq "easy") {
                    $SmallestValue = 1E-20 
                    $Level = [Math]::Max($Level + ($Level * $Stat.Deviation), $SmallestValue)
               }
     
                $Pass1 = $global:Wallets.Wallet1.Keys
                $User1 = $global:Wallets.Wallet1.$($(arg).Passwordcurrency1).address
                $Pass2 = $global:Wallets.Wallet2.Keys
                $User2 = $global:Wallets.Wallet2.$($(arg).Passwordcurrency2).address
                $Pass3 = $global:Wallets.Wallet3.Keys
                $User3 = $global:Wallets.Wallet3.$($(arg).Passwordcurrency3).address

                if ($global:Wallets.AltWallet1.keys) {
                    $global:Wallets.AltWallet1.Keys | ForEach-Object {
                        if ($global:Wallets.AltWallet1.$_.Pools -contains $Name) {
                            $Pass1 = $_;
                            $User1 = $global:Wallets.AltWallet1.$_.address;
                        }
                    }
                }
                if ($global:Wallets.AltWallet2.keys) {
                    $global:Wallets.AltWallet2.Keys | ForEach-Object {
                        if ($global:Wallets.AltWallet2.$_.Pools -contains $Name) {
                            $Pass2 = $_;
                            $User2 = $global:Wallets.AltWallet2.$_.address;
                        }
                    }
                }
                if ($global:Wallets.AltWallet3.keys) {
                    $global:Wallets.AltWallet3.Keys | ForEach-Object {
                        if ($global:Wallets.AltWallet3.$_.Pools -contains $Name) {
                            $Pass3 = $_;
                            $User3 = $global:Wallets.AltWallet3.$_.address;
                        }
                    }
                }
                
                [PSCustomObject]@{
                    Symbol    = "$Zpool_Algorithm-Algo"
                    Algorithm = $Zpool_Algorithm
                    Price     = $Level
                    Protocol  = "stratum+tcp"
                    Host      = $Zpool_Host
                    Port      = $Zpool_Port
                    User1     = $User1
                    User2     = $User2
                    User3     = $User3
                    Pass1     = "c=$Pass1,id=$($(arg).RigName1)"
                    Pass2     = "c=$Pass2,id=$($(arg).RigName2)"
                    Pass3     = "c=$Pass3,id=$($(arg).RigName3)"
                    Meets_Threshold = $Meets_Threshold
                    Previous = $previous
                }
            }
        }
    }
}
