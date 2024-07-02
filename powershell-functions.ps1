# Global variables
$DevDirectory = "D:"

<# Initial setup

# Resize the C partition to make room for a dev drive
$disk_path = (Get-Partition -DriveLetter C).DiskPath
$new_size = (Get-Partition -DriveLetter C).Size - (250*1024*1024*1024)
Resize-Partition -DriveLetter C -Size $new_size
New-Partition -DiskPath "$disk_path" -UseMaximumSize -DriveLetter D
Format-Volume -DriveLetter D -DevDrive
fsutil devdrv trust D:

echo "[wsl2]
memory=58GB
swapFile=0
swap=0
dnsTunneling=true
networkingMode=mirrored
autoProxy=true
firewall=false
useWindowsDnsCache=true
bestEffortDnsParsing=true
" > $env:USERPROFILE/.wslconfig

echo "[system-distro-env]
WESTON_RDPRAIL_SHELL_ALLOW_ZAP=true
" > $env:USERPROFILE/.wslgconfig

Install-PackageProvider Nuget –Force -Scope CurrentUser
Install-Module PowerShellGet -Scope CurrentUser -Force -AllowClobber
Set-ExecutionPolicy -ExecutionPolicy Bypass -Force -Scope CurrentUser
Install-Module posh-git
Install-Module modern-unix-win

winget install Microsoft.Powertoys
winget install Microsoft.WindowsTerminal.Preview
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
winget install gsudo
winget install Clement.bottom
winget install keepass

wsl --update
wsl --install Ubuntu-24.04

git clone https://github.com/timfel/my_emacs_for_rails.git $env:APPDATA/.emacs.d
git clone https://github.com/timfel/dotfiles.git $env:APPDATA/dotfiles
sudo New-Item -Path $env:USERPROFILE/.gitconfig -ItemType SymbolicLink -Value $env:APPDATA/dotfiles/.gitconfig
sudo New-Item -Path $profile.CurrentUserCurrentHost -ItemType SymbolicLink -Value $env:APPDATA/dotfiles/powershell-functions.ps1

mkdir $DevDirectory/patch
cp $env:APPDATA/dotfiles/bin/patch.exe $DevDirectory/patch/patch.exe

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

function Search-StartMenu {
<#

.SYNOPSIS

Search the Start Menu for items that match the provided text. This script
searches both the name (as displayed on the Start Menu itself,) and the
destination of the link.

.DESCRIPTION

PS > Search-StartMenu "Character Map" | Invoke-Item
Searches for the "Character Map" application, and then runs it

PS > Search-StartMenu PowerShell | Select-FilteredObject | Invoke-Item
Searches for anything with "PowerShell" in the application name, lets you pick which one to launch, and then launches it.

 From PowerShell Cookbook (O'Reilly)
 by Lee Holmes (http://www.leeholmes.com/blog)

#>

    param(
        ## The pattern to match
        [Parameter(Mandatory = $true)]
        $Pattern
    )

    Set-StrictMode -Version 3

    ## Get the locations of the start menu paths
    $myStartMenu = [Environment]::GetFolderPath("StartMenu")
    $shell = New-Object -Com WScript.Shell
    $allStartMenu = $shell.SpecialFolders.Item("AllUsersStartMenu")

    ## Escape their search term, so that any regular expression
    ## characters don't affect the search
    $escapedMatch = [Regex]::Escape($pattern)

    ## Search in "my start menu" for text in the link name or link destination
    dir $myStartMenu *.lnk -rec | Where-Object {
        ($_.Name -match "$escapedMatch") -or
        ($_ | Select-String "\\[^\\]*$escapedMatch\." -Quiet)
    }

    ## Search in "all start menu" for text in the link name or link destination
    dir $allStartMenu *.lnk -rec | Where-Object {
        ($_.Name -match "$escapedMatch") -or
        ($_ | Select-String "\\[^\\]*$escapedMatch\." -Quiet)
    }
}

function emacsclient {
    $emacs = Search-StartMenu runemacs
    if ($emacs) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($emacs[0].FullName)
        if ($shortcut.TargetPath) {
            $target = Get-Item $shortcut.TargetPath
            if ($target.Exists) {
                $emacsc = Get-ChildItem $target.Directory "emacsclient.exe"
                if ($emacsc.Exists) {
                    & $emacsc.FullName -n -c $args
                }
            }
        }
    }
}

function 7z {
    $lnk = Search-StartMenu 7zFM
    if ($lnk) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($lnk[0].FullName)
        if ($shortcut.TargetPath) {
            $target = Get-Item $shortcut.TargetPath
            if ($target.Exists) {
                $exe = Get-ChildItem $target.Directory "7z.exe"
                if ($exe.Exists) {
                    & $exe.FullName $args
                    return
                }
            }
        }
    }
    & 7z.exe $args
}

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
    if ($env:http_proxy) {
        Write-Host "Disabling proxies"
        $proxy = ""
    } else {
        $proxy = Get-InternetProxy
    }
    $env:http_proxy=$proxy
    $env:https_proxy=$proxy

    $mvnsettings = "$env:USERPROFILE\.m2\settings.xml"
    $xml = [xml]::new()
    if (Test-Path "$mvnsettings") {
        $xml.Load($mvnsettings)
    }
    if ($xml.GetElementsByTagName("settings").Count -eq 0) {
        $xml.AppendChild($xml.CreateElement("settings"))
    }
    if ($xml.GetElementsByTagName("proxies").Count -eq 0) {
        ($xml.ChildNodes | Where {$_.Name -eq "settings"}).AppendChild($xml.CreateElement("proxies"))
    }
    $proxies = $xml.GetElementsByTagName("proxy")

    $http_proxy = $proxies | Where {$_.protocol -eq "http"}
    if (-Not ($http_proxy)) {
        $http_proxy = $xml.CreateElement("proxy")
        ($xml.settings.ChildNodes | Where {$_.Name -eq "proxies"}).AppendChild($http_proxy)
        $http_proxy.AppendChild($xml.CreateElement("id"))
        $http_proxy.id = "http-proxy"
        $http_proxy.AppendChild($xml.CreateElement("active"))
        $http_proxy.AppendChild($xml.CreateElement("host"))
        $http_proxy.AppendChild($xml.CreateElement("protocol"))
        $http_proxy.AppendChild($xml.CreateElement("port"))
    }
    if ($env:http_proxy) {
        $http_proxy.active = "true"
        $http_proxy.host = $env:http_proxy -replace "^https?://","" -replace ":\d+$",""
        $http_proxy.protocol = $env:http_proxy -replace "://.*$",""
        $http_proxy.port = $env:http_proxy -replace "^.*:",""
    } else {
        $http_proxy.active = "false"
    }

    $https_proxy = $proxies | Where {$_.protocol -eq "https"}
    if (-Not ($https_proxy)) {
        $https_proxy = $xml.CreateElement("proxy")
        ($xml.settings.ChildNodes | Where {$_.Name -eq "proxies"}).AppendChild($https_proxy)
        $https_proxy.AppendChild($xml.CreateElement("id"))
        $https_proxy.id = "https-proxy"
        $https_proxy.AppendChild($xml.CreateElement("active"))
        $https_proxy.AppendChild($xml.CreateElement("host"))
        $https_proxy.AppendChild($xml.CreateElement("protocol"))
        $https_proxy.AppendChild($xml.CreateElement("port"))
    }
    if ($env:https_proxy) {
        $https_proxy.active = "true"
        $https_proxy.host = $env:https_proxy -replace "^https?://","" -replace ":\d+$",""
        $https_proxy.protocol = $env:https_proxy -replace "://.*$",""
        $https_proxy.port = $env:https_proxy -replace "^.*:",""
    } else {
        $https_proxy.active = "false"
    }
    $xml.Save("$mvnsettings")
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

function Tim-GraalJdkHome {
    if ($env:__prev_java_home) {
        $env:JAVA_HOME = $env:__prev_java_home
    } else {
        $env:__prev_java_home = $env:JAVA_HOME
    }
    $jdks = "$env:USERPROFILE\\.mx\\jdks"
    $candidates = Get-ChildItem "$jdks" | % {"$jdks\\" + $_.Name}
    if ($candidates) {
        $env:JAVA_HOME = (@($candidates) + @($env:JAVA_HOME)) | Out-GridView -PassThru
    } else {
        Write-Host "No JDKs in $jdks"
    }
}

$Env:MX_CACHE_DIR="$DevDirectory\mx_cache"
$Env:PIP_CACHE_DIR="$DevDirectory\pip_cache"
$Env:MAVEN_OPTS="-Dmaven.repo.local=$DevDirectory\maven_cache"
$Env:GRADLE_USER_HOME="$DevDirectory\gradle_cache"
$Env:PATH+=";$DevDirectory\mx"
$Env:PATH+=";$DevDirectory\apache-maven\bin"
$Env:PATH+=";$DevDirectory\patch"
