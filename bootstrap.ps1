# *********************************************
# Ensure the script is running as Administrator
# *********************************************
If (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Script is not running as Administrator. Restarting elevated..."
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

[CmdletBinding()]
param()

# Bootstrap the small set of prerequisites needed before mise can manage this
# repository. The full machine setup belongs in mise.toml and is applied by
# `mise bootstrap` below.
$ErrorActionPreference = 'Stop'

$DefaultRepository = 'https://github.com/timfel/dotfiles.git'
$Repository = if ($env:DOTFILES_REPO) { $env:DOTFILES_REPO } else { $DefaultRepository }
$DotfilesDirectory = if ($env:DOTFILES_DIR) {
    $env:DOTFILES_DIR
} else {
    Join-Path $HOME 'dotfiles'
}

function Write-BootstrapMessage([string] $Message) {
    Write-Host "bootstrap: $Message"
}

function Throw-BootstrapError([string] $Message) {
    throw "bootstrap: $Message"
}

function Refresh-Path {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    if ($userPath -and $machinePath) {
        $env:Path = "$userPath;$machinePath"
    } elseif ($userPath) {
        $env:Path = $userPath
    } elseif ($machinePath) {
        $env:Path = $machinePath
    }
}

function Invoke-Native([string] $Command, [string[]] $Arguments) {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        Throw-BootstrapError "command failed with exit code ${LASTEXITCODE}: $Command $($Arguments -join ' ')"
    }
}

function Require-Winget {
    Refresh-Path
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Throw-BootstrapError 'winget is required; install Microsoft App Installer and rerun this script'
    }
}

function Install-WingetPackage([string] $Id) {
    $installed = & winget list --id $Id --exact --accept-source-agreements 2>$null |
        Select-String -SimpleMatch $Id
    if ($installed) {
        Write-BootstrapMessage "$Id is already installed"
        return
    }

    Write-BootstrapMessage "installing $Id with winget"
    Invoke-Native 'winget' @(
        'install', '--id', $Id, '--exact',
        '--accept-source-agreements', '--accept-package-agreements'
    )
    Refresh-Path
}

function Require-Command([string] $Name) {
    Refresh-Path
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        Throw-BootstrapError "$Name was installed but is not on PATH; open a new PowerShell and rerun this script"
    }
    return $command.Source
}

function Ensure-GlobalMiseConfig {
    $configDirectory = if ($env:XDG_CONFIG_HOME) {
        Join-Path $env:XDG_CONFIG_HOME 'mise'
    } else {
        Join-Path $HOME '.config\mise'
    }
    $config = Join-Path $configDirectory 'config.toml'
    $target = Join-Path $DotfilesDirectory 'mise.toml'
    New-Item -ItemType Directory -Force -Path $configDirectory | Out-Null

    if (Test-Path -LiteralPath $config) {
        $item = Get-Item -Force -LiteralPath $config
        if ($item.LinkType -ne 'SymbolicLink') {
            Throw-BootstrapError "refusing to replace existing mise config: $config"
        }
        $actual = (Resolve-Path -LiteralPath $config).Path
        $expected = (Resolve-Path -LiteralPath $target).Path
        if ($actual -ne $expected) {
            Throw-BootstrapError "mise config is a conflicting symlink: $config"
        }
        return
    }

    Write-BootstrapMessage "linking global mise config $config -> $target"
    New-Item -ItemType SymbolicLink -Path $config -Target $target | Out-Null
}

function Clone-OrUseRepository([string] $Git) {
    if (Test-Path -LiteralPath $DotfilesDirectory) {
        if (-not (Test-Path -LiteralPath $DotfilesDirectory -PathType Container)) {
            Throw-BootstrapError "DOTFILES_DIR exists but is not a directory: $DotfilesDirectory"
        }

        & $Git '-C' $DotfilesDirectory 'rev-parse' '--show-toplevel' *> $null
        if ($LASTEXITCODE -ne 0) {
            Throw-BootstrapError "DOTFILES_DIR exists but is not a git checkout: $DotfilesDirectory"
        }

        Write-BootstrapMessage "using existing checkout $DotfilesDirectory"
        Write-BootstrapMessage "not pulling automatically; update it manually with git -C `"$DotfilesDirectory`" pull"
        return
    }

    $parent = Split-Path -Parent $DotfilesDirectory
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Write-BootstrapMessage "cloning $Repository into $DotfilesDirectory"
    Invoke-Native $Git @('clone', $Repository, $DotfilesDirectory)
}

function Main {
    Refresh-Path
    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    $miseCommand = Get-Command mise -ErrorAction SilentlyContinue

    if (-not $gitCommand -or -not $miseCommand) {
        Require-Winget
        if (-not $gitCommand) {
            Install-WingetPackage 'Git.Git'
        }
        if (-not $miseCommand) {
            Install-WingetPackage 'jdx.mise'
        }
    }

    $git = Require-Command 'git'
    $mise = Require-Command 'mise'
    Clone-OrUseRepository $git

    $config = Join-Path $DotfilesDirectory 'mise.toml'
    if (-not (Test-Path -LiteralPath $config -PathType Leaf)) {
        Throw-BootstrapError "mise.toml was not found in $DotfilesDirectory"
    }
    Ensure-GlobalMiseConfig

    Write-BootstrapMessage "trusting $config"
    Invoke-Native $mise @('trust', '--yes', $config)

    Write-BootstrapMessage 'running mise bootstrap'
    Push-Location $DotfilesDirectory
    try {
        Invoke-Native $mise @('bootstrap', '--yes')
    } finally {
        Pop-Location
    }
    Write-BootstrapMessage 'done'
}

Main
