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
winget install Microsoft.VisualStudio.2022.BuildTools
winget install Microsoft.VisualStudioCode
winget install Kitware.CMake
winget install GNU.Emacs
winget install gsudo
winget install Clement.bottom
winget install keepass
winget install GunWin32.Zip
winget install 7-Zip

powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

wsl --update
wsl --install Ubuntu-24.04

git clone https://github.com/timfel/my_emacs_for_rails.git $env:APPDATA/.emacs.d
git clone https://github.com/timfel/dotfiles.git $env:APPDATA/dotfiles
sudo New-Item -Path $env:USERPROFILE/.gitconfig -ItemType SymbolicLink -Value $env:APPDATA/dotfiles/.gitconfig
sudo New-Item -Path $profile.CurrentUserCurrentHost -ItemType SymbolicLink -Value $env:APPDATA/dotfiles/powershell-functions.ps1

Tim-InstallPyenv
Tim-InstallSdkMan

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

function vi {
    $emacs = Search-StartMenu runemacs
    if ($emacs) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($emacs[0].FullName)
        if ($shortcut.TargetPath) {
            $target = Get-Item $shortcut.TargetPath
            if ($target.Exists) {
                $emacsc = Get-ChildItem $target.Directory "emacs.exe"
                if ($emacsc.Exists) {
                    & $emacsc.FullName -Q -nw $args
                }
            }
        }
    }
}

function emacs {
    $emacs = Search-StartMenu runemacs
    if ($emacs) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($emacs[0].FullName)
        if ($shortcut.TargetPath) {
            $target = Get-Item $shortcut.TargetPath
            if ($target.Exists) {
                $emacsc = Get-ChildItem $target.Directory "emacs.exe"
                if ($emacsc.Exists) {
                    & $emacsc.FullName $args
                }
            }
        }
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
                    Write-Host "Running " $exe.FullName
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

function pkill {
    [CmdletBinding()]
    param (
        [switch]$9,
        [Parameter(Mandatory, Position=0)]
        [string]$Pattern
    )
    if ($9) {
        pgrep "$Pattern" | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    } else {
        pgrep "$Pattern" | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    }
}

function pgrep {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$Pattern
    )
    Get-CimInstance Win32_Process | Select-Object ProcessId,Name,CommandLine | Where-Object { $_.CommandLine -match "$Pattern" }
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
    btm -b --battery --process_memory_as_value -n
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
        $env:http_proxy=""
        $env:https_proxy=""
        $env:no_proxy=""
        $env:MAVEN_OPTS=$env:__prevMAVEN_OPTS
        $env:GRADLE_OPTS=$env:__prevGRADLE_OPTS
    } else {
        try {
            $proxy = Get-InternetProxy
        } catch {
            return
        }
        $env:http_proxy=$proxy
        $env:https_proxy=$proxy
        $env:no_proxy="localhost,127.0.0.1,*.oraclecorp.com,oraclecorp.com,*.oraclecloud.com,oraclecloud.com,*.oracle.com,oracle.com"

        $proxyHost = $env:http_proxy -replace "^https?://","" -replace ":\d+$",""
        $proxyPort = $env:http_proxy -replace "^.*:",""
        $nonProxyHosts = $env:no_proxy -replace ",","^|"
        $javaProxies = "-Dhttp.proxyHost=${proxyHost} -Dhttp.proxyPort=${proxyPort} -Dhttps.proxyHost=${proxyHost} -Dhttps.proxyPort=${proxyPort} -Dhttp.nonProxyHosts=${nonProxyHosts} -Dhttps.nonProxyHosts=${nonProxyHosts}"    

        $env:__prevMAVEN_OPTS=$env:MAVEN_OPTS
        $env:MAVEN_OPTS="${env:MAVEN_OPTS} ${javaProxies}"
        $env:__prevGRADLE_OPTS=$env:GRADLE_OPTS
        $env:GRADLE_OPTS="${env:GRADLE_OPTS} ${javaProxies}"
    }
}

function Tim-InstallPyenv {
    $__userprofile=$env:USERPROFILE
    $env:USERPROFILE=$DevDirectory
    try {
        Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/pyenv-win/pyenv-win/master/pyenv-win/install-pyenv-win.ps1" -OutFile "./install-pyenv-win.ps1"; &"./install-pyenv-win.ps1"
    } finally {
        $env:USERPROFILE=$__userprofile
    }
}

function Tim-InstallSdkMan {
    $git = (Get-Item (Get-Command "git").Source).Directory.Parent
    $bin = Get-ChildItem $git.FullName "bin"
    $bash = Get-ChildItem $bin.FullName "bash.exe"

    $zip = fd -p "GnuWin32.bin.zip.exe" $env:ProgramFiles
    if (-Not ($zip)) {
        $zip = fd -p "GnuWin32.bin.zip.exe" ${env:ProgramFiles(x86)}
    }
    mkdir -p "$DevDirectory\bin"
    cp $zip "$DevDirectory\bin\zip.exe"
    (Invoke-WebRequest -Uri "https://get.sdkman.io").Content | & $bash.FullName
}

function sdk {
    $git = (Get-Item (Get-Command "git").Source).Directory.Parent
    $bin = Get-ChildItem $git.FullName "bin"
    $bash = Get-ChildItem $bin.FullName "bash.exe"
    if ($args) {
        $TempFile = New-TemporaryFile
        try {
            Write-Output ". $env:SDKMAN_DIR/bin/sdkman-init.sh; sdk $args" | Set-Content -Encoding ascii $TempFile.FullName
            & $bash.FullName --noprofile $TempFile.FullName
        } finally {
            Remove-Item -Force $TempFile
        }
    } else {
        & $bash.FullName --init-file "$env:SDKMAN_DIR/bin/sdkman-init.sh"
    }
}

function Tim-Get-Graal-Repos {
    git clone https://github.com/graalvm/mx $DevDirectory/mx
    git clone https://github.com/oracle/graalpython $DevDirectory/graalpython
}

function graalenv {
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

function sdkman-java-home {
    if ($env:__prev_java_home) {
        $env:JAVA_HOME = $env:__prev_java_home
    } else {
        $env:__prev_java_home = $env:JAVA_HOME
    }
    $jdks = "$env:SDKMAN_DIR\\candidates\\java"
    $candidates = Get-ChildItem "$jdks" | % {"$jdks\\" + $_.Name}
    if ($candidates) {
        $env:JAVA_HOME = (@($candidates) + @($env:JAVA_HOME)) | Out-GridView -PassThru
    } else {
        Write-Host "No JDKs in $jdks"
    }
}

function podman-DOCKER_HOST {
    $env:DOCKER_HOST="npipe://" + (podman machine inspect --format '{{.ConnectionInfo.PodmanPipe.Path}}') -replace "\\", "/"
}

function mx_fetch_latest_jdk {
    mx -p ../graal/vm fetch-jdk -A --jdk-id labsjdk-ce-latest
    $env:JAVA_HOME="$env:USERPROFILE\\.mx\\jdks\\labsjdk-ce-latest"
}

$Env:MX_CACHE_DIR="$DevDirectory\mx_cache"
$Env:MX_ASYNC_DISTRIBUTIONS="true"
$Env:MX_BUILD_EXPLODED="false"
$Env:JDT="builtin"
$Env:SDKMAN_DIR="$DevDirectory/.sdkman"
$Env:PIP_CACHE_DIR="$DevDirectory\pip_cache"
$Env:MAVEN_OPTS="-Dmaven.repo.local=$DevDirectory\maven_cache"
$Env:GRADLE_USER_HOME="$DevDirectory\gradle_cache"

$Env:OLLAMA_FLASH_ATTENTION=1
$Env:OLLAMA_MODELS="$DevDirectory\ollamamodels"
$Env:OLLAMA_HOST="0.0.0.0"
$Env:OLLAMA_ORIGINS="*"
$Env:OLLAMA_CONTEXT_LENGTH=32768
$Env:OLLAMA_KV_CACHE_TYPE="q4_0"

$Env:UV_INSTALL_DIR="$DevDirectory\uv"
$Env:UV_CACHE_DIR="$DevDirectory\uv\.cache"
$Env:UV_PYTHON_CACHE_DIR="$DevDirectory\uv\.python-cache"
$Env:UV_PYTHON_INSTALL_DIR="$DevDirectory\uv\.pythons"
$Env:UV_TOOL_DIR="$DevDirectory\uv\.tools"
$Env:UV_PYTHON_BIN_DIR="$DevDirectory\bin"
$Env:UV_TOOL_BIN_DIR="$DevDirectory\bin"

$MyPath="$DevDirectory\bin"
$MyPath+=";$DevDirectory\mx"
$MyPath+=";$DevDirectory\patch"
$MyPath+=";$DevDirectory\.pyenv\pyenv-win\shims"
foreach ($sdkmanPath in Get-ChildItem "$Env:SDKMAN_DIR\candidates") {
    $MyPath+=";${env:SDKMAN_DIR}\candidates\${sdkmanPath}\current\bin"
}

# Because e.g. the Visual Studio commandline modifies my PATH again, I set it here
$previousPrompt = $function:Prompt
function Prompt {
    if ($MyPath) {
        $Env:PATH = $MyPath + ";" + $Env:PATH
        $global:MyPath = ""
        & pyenv shell @(Get-Content $DevDirectory\.pyenv\pyenv-win\version)
        $function:Prompt = $previousPrompt
    }
    & $previousPrompt
}
