$xmingfileassoc = cmd /c assoc .xlaunch
$xmingpathassoc = cmd /c ftype $xmingfileassoc.Split("=")[1]
$xlaunchpath = Split-Path -parent -Path $xmingpathassoc.split('"')[1]
$xmingexe = Join-Path $xlaunchpath "Xming.exe"
start -FilePath $xmingexe -ArgumentList '-br','-multiwindow','-clipboard','-dpi','160','-compositewm','-wgl','-silent-dup-error' -NoNewWindow
powershell -windowstyle hidden -command "&{ bash -l -c 'cd ~; xfce4-terminal' }"

$url = 'http://localhost:9876/'
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($url)
$listener.Start()

Write-Host "Listening at $url..."

while ($listener.IsListening)
{
    $context = $listener.GetContext()
    $requestUrl = $context.Request.Url
    $response = $context.Response

    Write-Host ''
    Write-Host "> $requestUrl"
    $localPath = $requestUrl.LocalPath.TrimStart("/")

    if ($requestUrl -match '/kill$') { break }

    $output = cmd /c "$localPath"
    $content = "$localPath #=> $output\n"
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
    $response.ContentLength64 = $buffer.Length
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
    $response.Close()
    $responseStatus = $response.StatusCode
    Write-Host "< $responseStatus"
}

$listener.Stop()
