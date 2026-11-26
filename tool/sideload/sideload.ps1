<#
.SYNOPSIS
  Installs WattWise on your iPhone from Windows, using xtool inside WSL.

.DESCRIPTION
  Run in PowerShell **as administrator**, with the iPhone plugged in and unlocked:

    powershell -ExecutionPolicy Bypass -File tool\sideload\sideload.ps1
    powershell -ExecutionPolicy Bypass -File tool\sideload\sideload.ps1 -Ipa C:\path\to\wattwise.ipa

  What it does:
    1. Checks WSL and iTunes (its Apple Mobile Device Service talks to the iPhone).
    2. Forwards that connection (port 27015) into WSL, only on the WSL network adapter.
    3. First run: installs xtool in WSL and signs in to your Apple ID (setup-wsl.sh).
    4. Downloads the latest WattWise .ipa from GitHub Releases and installs it (install.sh).

  Free Apple ID: the app stops opening after 7 days. Run this again to renew.
#>
#Requires -RunAsAdministrator
param([string]$Ipa)
$ErrorActionPreference = 'Stop'

function Step($text) { Write-Host "==> $text" -ForegroundColor Cyan }

Step 'Checking WSL'
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
  throw 'WSL is not installed. Run "wsl --install -d Ubuntu", restart Windows, open Ubuntu once to create your user, then run this again.'
}
$distros = (wsl.exe --list --quiet) -replace "`0", '' | Where-Object { $_.Trim() }
if (-not $distros) {
  throw 'WSL has no Linux distribution yet. Run "wsl --install -d Ubuntu", open Ubuntu once, then run this again.'
}

Step 'Checking iTunes (Apple Mobile Device Service)'
$svc = Get-Service -Name 'Apple Mobile Device Service' -ErrorAction SilentlyContinue
if (-not $svc) {
  throw 'iTunes is not installed. Install iTunes (Microsoft Store or apple.com), open it, plug in the iPhone and tap Trust on the phone, then run this again.'
}
if ($svc.Status -ne 'Running') { Start-Service -Name $svc.Name }

Step 'Forwarding the iPhone connection into WSL'
$wslHost = (wsl.exe -e sh -c "ip route list default | awk '{print `$3}'").Trim()
if ($wslHost -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
  throw "Couldn't find the WSL network address (got '$wslHost'). If WSL uses mirrored networking, run tool/sideload/install.sh in Ubuntu with USBMUXD_SOCKET_ADDRESS=127.0.0.1:27015 instead."
}
# Replace any earlier forward of port 27015 (the WSL address can change after a restart).
netsh interface portproxy show v4tov4 | Select-String -Pattern '^\s*(\S+)\s+27015\s' | ForEach-Object {
  $old = $_.Matches[0].Groups[1].Value
  netsh interface portproxy delete v4tov4 listenport=27015 listenaddress=$old | Out-Null
}
netsh interface portproxy add v4tov4 listenaddress=$wslHost listenport=27015 connectaddress=127.0.0.1 connectport=27015 | Out-Null
$rule = 'WattWise sideload (iPhone to WSL)'
Get-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName $rule -Direction Inbound -Protocol TCP -LocalAddress $wslHost -LocalPort 27015 -Action Allow | Out-Null
Write-Host "    $($wslHost):27015 -> Apple Mobile Device Service"

$here = (wsl.exe wslpath -a "$PSScriptRoot").Trim()

$hasXtool = (wsl.exe -e bash -lc 'command -v xtool >/dev/null || [ -x "$HOME/.local/bin/xtool" ] && echo yes').Trim()
if ($hasXtool -ne 'yes') {
  Step 'First run: installing xtool in WSL and signing in to Apple'
  wsl.exe -e bash "$here/setup-wsl.sh"
  if ($LASTEXITCODE -ne 0) { throw 'xtool setup failed (see the messages above).' }
}

Step 'Installing WattWise'
if ($Ipa) {
  $ipaWsl = (wsl.exe wslpath -a "$((Resolve-Path $Ipa).Path)").Trim()
  wsl.exe -e bash "$here/install.sh" "$ipaWsl"
} else {
  wsl.exe -e bash "$here/install.sh"
}
if ($LASTEXITCODE -ne 0) { throw 'Install failed (see the messages above).' }
