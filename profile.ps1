# iwr https://raw.githubusercontent.com/timfel/dotfiles/master/profile.ps1 -OutFile $PROFILE
New-Alias unzip Expand-Archive -option AllScope -force
New-Alias zip Compress-Archive -option AllScope  -force
New-Alias man Get-Help -option AllScope  -force
New-Alias wget Invoke-WebRequest -option AllScope  -force

function vscode {
    if ($args.Count -eq 0) {
        Start-Process -WindowStyle Hidden code
    } else {
        Start-Process -WindowStyle Hidden code -ArgumentList "$args"
    }
}

function first_time_system_setup {
    $packages = @(
        'keepass'
        'steam'
        'gog.galaxy'
        'discord'
        # 'uplay'
        'Microsoft.VisualStudio.BuildTools'
        'vlc'
        'vscode'
        'git'
        'github.cli'
        'slack'
        'vncviewer'
    )
    foreach ($item in $packages) {
        winget install "$item"
    }

    wsl --install
}

Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
        $Local:word = $wordToComplete.Replace('"', '""')
        $Local:ast = $commandAst.ToString().Replace('"', '""')
        winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}
