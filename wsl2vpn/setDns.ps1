echo "Setting DNS"
Start-Sleep -s 5
$dnsServers = (Get-NetAdapter | Where-Object InterfaceDescription -like "Cisco AnyConnect*" | Get-DnsClientServerAddress).ServerAddresses -join ','
$searchSuffix = (Get-DnsClientGlobalSetting).SuffixSearchList -join ','

echo dnsservers: $dnsServers
echo searchSuffix: $searchSuffix

function set-DnsWsl($distro) {
    echo $distro
    copy $PSScriptRoot\wsl_dns.py \\wsl$\$distro\tmp
    if ( $dnsServers ) {
        wsl.exe -d $distro -u root python3 /tmp/wsl_dns.py --servers $dnsServers --search $searchSuffix
    }
    else {
        wsl.exe -d $distro -u root python3 /tmp/wsl_dns.py
    }
}

set-DnsWsl Ubuntu

Start-Sleep -s 10 # Allow time to view the output before window closes
