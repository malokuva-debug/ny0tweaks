[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$url = "https://ny0tweaks.vercel.app/Win11-Gaming-Optimizer-GUI.ps1"
$tmp = "$env:TEMP\Win11-Gaming-Optimizer-GUI.ps1"
(New-Object System.Net.WebClient).DownloadFile($url, $tmp)
& $tmp
