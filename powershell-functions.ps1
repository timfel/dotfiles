# Global variables
$DevDirectory = "D:"

<# Initial setup

Install-PackageProvider Nuget –Force -Scope CurrentUser
Install-Module PowerShellGet -Scope CurrentUser -Force -AllowClobber
Set-ExecutionPolicy -ExecutionPolicy Bypass -Force -Scope CurrentUser
Install-Module posh-git
Install-Module modern-unix-win

winget install "Windows Subsystem for Linux Preview"
winget install Microsoft.WindowsTerminal.Preview
winget install Canonical.Ubuntu.2204
winget install Mozilla.Firefox
winget install SlackTechnologies.Slack
winget install Discord.Discord
winget install Zoom.Zoom
winget install Git.Git
winget install Python.Python.3.12
winget install Microsoft.VisualStudio.2022.BuildTools
winget install Microsoft.VisualStudioCode
winget install Oracle.JDK.21
winget install JetBrains.IntelliJIDEA.Community
winget install Kitware.CMake
winget install GNU.Emacs
winget install RedHat.Podman
winget install gsudo
winget install Clement.bottom
winget install keepass

git clone https://github.com/timfel/my_emacs_for_rails.git $env:APPDATA/.emacs.d
git clone https://github.com/timfel/dotfiles.git $env:APPDATA/dotfiles
sudo New-Item -Path $env:USERPROFILE/.gitconfig -ItemType SymbolicLink -Value $env:APPDATA/dotfiles/.gitconfig
sudo New-Item -Path $profile.CurrentUserCurrentHost -ItemType SymbolicLink -Value $env:APPDATA/dotfiles/powershell-functions.ps1

#>

Import-Module posh-git
Import-Module modern-unix-win
Enable-ModernUnixCompletions
set-alias cat bat -Option AllScope
set-alias df duf
set-alias du dust
set-alias diff delta -Option AllScope -Force
set-alias find fd
set-alias ls lsd -Option AllScope
set-alias grep rg
set-alias sed sd
set-alias ps procs -Option AllScope
set-alias curl curlie -Option AllScope
set-alias which Get-Command
set-alias unzip Expand-Archive
set-alias zip Compress-Archive

function time {
    hyperfine -r 1 $args
}

function ln {
    [CmdletBinding()]
    param (
        [switch]$s,
        [Parameter(Mandatory, Position=0)]
        [string]$Target,
        [Parameter(Mandatory, Position=1)]
        [string]$LinkName
    )

    if ($s) {
        New-Item -Path $LinkName -ItemType SymbolicLink -Value $Target
    } else {
        New-Item -Path $LinkName -ItemType HardLink -Value $Target
    }
}

function htop {
    btm -b --battery --mem_as_value -n
}

function Get-InternetProxy {
    $proxies = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').proxyServer
    $wpad = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').AutoConfigURL
    if ($proxies) {
        if ($proxies -ilike "*=*") {
            $proxies -replace "=","://" -split(';') | Select-Object -First 1
        } else {
            "http://" + $proxies
        }
    } elseif ($wpad) {
        Write-Host "No proxy defined, checking $wpad"
        $wpadContent=(iwr $wpad).RawContent
        if ($wpadContent -match "PROXY ([^ ;]+)") {
            "http://" + $Matches.1
        }
    } else {
        Write-Host "No proxies"
        ""
    }
}

function sproxy {
    $proxy = Get-InternetProxy
    $env:http_proxy=$proxy
    $env:https_proxy=$proxy
}

function Tim-Install-Maven {
    $mvn_version = "3.9.6"

    wget https://dlcdn.apache.org/maven/maven-3/$mvn_version/binaries/apache-maven-$mvn_version-bin.zip -OutFile $env:USERPROFILE/apache-maven-$mvn_version-bin.zip
    Expand-Archive $env:USERPROFILE/apache-maven-$mvn_version-bin.zip -DestinationPath $env:USERPROFILE/apache-maven-$mvn_version-bin
    rm $env:USERPROFILE/apache-maven-$mvn_version-bin.zip
    mv $env:USERPROFILE/apache-maven-$mvn_version-bin $DevDirectory/apache-maven
    mv $DevDirectory/apache-maven/apache-maven-$mvn_version/* $DevDirectory/apache-maven/
    rmdir $DevDirectory/apache-maven/apache-maven-$mvn_version
}

function Tim-Get-Graal-Repos {
    git clone https://github.com/graalvm/mx $DevDirectory/mx
    git clone https://github.com/oracle/graalpython $DevDirectory/graalpython
}

$Env:MX_CACHE_DIR="$DevDirectory\mx_cache"
$Env:PIP_CACHE_DIR="$DevDirectory\pip_cache"
$Env:PATH+=";$DevDirectory\mx"
$Env:PATH+=";$DevDirectory\apache-maven\bin"
