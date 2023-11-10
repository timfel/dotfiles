Import-Module posh-git
Import-Module modern-unix-win
Enable-ModernUnixCompletions
set-alias cat bat -Option AllScope
set-alias df duf
set-alias ls lsd -Option AllScope
set-alias grep rg
set-alias sed sd
set-alias which Get-Command
set-alias unzip Expand-Archive

function Get-InternetProxy {
    $proxies = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').proxyServer
    if ($proxies) {
        if ($proxies -ilike "*=*") {
            $proxies -replace "=","://" -split(';') | Select-Object -First 1
        } else {
            "http://" + $proxies
        }
    }
}

function Set-ProxyEnv {
    $proxy = Get-InternetProxy
    $env:http_proxy=$proxy
    $env:https_proxy=$proxy
}
