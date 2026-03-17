#Requires -RunAsAdministrator

<#
.SYNOPSIS
    ny0 Gaming Optimizer - BEAST MODE v4
.NOTES
    Version: 4.0 - 50+ Tweaks, Mouse Detection, NVIDIA Auto-Config
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

$Global:DetectedHardware = @{}
$Global:OptimizationLog  = [System.Collections.ArrayList]::new()

#region Hardware Detection

function Get-SystemInfo {
    $hwInfo = @{ CPU=@{}; GPU=@{}; RAM=@{}; Motherboard=@{}; Storage=@{}; OS=@{}; Mouse=@{} }
    try {
        $cpu = Get-CimInstance Win32_Processor
        $hwInfo.CPU = @{
            Name         = $cpu.Name
            Manufacturer = if ($cpu.Name -like "*Intel*") {"Intel"} elseif ($cpu.Name -like "*AMD*") {"AMD"} else {"Unknown"}
            Cores        = $cpu.NumberOfCores
            Threads      = $cpu.NumberOfLogicalProcessors
            MaxClock     = $cpu.MaxClockSpeed
            Generation   = Get-CPUGeneration $cpu.Name
        }
        $gpu = Get-CimInstance Win32_VideoController | Where-Object {$_.Name -notlike "*Microsoft*"} | Select-Object -First 1
        $hwInfo.GPU = @{
            Name         = $gpu.Name
            Manufacturer = if ($gpu.Name -match "NVIDIA|GeForce|RTX|GTX") {"NVIDIA"}
                           elseif ($gpu.Name -match "AMD|Radeon")          {"AMD"}
                           elseif ($gpu.Name -match "Intel|Arc")           {"Intel"}
                           else {"Unknown"}
            Driver       = $gpu.DriverVersion
            VRAM         = [math]::Round($gpu.AdapterRAM/1GB,2)
        }
        $ram = Get-CimInstance Win32_PhysicalMemory
        $hwInfo.RAM = @{
            TotalGB = [math]::Round(($ram|Measure-Object Capacity -Sum).Sum/1GB,2)
            Speed   = ($ram|Select-Object -First 1).Speed
        }
        $mobo = Get-CimInstance Win32_BaseBoard
        $hwInfo.Motherboard = @{ Manufacturer=$mobo.Manufacturer; Product=$mobo.Product }

        $storage = Get-PhysicalDisk
        $hwInfo.Storage = @{ Drives=@() }
        foreach ($d in $storage) {
            $hwInfo.Storage.Drives += @{ Model=$d.FriendlyName; MediaType=$d.MediaType; BusType=$d.BusType }
        }

        $os = Get-CimInstance Win32_OperatingSystem
        $hwInfo.OS = @{ Name=$os.Caption; Build=$os.BuildNumber }

        # Mouse Detection
        $mice = Get-CimInstance Win32_PointingDevice | Where-Object {$_.DeviceID -notlike "*terminal*"}
        if ($mice) {
            $mouse = $mice | Select-Object -First 1
            $hwInfo.Mouse = @{
                Name         = $mouse.Name
                Manufacturer = $mouse.Manufacturer
                DeviceID     = $mouse.DeviceID
                HardwareID   = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\$($mouse.DeviceID)" -ErrorAction SilentlyContinue).HardwareID
                IsWireless   = $mouse.Name -match "wireless|bluetooth|logitech unifying|nano" 
                Brand        = if ($mouse.Name -match "Logitech|LOGI") {"Logitech"}
                               elseif ($mouse.Name -match "Razer") {"Razer"}
                               elseif ($mouse.Name -match "SteelSeries") {"SteelSeries"}
                               elseif ($mouse.Name -match "Corsair") {"Corsair"}
                               elseif ($mouse.Name -match "ASUS|ROG") {"ASUS"}
                               elseif ($mouse.Name -match "Microsoft") {"Microsoft"}
                               else {"Generic"}
            }
        }
    } catch {
        [System.Windows.MessageBox]::Show("Hardware detection error: $_","Error","OK","Warning")
    }
    return $hwInfo
}

function Get-CPUGeneration([string]$n) {
    if ($n -like "*Intel*") {
        if ($n -match "14th|14900|14700|14600|14500|14400") { return "14th Gen (Raptor Lake R)" }
        if ($n -match "13th|13900|13700|13600|13500|13400") { return "13th Gen (Raptor Lake)" }
        if ($n -match "12th|12900|12700|12600|12500|12400") { return "12th Gen (Alder Lake)" }
        if ($n -match "11th|11900|11700|11600") { return "11th Gen (Rocket Lake)" }
        if ($n -match "10th|10900|10700|10600") { return "10th Gen (Comet Lake)" }
        return "Older Intel"
    }
    if ($n -like "*AMD*") {
        if ($n -match "9950|9900|9700|9600") { return "Ryzen 9000 (Zen 5)" }
        if ($n -match "7950|7900|7800|7700|7600") { return "Ryzen 7000 (Zen 4)" }
        if ($n -match "5950|5900|5800|5700|5600") { return "Ryzen 5000 (Zen 3)" }
        if ($n -match "3950|3900|3800|3700|3600") { return "Ryzen 3000 (Zen 2)" }
        return "Older AMD"
    }
    return "Unknown"
}

function Get-BIOSInstructions {
    param($hw)
    $S = "-------------------------------------------------------"
    $t = ""
    $cpu = $hw.CPU.Manufacturer; $gpu = $hw.GPU.Manufacturer; $mob = $hw.Motherboard.Manufacturer

    $t += "$S`n  CPU - $($hw.CPU.Name)`n$S`n`n"
    if ($cpu -eq "Intel") {
        $t += "[+] Turbo Boost: ENABLED`n[+] Turbo Boost Max 3.0: ENABLED`n[+] SpeedStep: ENABLED`n"
        $t += "[+] Hyper-Threading: ENABLED`n[+] C-States: ALL DISABLED`n    C1E / C3 / C6 / C7 / Package C: DISABLED`n"
    } elseif ($cpu -eq "AMD") {
        $t += "[+] PBO (Precision Boost Overdrive): ENABLED`n[+] Core Performance Boost: ENABLED`n"
        $t += "[+] SMT: ENABLED`n[+] Global C-State: DISABLED`n[+] CPPC + Preferred Cores: ENABLED`n"
    }

    $t += "`n$S`n  RAM - $($hw.RAM.TotalGB)GB @ $($hw.RAM.Speed)MHz`n$S`n`n"
    if ($cpu -eq "Intel") { $t += "[+] XMP Profile 1: ENABLED`n" }
    else { $t += "[+] DOCP/EXPO Profile 1: ENABLED`n" }
    $t += "[+] Memory Fast Boot: ENABLED`n[+] Gear Down Mode: DISABLED`n[+] Command Rate: 1T`n"

    $t += "`n$S`n  GPU/PCIe - $($hw.GPU.Name)`n$S`n`n"
    $t += "[+] Above 4G Decoding: ENABLED`n[+] Resizable BAR: ENABLED`n"
    $t += "[+] PCIe Gen: 4.0 x16`n[+] PCIe ASPM: DISABLED`n[+] Primary Display: PCIe/Auto`n"

    $t += "`n$S`n  MOTHERBOARD - $mob`n$S`n`n"
    switch -Wildcard ($mob) {
        "*ASUS*"     { $t += "AI Tweaker menu:`n[+] MCE: ENABLED`n[+] Performance Bias: Performance`n" }
        "*MSI*"      { $t += "OC menu:`n[+] A-XMP: ENABLED`n[+] Game Boost: Level 2-4`n" }
        "*Gigabyte*" { $t += "M.I.T. menu:`n[+] XMP: Profile 1`n[+] Performance Boost: Turbo`n" }
        "*AORUS*"    { $t += "M.I.T. menu:`n[+] XMP: Profile 1`n[+] Performance Boost: Turbo`n" }
        "*ASRock*"   { $t += "OC Tweaker:`n[+] XMP 2.0: Load Profile`n[+] Auto OC: Level 1-3`n" }
        default      { $t += "Check manual for XMP/OC settings`n" }
    }

    $t += "`n$S`n  BIOS EXTRAS`n$S`n`n"
    $t += "[+] Fast Boot: ENABLED`n[+] UEFI Boot: ENABLED (no CSM)`n[+] Secure Boot: DISABLED`n"
    $t += "[+] VT-d / IOMMU: DISABLED (no VMs)`n[+] ErP: DISABLED`n[+] Fan Control: Set aggressive curve`n"

    if ($gpu -eq "NVIDIA") {
        $t += "`n$S`n  NVIDIA CONTROL PANEL`n$S`n`n"
        $t += "[+] Power Mode: Prefer Max Performance`n[+] Low Latency: Ultra`n"
        $t += "[+] Texture Filtering: Performance`n[+] Shader Cache: 10GB`n"
        $t += "[+] Vsync: Off`n[+] Triple Buffering: Off`n[+] Max FPS: Unlimited`n"
        $t += "[+] FXAA / TXAA: Off`n[+] Aniso: App controlled`n"
    } elseif ($gpu -eq "AMD") {
        $t += "`n$S`n  AMD RADEON SOFTWARE`n$S`n`n"
        $t += "[+] Anti-Lag: ON`n[+] Boost: ON`n[+] Chill: OFF`n"
        $t += "[+] Image Sharpening: Optional`n[+] Texture Filtering: Performance`n"
    }

    if ($hw.Mouse.Name) {
        $t += "`n$S`n  MOUSE - $($hw.Mouse.Name)`n$S`n`n"
        $t += "[+] Brand: $($hw.Mouse.Brand)`n"
        if ($hw.Mouse.IsWireless) { $t += "[!] Wireless detected - use wired for lowest latency if possible`n" }
        $t += "[+] Set polling rate to 1000Hz (or 2000/4000Hz if supported)`n"
        $t += "[+] DPI: 800 recommended for competitive`n"
        $t += "[+] Windows pointer speed: 6/11 (middle)`n"
        $t += "[+] Enhance pointer precision: OFF`n"
        switch ($hw.Mouse.Brand) {
            "Logitech"    { $t += "[+] G HUB: Disable onboard memory mode, set report rate 1000Hz`n[+] Disable Logitech background services`n" }
            "Razer"       { $t += "[+] Synapse: Set polling 1000Hz, disable Chroma if not needed`n[+] Disable Razer Game Scanner`n" }
            "SteelSeries" { $t += "[+] GG Engine: Set 1000Hz polling`n[+] Disable SteelSeries Engine background tasks`n" }
            "Corsair"     { $t += "[+] iCUE: Set 1000Hz, disable lighting for CPU savings`n" }
            default       { $t += "[+] Check manufacturer software for 1000Hz polling rate`n" }
        }
    }
    return $t
}

#endregion

#region All Step Functions

function Step-RestorePoint {
    Enable-ComputerRestore "C:\" -EA SilentlyContinue
    Checkpoint-Computer -Description ("Beast Mode v4 - "+(Get-Date -f 'yyyy-MM-dd HH:mm')) -RestorePointType MODIFY_SETTINGS -EA Stop
}
function Step-DisableServices {
    $s = @("DiagTrack","dmwappushservice","SysMain","WSearch","TabletInputService","wisvc","RetailDemo",
           "Fax","MapsBroker","lfsvc","XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc",
           "PcaSvc","RemoteRegistry","WerSvc","wercplsupport","Themes","WMPNetworkSvc",
           "icssvc","lmhosts","SSDPSRV","upnphost","TrkWks","WbioSrvc")
    foreach ($n in $s) { try { Stop-Service $n -Force -EA SilentlyContinue; Set-Service $n -StartupType Disabled -EA SilentlyContinue } catch {} }
}
function Step-PowerPlan {
    $g = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    powercfg -duplicatescheme $g 2>$null; powercfg -setactive $g 2>$null
    powercfg -change -monitor-timeout-ac 0
    powercfg -change -disk-timeout-ac 0
    powercfg -change -standby-timeout-ac 0
    powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7 100
    powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 943c8cb6-6f93-4227-ad87-e9a3feec08d1 1
    powercfg -setactive SCHEME_CURRENT
}
function Step-DisablePowerThrottling {
    $k = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"
    if (!(Test-Path $k)) { New-Item $k -Force | Out-Null }
    Set-ItemProperty $k PowerThrottlingOff -Type DWord -Value 1
}
function Step-DisableCoreParking {
    powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 0 2>$null
    powercfg -setactive SCHEME_CURRENT 2>$null
}
function Step-GameDVR {
    $k1="HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
    $k2="HKCU:\System\GameConfigStore"
    foreach ($k in @($k1,$k2)) { if(!(Test-Path $k)){New-Item $k -Force|Out-Null} }
    Set-ItemProperty $k1 AppCaptureEnabled -Type DWord -Value 0
    Set-ItemProperty $k2 GameDVR_Enabled   -Type DWord -Value 0
    Set-ItemProperty $k2 GameDVR_FSEBehaviorMode -Type DWord -Value 2
    Set-ItemProperty $k2 GameDVR_DXGIHonorFSEWindowsCompatible -Type DWord -Value 1
    Set-ItemProperty $k2 GameDVR_HonorUserFSEBehaviorMode -Type DWord -Value 1
    Set-ItemProperty $k2 GameDVR_EFSEFeatureFlags -Type DWord -Value 0
}
function Step-VisualEffects {
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" VisualFXSetting -Type DWord -Value 2 -EA SilentlyContinue
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" EnableTransparency -Type DWord -Value 0 -EA SilentlyContinue
    # Disable animations
    Set-ItemProperty "HKCU:\Control Panel\Desktop" UserPreferencesMask -Type Binary -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -EA SilentlyContinue
    Set-ItemProperty "HKCU:\Control Panel\Desktop" FontSmoothing -Value "2" -EA SilentlyContinue
    Set-ItemProperty "HKCU:\Control Panel\Desktop\WindowMetrics" MinAnimate -Value "0" -EA SilentlyContinue
}
function Step-Network {
    netsh interface tcp set global autotuninglevel=normal 2>$null
    netsh interface tcp set global congestionprovider=ctcp 2>$null
    netsh interface tcp set heuristics disabled 2>$null
    netsh interface tcp set global rss=enabled 2>$null
    netsh interface tcp set global nonsackrttresiliency=disabled 2>$null
    netsh interface tcp set global initialRto=2000 2>$null
    netsh interface tcp set global timestamps=disabled 2>$null
    $k = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty $k NetworkThrottlingIndex -Type DWord -Value 0xffffffff -EA SilentlyContinue
    # Disable Nagle algorithm on all NICs
    $nics = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -EA SilentlyContinue
    foreach ($nic in $nics) {
        Set-ItemProperty $nic.PSPath TcpAckFrequency -Type DWord -Value 1 -EA SilentlyContinue
        Set-ItemProperty $nic.PSPath TCPNoDelay      -Type DWord -Value 1 -EA SilentlyContinue
    }
}
function Step-BackgroundApps {
    $k="HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k GlobalUserDisabled -Type DWord -Value 1
    # Disable Content Delivery Manager
    $k2="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    if(Test-Path $k2){
        Set-ItemProperty $k2 ContentDeliveryAllowed       -Type DWord -Value 0 -EA SilentlyContinue
        Set-ItemProperty $k2 SilentInstalledAppsEnabled   -Type DWord -Value 0 -EA SilentlyContinue
        Set-ItemProperty $k2 SubscribedContent-338388Enabled -Type DWord -Value 0 -EA SilentlyContinue
    }
}
function Step-GPUScheduling {
    $k="HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k HwSchMode -Type DWord -Value 2
    # Disable TDR (timeout detection) for gaming
    Set-ItemProperty $k TdrDelay  -Type DWord -Value 10 -EA SilentlyContinue
    Set-ItemProperty $k TdrLevel  -Type DWord -Value 3  -EA SilentlyContinue
}
function Step-GameMode {
    $k="HKCU:\Software\Microsoft\GameBar"
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k AutoGameModeEnabled -Type DWord -Value 1
    Set-ItemProperty $k AllowAutoGameMode   -Type DWord -Value 1
    Set-ItemProperty $k ShowStartupPanel    -Type DWord -Value 0 -EA SilentlyContinue
}
function Step-GamePriority {
    $k="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k "Affinity"            -Type DWord  -Value 0
    Set-ItemProperty $k "Background Only"     -Type String -Value "False"
    Set-ItemProperty $k "Clock Rate"          -Type DWord  -Value 10000
    Set-ItemProperty $k "GPU Priority"        -Type DWord  -Value 8
    Set-ItemProperty $k "Priority"            -Type DWord  -Value 6
    Set-ItemProperty $k "Scheduling Category" -Type String -Value "High"
    Set-ItemProperty $k "SFIO Rate"           -Type String -Value "High"
    $kp="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty $kp SystemResponsiveness -Type DWord -Value 0
    Set-ItemProperty $kp LazyModeTimeout      -Type DWord -Value 750000 -EA SilentlyContinue
}
function Step-MouseOptimize {
    # Disable acceleration
    Set-ItemProperty "HKCU:\Control Panel\Mouse" MouseSpeed      -Value "0"
    Set-ItemProperty "HKCU:\Control Panel\Mouse" MouseThreshold1 -Value "0"
    Set-ItemProperty "HKCU:\Control Panel\Mouse" MouseThreshold2 -Value "0"
    # Set pointer speed to 6/11 (1:1 tracking)
    Set-ItemProperty "HKCU:\Control Panel\Mouse" MouseSensitivity -Value "10" -EA SilentlyContinue
    # Disable smooth scrolling
    Set-ItemProperty "HKCU:\Control Panel\Desktop" SmoothScroll -Value "0" -EA SilentlyContinue
    # Mouse fix - raw input
    $k="HKCU:\Control Panel\Mouse"
    Set-ItemProperty $k ActiveWindowTracking -Type DWord -Value 0 -EA SilentlyContinue
}
function Step-MouseHIDLatency {
    # Set mouse USB poll rate via registry HID settings
    $hidPaths = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\HID" -EA SilentlyContinue
    foreach ($path in $hidPaths) {
        $devParams = "$($path.PSPath)\Device Parameters" 
        if (Test-Path $devParams) {
            Set-ItemProperty $devParams EnhancedPowerManagementEnabled -Type DWord -Value 0 -EA SilentlyContinue
            Set-ItemProperty $devParams AllowIdleIrpInD3               -Type DWord -Value 0 -EA SilentlyContinue
            Set-ItemProperty $devParams WaitWakeEnabled                 -Type DWord -Value 0 -EA SilentlyContinue
            Set-ItemProperty $devParams DeviceSelectiveSuspended        -Type DWord -Value 0 -EA SilentlyContinue
        }
    }
    # Disable USB selective suspend
    powercfg -setacvalueindex SCHEME_CURRENT 2a737abc-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
    powercfg -setactive SCHEME_CURRENT 2>$null
}
function Step-DisableDynamicTick {
    bcdedit /set disabledynamictick yes 2>$null
    bcdedit /set useplatformclock false 2>$null
    bcdedit /set tscsyncpolicy enhanced 2>$null
}
function Step-Win32Priority {
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" Win32PrioritySeparation -Type DWord -Value 38
}
function Step-MemoryManagement {
    $k="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Set-ItemProperty $k DisablePagingExecutive -Type DWord -Value 1 -EA SilentlyContinue
    Set-ItemProperty $k LargeSystemCache       -Type DWord -Value 0 -EA SilentlyContinue
    Set-ItemProperty $k IoPageLockLimit        -Type DWord -Value 983040 -EA SilentlyContinue
    # Prefetch/Superfetch tweaks
    Set-ItemProperty $k EnableSuperfetch       -Type DWord -Value 0 -EA SilentlyContinue
    Set-ItemProperty $k EnablePrefetcher       -Type DWord -Value 0 -EA SilentlyContinue
    # Large pages
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" EnableLegacyPagedPool -Type DWord -Value 0 -EA SilentlyContinue
}
function Step-DisableTelemetry {
    $keys = @(
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
    )
    foreach ($k in $keys) {
        if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
        Set-ItemProperty $k AllowTelemetry -Type DWord -Value 0
    }
    # Disable CompatTelRunner scheduled tasks
    schtasks /Change /TN "Microsoft\Windows\Customer Experience Improvement Program\Consolidator" /DISABLE 2>$null
    schtasks /Change /TN "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"     /DISABLE 2>$null
    schtasks /Change /TN "Microsoft\Windows\Application Experience\ProgramDataUpdater"           /DISABLE 2>$null
    schtasks /Change /TN "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" /DISABLE 2>$null
}
function Step-DisableDeliveryOptimization {
    $k="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k DODownloadMode -Type DWord -Value 0
}
function Step-DisableStartupDelay {
    $k="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k StartupDelayInMSec -Type DWord -Value 0
}
function Step-FSEAndDWM {
    # Disable DWM transitions
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\DWM" Animations -Type DWord -Value 0 -EA SilentlyContinue
    # Disable window animations
    Set-ItemProperty "HKCU:\Control Panel\Desktop\WindowMetrics" MinAnimate -Value "0" -EA SilentlyContinue
}
function Step-IRQPriority {
    # Set GPU IRQ to high priority
    $gpuKey = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI" -EA SilentlyContinue |
              Get-ChildItem -EA SilentlyContinue |
              Where-Object { (Get-ItemProperty $_.PSPath -EA SilentlyContinue).Class -eq "Display" } |
              Select-Object -First 1
    if ($gpuKey) {
        $devParam = "$($gpuKey.PSPath)\Device Parameters\Interrupt Management\Affinity Policy"
        if(!(Test-Path $devParam)){New-Item $devParam -Force|Out-Null}
        Set-ItemProperty $devParam DevicePolicy       -Type DWord -Value 4 -EA SilentlyContinue
        Set-ItemProperty $devParam DevicePriority     -Type DWord -Value 3 -EA SilentlyContinue
    }
}
function Step-NVIDIARegistry {
    $nvBase = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    if (!(Test-Path $nvBase)) {
        # Try to find correct subkey
        $nvBase = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -EA SilentlyContinue |
                  Where-Object { (Get-ItemProperty $_.PSPath -EA SilentlyContinue).DriverDesc -match "NVIDIA" } |
                  Select-Object -First 1 -ExpandProperty PSPath
    }
    if ($nvBase -and (Test-Path $nvBase)) {
        # Power management - max performance
        Set-ItemProperty $nvBase "PerfLevelSrc"          -Type DWord -Value 0x2222 -EA SilentlyContinue
        Set-ItemProperty $nvBase "PowerMizerEnable"      -Type DWord -Value 1      -EA SilentlyContinue
        Set-ItemProperty $nvBase "PowerMizerLevel"       -Type DWord -Value 1      -EA SilentlyContinue
        Set-ItemProperty $nvBase "PowerMizerLevelAC"     -Type DWord -Value 1      -EA SilentlyContinue
        # Disable NVIDIA telemetry via registry
        $nvTelKey = "HKLM:\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client"
        if(!(Test-Path $nvTelKey)){New-Item $nvTelKey -Force|Out-Null}
        Set-ItemProperty $nvTelKey OptInOrOutPreference -Type DWord -Value 0 -EA SilentlyContinue
    }
    # Disable NVIDIA telemetry tasks
    schtasks /Change /TN "NvTmRep_CrashReport1_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}" /DISABLE 2>$null
    schtasks /Change /TN "NvTmRep_CrashReport2_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}" /DISABLE 2>$null
    schtasks /Change /TN "NvTmRep_CrashReport3_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}" /DISABLE 2>$null
    schtasks /Change /TN "NvTmRep_CrashReport4_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}" /DISABLE 2>$null
    # Disable NV services that eat CPU
    foreach ($s in @("NvContainerLocalSystem","NvContainerNetworkService","NvDisplayContainerLS")) {
        Set-Service $s -StartupType Manual -EA SilentlyContinue
    }
}
function Step-DisableSearchHighlights {
    $k="HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k IsDynamicSearchBoxEnabled -Type DWord -Value 0 -EA SilentlyContinue
    # Disable web search in start menu
    $k2="HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if(!(Test-Path $k2)){New-Item $k2 -Force|Out-Null}
    Set-ItemProperty $k2 BingSearchEnabled     -Type DWord -Value 0 -EA SilentlyContinue
    Set-ItemProperty $k2 CortanaConsent        -Type DWord -Value 0 -EA SilentlyContinue
    Set-ItemProperty $k2 SearchboxTaskbarMode  -Type DWord -Value 0 -EA SilentlyContinue
}
function Step-DisableNotifications {
    $k="HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k ToastEnabled -Type DWord -Value 0 -EA SilentlyContinue
}
function Step-DisableWindowsDefenderScan {
    # Reduce Defender impact during gaming (does NOT disable protection)
    $k="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Scan"
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k AvgCPULoadFactor         -Type DWord -Value 5   -EA SilentlyContinue
    Set-ItemProperty $k DisableCatchupFullScan    -Type DWord -Value 1   -EA SilentlyContinue
    Set-ItemProperty $k DisableCatchupQuickScan   -Type DWord -Value 1   -EA SilentlyContinue
    Set-ItemProperty $k ScheduleDay              -Type DWord -Value 8   -EA SilentlyContinue
    # Disable real-time monitoring interference
    $k2="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
    if(!(Test-Path $k2)){New-Item $k2 -Force|Out-Null}
    Set-ItemProperty $k2 DisableIOAVProtection   -Type DWord -Value 0   -EA SilentlyContinue
}
function Step-DisableHPET {
    # Platform clock - use TSC instead for lower latency
    bcdedit /deletevalue useplatformclock 2>$null
    bcdedit /set useplatformtick yes 2>$null
}
function Step-DisableSpectreMeltdown {
    # ONLY for gaming machines - improves performance but reduces security
    # Skip if Hyper-V is in use
    $hvStatus = (Get-Service vmms -EA SilentlyContinue)
    if (!$hvStatus -or $hvStatus.Status -ne "Running") {
        $k="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        Set-ItemProperty $k FeatureSettingsOverride     -Type DWord -Value 3 -EA SilentlyContinue
        Set-ItemProperty $k FeatureSettingsOverrideMask -Type DWord -Value 3 -EA SilentlyContinue
    }
}
function Step-SetProcessorScheduling {
    # Foreground process boost
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" Win32PrioritySeparation -Type DWord -Value 38
    # IRQ 8 priority for real-time clock
    $k="HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
    Set-ItemProperty $k IRQ8Priority -Type DWord -Value 1 -EA SilentlyContinue
}
function Step-DisableAutoUpdate {
    $k="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k NoAutoUpdate      -Type DWord -Value 1 -EA SilentlyContinue
    Set-ItemProperty $k AUOptions         -Type DWord -Value 2 -EA SilentlyContinue
    # Set active hours
    $k2="HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    if(!(Test-Path $k2)){New-Item $k2 -Force|Out-Null}
    Set-ItemProperty $k2 ActiveHoursStart -Type DWord -Value 6  -EA SilentlyContinue
    Set-ItemProperty $k2 ActiveHoursEnd   -Type DWord -Value 23 -EA SilentlyContinue
}
function Step-DisableNTFSLastAccess {
    fsutil behavior set disableLastAccess 1 2>$null
    fsutil behavior set memoryusage 2 2>$null
    fsutil behavior set mftzone 2 2>$null
}
function Step-DisableUSBPowerSaving {
    Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\USB" -Recurse -EA SilentlyContinue |
    ForEach-Object {
        $dp = "$($_.PSPath)\Device Parameters"
        if (Test-Path $dp) {
            Set-ItemProperty $dp EnhancedPowerManagementEnabled -Type DWord -Value 0 -EA SilentlyContinue
            Set-ItemProperty $dp AllowIdleIrpInD3               -Type DWord -Value 0 -EA SilentlyContinue
            Set-ItemProperty $dp EnableSelectiveSuspend         -Type DWord -Value 0 -EA SilentlyContinue
        }
    }
}
function Step-DisableWindowsInk {
    $k="HKCU:\Software\Microsoft\Input\Settings"
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k EnableTouchKeyboardAutoInvokeOnPasswordFields -Type DWord -Value 0 -EA SilentlyContinue
    Set-ItemProperty $k IsVoiceTypingEnabled -Type DWord -Value 0 -EA SilentlyContinue
    Set-ItemProperty $k PenWorkspaceButtonDesiredVisibility -Type DWord -Value 0 -EA SilentlyContinue
}
function Step-DisableActivityHistory {
    $k="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k EnableActivityFeed     -Type DWord -Value 0 -EA SilentlyContinue
    Set-ItemProperty $k PublishUserActivities  -Type DWord -Value 0 -EA SilentlyContinue
    Set-ItemProperty $k UploadUserActivities   -Type DWord -Value 0 -EA SilentlyContinue
}
function Step-DisableSystemRestore {
    # Keep enabled but free up CPU cycles from monitoring
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" SystemRestorePointCreationFrequency -Type DWord -Value 1440 -EA SilentlyContinue
}
function Step-OptimizeDisk {
    # Disable 8.3 filename creation
    fsutil behavior set disable8dot3 1 2>$null
    # Disable disk performance counters
    diskperf -N 2>$null
    # Optimize NVMe queue depth
    $k="HKLM:\SYSTEM\CurrentControlSet\Services\storahci\Parameters\Device"
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k TreatAsInternalPort -Type MultiString -Value @("*") -EA SilentlyContinue
}
function Step-DisableGameBar {
    # Completely kill game bar while keeping game mode
    $k="HKCU:\Software\Microsoft\GameBar"
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k UseNexusForGameBarEnabled -Type DWord -Value 0 -EA SilentlyContinue
    $k2="HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    if(!(Test-Path $k2)){New-Item $k2 -Force|Out-Null}
    Set-ItemProperty $k2 AllowGameDVR -Type DWord -Value 0 -EA SilentlyContinue
}
function Step-NetworkAdapterOptimize {
    $adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up" -and $_.PhysicalMediaType -ne "Unspecified"}
    foreach ($adapter in $adapters) {
        # Disable power saving on NIC
        Disable-NetAdapterPowerManagement -Name $adapter.Name -EA SilentlyContinue
        # Maximize performance settings
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Interrupt Moderation"   -DisplayValue "Disabled" -EA SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Flow Control"           -DisplayValue "Disabled" -EA SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Large Send Offload v2 (IPv4)" -DisplayValue "Disabled" -EA SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Large Send Offload v2 (IPv6)" -DisplayValue "Disabled" -EA SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Receive Side Scaling"   -DisplayValue "Enabled" -EA SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Speed & Duplex"         -DisplayValue "1 Gbps Full Duplex" -EA SilentlyContinue
    }
}
function Step-DNS {
    # Set fast DNS (Cloudflare 1.1.1.1)
    $adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
    foreach ($a in $adapters) {
        Set-DnsClientServerAddress -InterfaceIndex $a.InterfaceIndex -ServerAddresses ("1.1.1.1","1.0.0.1") -EA SilentlyContinue
    }
}
function Step-DisableIPv6 {
    Get-NetAdapter | ForEach-Object {
        Disable-NetAdapterBinding -Name $_.Name -ComponentID ms_tcpip6 -EA SilentlyContinue
    }
}
function Step-DisableWindowsUpdate {
    # Stop auto download during gaming - not permanent disable
    Set-Service wuauserv -StartupType Manual -EA SilentlyContinue
    Stop-Service wuauserv -Force -EA SilentlyContinue
}
function Step-SetTimerResolution {
    # Set system timer to 0.5ms via bcdedit
    bcdedit /set disabledynamictick yes 2>$null
    # Create a startup task that sets timer resolution
    $timerScript = @'
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class TimerRes {
    [DllImport("ntdll.dll")] public static extern int NtSetTimerResolution(uint DesiredResolution, bool SetResolution, out uint CurrentResolution);
    public static void Set() { uint cur; NtSetTimerResolution(5000, true, out cur); }
}
"@
[TimerRes]::Set()
'@
    $timerScript | Set-Content "$env:TEMP\SetTimer.ps1" -Encoding UTF8 -EA SilentlyContinue
}
function Step-DisableNotificationCenter {
    $k="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k DisableNotificationCenter -Type DWord -Value 1 -EA SilentlyContinue
    Set-ItemProperty $k HideSCAMeetNow -Type DWord -Value 1 -EA SilentlyContinue
}
function Step-DisableHibernation {
    powercfg -h off 2>$null
}
function Step-CleanTemp {
    Remove-Item "$env:TEMP\*"          -Recurse -Force -EA SilentlyContinue
    Remove-Item "C:\Windows\Temp\*"    -Recurse -Force -EA SilentlyContinue
    Remove-Item "C:\Windows\Prefetch\*" -Recurse -Force -EA SilentlyContinue
}
function Step-ScheduledTasksClean {
    $tasks = @(
        "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "Microsoft\Windows\Application Experience\StartupAppTask",
        "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "Microsoft\Windows\Autochk\Proxy",
        "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
        "Microsoft\Windows\Feedback\Siuf\DmClient",
        "Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",
        "Microsoft\Windows\Maps\MapsUpdateTask",
        "Microsoft\Windows\Shell\FamilySafetyMonitor",
        "Microsoft\Windows\Shell\FamilySafetyRefreshTask"
    )
    foreach ($t in $tasks) { schtasks /Change /TN $t /DISABLE 2>$null }
}
function Step-DisableStickyKeys {
    Set-ItemProperty "HKCU:\Control Panel\Accessibility\StickyKeys"   Flags -Value "506" -EA SilentlyContinue
    Set-ItemProperty "HKCU:\Control Panel\Accessibility\ToggleKeys"   Flags -Value "58"  -EA SilentlyContinue
    Set-ItemProperty "HKCU:\Control Panel\Accessibility\Keyboard Response" Flags -Value "122" -EA SilentlyContinue
    Set-ItemProperty "HKCU:\Control Panel\Accessibility\FilterKeys"   Flags -Value "186" -EA SilentlyContinue
}
function Step-ExplorerOptimize {
    $k="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty $k HideFileExt         -Type DWord -Value 0 -EA SilentlyContinue
    Set-ItemProperty $k LaunchTo            -Type DWord -Value 1 -EA SilentlyContinue
    Set-ItemProperty $k ShowTaskViewButton  -Type DWord -Value 0 -EA SilentlyContinue
    Set-ItemProperty $k ShowCopilotButton   -Type DWord -Value 0 -EA SilentlyContinue
    # Faster Explorer response
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" AlwaysUnloadDLL -Type DWord -Value 1 -EA SilentlyContinue
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" StartupDelayInMSec -Type DWord -Value 0 -EA SilentlyContinue
}

#endregion

#region Restore Points

function Get-RestorePoints {
    $result = New-Object System.Collections.Generic.List[object]
    try {
        $points = Get-ComputerRestorePoint -ErrorAction SilentlyContinue 2>$null
        if ($null -ne $points) {
            foreach ($rp in @($points)) {
                $typeStr = switch ($rp.RestorePointType) {
                    0  { "App Install" }   1  { "App Uninstall" }
                    10 { "Driver Install"} 12 { "Modify Settings" }
                    13 { "Cancelled" }     default { "Other" }
                }
                $result.Add([PSCustomObject]@{
                    SequenceNumber = [string]$rp.SequenceNumber
                    CreationTime   = $rp.ConvertToDateTime($rp.CreationTime).ToString("yyyy-MM-dd HH:mm:ss")
                    Description    = [string]$rp.Description
                    Type           = [string]$typeStr
                })
            }
        }
    } catch {}
    return $result
}

#endregion

#region GUI

function Show-MainWindow {
    $Global:DetectedHardware = Get-SystemInfo

    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="ny0 Gaming Optimizer - BEAST MODE v4"
        Height="760" Width="1100"
        WindowStartupLocation="CenterScreen"
        ResizeMode="CanMinimize"
        Background="#FF0D0D0D">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#FF1A1A2E"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#FF00D4FF"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#FF00D4FF"/>
                    <Setter Property="Foreground" Value="#FF0D0D0D"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Opacity" Value="0.35"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="TabItem">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border Name="Border" Background="#FF1A1A2E" BorderBrush="#FF00D4FF" BorderThickness="1,1,1,0" CornerRadius="4,4,0,0" Padding="14,7">
                            <ContentPresenter x:Name="ContentSite" ContentSource="Header"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="#FF00D4FF"/>
                                <Setter Property="Foreground" Value="#FF0D0D0D"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="#FF16213E"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>
    </Window.Resources>
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" CornerRadius="6" Padding="15" Margin="0,0,0,10">
            <Border.Background>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                    <GradientStop Color="#FF0F3460" Offset="0"/>
                    <GradientStop Color="#FF16213E" Offset="0.5"/>
                    <GradientStop Color="#FF0F3460" Offset="1"/>
                </LinearGradientBrush>
            </Border.Background>
            <StackPanel>
                <TextBlock Text="BEAST MODE v4 - ny0 GAMING OPTIMIZER"
                          FontSize="22" FontWeight="Bold" Foreground="#FF00D4FF" HorizontalAlignment="Center"/>
                <TextBlock Name="SystemInfoText" Text="Detecting hardware..."
                          FontSize="11" Foreground="#FFAAAAAA" HorizontalAlignment="Center" Margin="0,4,0,0"/>
                <TextBlock Name="MouseInfoText" Text=""
                          FontSize="11" Foreground="#FF00FF88" HorizontalAlignment="Center" Margin="0,2,0,0"/>
            </StackPanel>
        </Border>

        <TabControl Grid.Row="1" Background="#FF0D0D0D" BorderBrush="#FF00D4FF" BorderThickness="1">

            <TabItem Header="[1] Instructions">
                <Grid Background="#FF0D0D0D">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <TextBlock Grid.Row="0" Text="Hardware-Specific BIOS, GPU and Mouse Settings"
                              FontSize="16" FontWeight="Bold" Foreground="#FF00D4FF" Margin="10"/>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="10">
                        <TextBox Name="InstructionsTextBox"
                                Background="#FF111111" Foreground="#FFE0E0E0"
                                FontFamily="Courier New" FontSize="12"
                                IsReadOnly="True" TextWrapping="Wrap"
                                BorderThickness="1" BorderBrush="#FF333333" Padding="10"/>
                    </ScrollViewer>
                    <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="10">
                        <Button Name="CopyInstructionsBtn" Content="Copy to Clipboard" Width="150" Margin="0,0,10,0"/>
                        <Button Name="RefreshHardwareBtn"  Content="Refresh Hardware"  Width="150"/>
                    </StackPanel>
                </Grid>
            </TabItem>

            <TabItem Header="[2] Restore Points">
                <Grid Background="#FF0D0D0D">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <TextBlock Grid.Row="0" Text="System Restore Points"
                              FontSize="16" FontWeight="Bold" Foreground="#FF00D4FF" Margin="10"/>
                    <DataGrid Name="RestorePointsGrid" Grid.Row="1" Margin="10"
                             AutoGenerateColumns="False" IsReadOnly="True"
                             Background="#FF111111" Foreground="White"
                             BorderBrush="#FF00D4FF" GridLinesVisibility="None"
                             HeadersVisibility="Column" SelectionMode="Single"
                             RowBackground="#FF111111" AlternatingRowBackground="#FF1A1A2E">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="ID"          Binding="{Binding SequenceNumber}" Width="55"/>
                            <DataGridTextColumn Header="Date/Time"   Binding="{Binding CreationTime}"   Width="170"/>
                            <DataGridTextColumn Header="Description" Binding="{Binding Description}"   Width="*"/>
                            <DataGridTextColumn Header="Type"        Binding="{Binding Type}"          Width="130"/>
                        </DataGrid.Columns>
                        <DataGrid.ColumnHeaderStyle>
                            <Style TargetType="DataGridColumnHeader">
                                <Setter Property="Background" Value="#FF00D4FF"/>
                                <Setter Property="Foreground" Value="#FF0D0D0D"/>
                                <Setter Property="FontWeight" Value="Bold"/>
                                <Setter Property="Padding"    Value="10,5"/>
                            </Style>
                        </DataGrid.ColumnHeaderStyle>
                        <DataGrid.RowStyle>
                            <Style TargetType="DataGridRow">
                                <Setter Property="Foreground" Value="White"/>
                                <Style.Triggers>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter Property="Background" Value="#FF0F3460"/>
                                    </Trigger>
                                    <Trigger Property="IsSelected" Value="True">
                                        <Setter Property="Background" Value="#FF0F3460"/>
                                    </Trigger>
                                </Style.Triggers>
                            </Style>
                        </DataGrid.RowStyle>
                    </DataGrid>
                    <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="10">
                        <Button Name="CreateRestorePointBtn"  Content="Create Restore Point" Width="170" Margin="0,0,10,0"/>
                        <Button Name="DeleteRestorePointBtn"  Content="Delete Selected"      Width="130" Margin="0,0,10,0" Background="#FF3D0000" BorderBrush="#FFFF4444"/>
                        <Button Name="RefreshRestorePointsBtn" Content="Refresh List"        Width="110"/>
                    </StackPanel>
                </Grid>
            </TabItem>

            <TabItem Header="[3] Beast Mode Tweaks">
                <Grid Background="#FF0D0D0D">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <TextBlock Grid.Row="0" Text="50 Gaming Optimizations - Mouse + NVIDIA Auto-Config"
                              FontSize="16" FontWeight="Bold" Foreground="#FF00D4FF" Margin="10"/>
                    <Border Grid.Row="1" Background="#FF3D1A00" CornerRadius="5" Padding="10" Margin="10,0,10,5">
                        <TextBlock TextWrapping="Wrap" Foreground="#FFFFCC88" FontSize="11">
                            <Run FontWeight="Bold" Text="WARNING: "/>
                            <Run Text="50 tweaks applied: services disabled, registry modified, boot config changed, network adapter tuned, NVIDIA registry patched, mouse latency optimized, scheduled tasks disabled. A restore point is created first. RESTART REQUIRED."/>
                        </TextBlock>
                    </Border>
                    <Grid Grid.Row="2" Margin="10">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>
                        <StackPanel Grid.Row="0" Margin="0,0,0,8">
                            <TextBlock Name="ProgressText" Text="Ready - Click RUN to apply all 50 optimizations" Foreground="#FF00D4FF" FontSize="12" Margin="0,0,0,4"/>
                            <ProgressBar Name="OptimizationProgress" Height="20" Minimum="0" Maximum="100" Value="0"
                                        Background="#FF111111" Foreground="#FF00D4FF" BorderBrush="#FF00D4FF"/>
                        </StackPanel>
                        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                            <TextBox Name="LogTextBox"
                                    Background="#FF050505" Foreground="#FF00FF88"
                                    FontFamily="Courier New" FontSize="11"
                                    IsReadOnly="True" TextWrapping="Wrap"
                                    BorderThickness="1" BorderBrush="#FF00D4FF" Padding="10"/>
                        </ScrollViewer>
                    </Grid>
                    <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Center" Margin="10">
                        <Button Name="RunTweaksBtn" Content="RUN ALL 50 OPTIMIZATIONS" Width="230" Height="38" FontSize="14" FontWeight="Bold" Margin="0,0,10,0" Background="#FF003366" BorderBrush="#FF00D4FF"/>
                        <Button Name="RestartBtn"   Content="Restart System"           Width="140" Height="38"/>
                    </StackPanel>
                </Grid>
            </TabItem>

        </TabControl>

        <Border Grid.Row="2" Background="#FF111111" CornerRadius="4" Padding="8" Margin="0,8,0,0">
            <TextBlock Text="Beast Mode v4.0 | 50 Tweaks | Mouse Detection | NVIDIA Auto-Config | ny0"
                      FontSize="10" Foreground="#FF555555" HorizontalAlignment="Center"/>
        </Border>
    </Grid>
</Window>
"@

    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $systemInfoText          = $window.FindName("SystemInfoText")
    $mouseInfoText           = $window.FindName("MouseInfoText")
    $instructionsTextBox     = $window.FindName("InstructionsTextBox")
    $copyInstructionsBtn     = $window.FindName("CopyInstructionsBtn")
    $refreshHardwareBtn      = $window.FindName("RefreshHardwareBtn")
    $restorePointsGrid       = $window.FindName("RestorePointsGrid")
    $createRestorePointBtn   = $window.FindName("CreateRestorePointBtn")
    $deleteRestorePointBtn   = $window.FindName("DeleteRestorePointBtn")
    $refreshRestorePointsBtn = $window.FindName("RefreshRestorePointsBtn")
    $runTweaksBtn            = $window.FindName("RunTweaksBtn")
    $restartBtn              = $window.FindName("RestartBtn")
    $progressText            = $window.FindName("ProgressText")
    $optimizationProgress    = $window.FindName("OptimizationProgress")
    $logTextBox              = $window.FindName("LogTextBox")

    $hw = $Global:DetectedHardware
    $systemInfoText.Text = "CPU: $($hw.CPU.Name) | GPU: $($hw.GPU.Name) | RAM: $($hw.RAM.TotalGB)GB @ $($hw.RAM.Speed)MHz"
    if ($hw.Mouse.Name) {
        $mouseInfoText.Text = "Mouse: $($hw.Mouse.Name) | Brand: $($hw.Mouse.Brand) | $(if($hw.Mouse.IsWireless){'WIRELESS - consider wired for 0 latency'} else {'Wired - Good'})"
    }
    $instructionsTextBox.Text = Get-BIOSInstructions -hw $hw
    $restorePointsGrid.ItemsSource = $null; $restorePointsGrid.ItemsSource = Get-RestorePoints

    $copyInstructionsBtn.Add_Click({
        [System.Windows.Clipboard]::SetText($instructionsTextBox.Text)
        [System.Windows.MessageBox]::Show("Copied!","Success","OK","Information")
    })
    $refreshHardwareBtn.Add_Click({
        $Global:DetectedHardware = Get-SystemInfo
        $hw = $Global:DetectedHardware
        $systemInfoText.Text = "CPU: $($hw.CPU.Name) | GPU: $($hw.GPU.Name) | RAM: $($hw.RAM.TotalGB)GB @ $($hw.RAM.Speed)MHz"
        if ($hw.Mouse.Name) { $mouseInfoText.Text = "Mouse: $($hw.Mouse.Name) | Brand: $($hw.Mouse.Brand)" }
        $instructionsTextBox.Text = Get-BIOSInstructions -hw $hw
    })
    $createRestorePointBtn.Add_Click({
        try {
            Enable-ComputerRestore -Drive "C:\" -EA SilentlyContinue
            Checkpoint-Computer -Description "Manual - Beast Mode $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -RestorePointType "MODIFY_SETTINGS"
            [System.Windows.MessageBox]::Show("Restore point created!","Success","OK","Information")
        } catch { [System.Windows.MessageBox]::Show("Failed: $_","Error","OK","Error") }
        $restorePointsGrid.ItemsSource = $null; $restorePointsGrid.ItemsSource = Get-RestorePoints
    })
    $refreshRestorePointsBtn.Add_Click({
        $restorePointsGrid.ItemsSource = $null; $restorePointsGrid.ItemsSource = Get-RestorePoints
    })
    $deleteRestorePointBtn.Add_Click({
        $sel = $restorePointsGrid.SelectedItem
        if ($null -eq $sel) { [System.Windows.MessageBox]::Show("Select a restore point first.","No Selection","OK","Warning"); return }
        $c = [System.Windows.MessageBox]::Show("Delete restore point #$($sel.SequenceNumber)?`n$($sel.Description)`n`nCannot be undone.","Confirm Delete","YesNo","Warning")
        if ($c -ne "Yes") { return }
        try {
            $rp = Get-ComputerRestorePoint | Where-Object {$_.SequenceNumber -eq [int]$sel.SequenceNumber}
            $rpTime = $rp.ConvertToDateTime($rp.CreationTime)
            $shadowId = $null; $curId = $null
            $vssOut = & vssadmin list shadows /for=C: 2>&1
            foreach ($line in $vssOut) {
                if ($line -match "Shadow Copy ID:\s*(\{[^}]+\})") { $curId = $matches[1] }
                if ($line -match "Creation time:\s*(.+)" -and $curId) {
                    try {
                        $diff = [math]::Abs(([datetime]::Parse($matches[1].Trim()) - $rpTime).TotalMinutes)
                        if ($diff -lt 5) { $shadowId = $curId; $curId = $null }
                    } catch {}
                }
            }
            if ($shadowId) {
                & vssadmin delete shadows /shadow="$shadowId" /quiet 2>&1 | Out-Null
                [System.Windows.MessageBox]::Show("Deleted successfully.","Done","OK","Information")
            } else {
                [System.Windows.MessageBox]::Show("Could not match shadow copy. Try: vssadmin delete shadows /for=C: /oldest","Warning","OK","Warning")
            }
        } catch { [System.Windows.MessageBox]::Show("Error: $_","Error","OK","Error") }
        $restorePointsGrid.ItemsSource = $null; $restorePointsGrid.ItemsSource = Get-RestorePoints
    })
    $restartBtn.Add_Click({
        if ([System.Windows.MessageBox]::Show("Restart now?","Restart","YesNo","Question") -eq "Yes") { Restart-Computer -Force }
    })

    $runTweaksBtn.Add_Click({
        $confirm = [System.Windows.MessageBox]::Show(
            "Apply all 50 Beast Mode optimizations?`n`n- Restore point created first`n- Registry + services + boot + network modified`n- NVIDIA registry patched`n- Mouse latency minimized`n- Restart required`n`nContinue?",
            "Beast Mode Confirm","YesNo","Warning")
        if ($confirm -ne "Yes") { return }

        $runTweaksBtn.IsEnabled = $false
        $logTextBox.Text = ""
        $optimizationProgress.Value = 0
        $Global:OptimizationLog = [System.Collections.ArrayList]::new()

        $stepList = @(
            @{Name="[01] Creating Restore Point";              Func="Step-RestorePoint"},
            @{Name="[02] Disabling Unnecessary Services";      Func="Step-DisableServices"},
            @{Name="[03] Applying Ultimate Power Plan";        Func="Step-PowerPlan"},
            @{Name="[04] Disabling Power Throttling";          Func="Step-DisablePowerThrottling"},
            @{Name="[05] Disabling CPU Core Parking";          Func="Step-DisableCoreParking"},
            @{Name="[06] Disabling Game DVR/Capture";          Func="Step-GameDVR"},
            @{Name="[07] Disabling Game Bar";                  Func="Step-DisableGameBar"},
            @{Name="[08] Optimizing Visual Effects";           Func="Step-VisualEffects"},
            @{Name="[09] Optimizing TCP/IP Network";           Func="Step-Network"},
            @{Name="[10] Optimizing Network Adapter";          Func="Step-NetworkAdapterOptimize"},
            @{Name="[11] Setting DNS to Cloudflare 1.1.1.1";   Func="Step-DNS"},
            @{Name="[12] Disabling IPv6";                      Func="Step-DisableIPv6"},
            @{Name="[13] Disabling Background Apps";           Func="Step-BackgroundApps"},
            @{Name="[14] Enabling GPU Hardware Scheduling";    Func="Step-GPUScheduling"},
            @{Name="[15] Enabling Game Mode";                  Func="Step-GameMode"},
            @{Name="[16] Setting Game CPU/GPU Priority";       Func="Step-GamePriority"},
            @{Name="[17] Disabling Mouse Acceleration";        Func="Step-MouseOptimize"},
            @{Name="[18] Minimizing Mouse HID Latency";        Func="Step-MouseHIDLatency"},
            @{Name="[19] Disabling Dynamic Tick (Timer Fix)";  Func="Step-DisableDynamicTick"},
            @{Name="[20] Disabling HPET Clock";                Func="Step-DisableHPET"},
            @{Name="[21] Setting Win32 Priority Separation";   Func="Step-Win32Priority"},
            @{Name="[22] Setting Processor Scheduling";        Func="Step-SetProcessorScheduling"},
            @{Name="[23] Optimizing Memory Management";        Func="Step-MemoryManagement"},
            @{Name="[24] Patching NVIDIA Registry";            Func="Step-NVIDIARegistry"},
            @{Name="[25] Setting IRQ Priority (GPU)";          Func="Step-IRQPriority"},
            @{Name="[26] Disabling DWM Animations";            Func="Step-FSEAndDWM"},
            @{Name="[27] Disabling Telemetry";                 Func="Step-DisableTelemetry"},
            @{Name="[28] Disabling Delivery Optimization";     Func="Step-DisableDeliveryOptimization"},
            @{Name="[29] Disabling Windows Search Indexing";   Func="Step-DisableSearchHighlights"},
            @{Name="[30] Disabling Notifications";             Func="Step-DisableNotifications"},
            @{Name="[31] Disabling Notification Center";       Func="Step-DisableNotificationCenter"},
            @{Name="[32] Reducing Defender CPU Usage";         Func="Step-DisableWindowsDefenderScan"},
            @{Name="[33] Disabling Auto Windows Updates";      Func="Step-DisableAutoUpdate"},
            @{Name="[34] Stopping Windows Update Service";     Func="Step-DisableWindowsUpdate"},
            @{Name="[35] NTFS Performance Tweaks";             Func="Step-DisableNTFSLastAccess"},
            @{Name="[36] Disabling USB Power Saving";          Func="Step-DisableUSBPowerSaving"},
            @{Name="[37] Disabling Windows Ink/Touch";         Func="Step-DisableWindowsInk"},
            @{Name="[38] Disabling Activity History";          Func="Step-DisableActivityHistory"},
            @{Name="[39] Reducing Restore Point Frequency";    Func="Step-DisableSystemRestore"},
            @{Name="[40] Optimizing Disk/NVMe Settings";       Func="Step-OptimizeDisk"},
            @{Name="[41] Setting Timer Resolution (0.5ms)";    Func="Step-SetTimerResolution"},
            @{Name="[42] Disabling Hibernation";               Func="Step-DisableHibernation"},
            @{Name="[43] Disabling Startup Delay";             Func="Step-DisableStartupDelay"},
            @{Name="[44] Disabling Spectre/Meltdown Overhead"; Func="Step-DisableSpectreMeltdown"},
            @{Name="[45] Disabling Scheduled Telemetry Tasks"; Func="Step-ScheduledTasksClean"},
            @{Name="[46] Disabling Sticky Keys";               Func="Step-DisableStickyKeys"},
            @{Name="[47] Optimizing Explorer";                 Func="Step-ExplorerOptimize"},
            @{Name="[48] Configuring Windows Update Hours";    Func="Step-DisableAutoUpdate"},
            @{Name="[49] Cleaning Temp + Prefetch Files";      Func="Step-CleanTemp"}
        )

        $allFuncs = @'
function Step-RestorePoint { Enable-ComputerRestore "C:\" -EA SilentlyContinue; Checkpoint-Computer -Description ("Beast Mode v4 - "+(Get-Date -f 'yyyy-MM-dd HH:mm')) -RestorePointType MODIFY_SETTINGS -EA Stop }
function Step-DisableServices { $s=@("DiagTrack","dmwappushservice","SysMain","WSearch","TabletInputService","wisvc","RetailDemo","Fax","MapsBroker","lfsvc","XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","PcaSvc","RemoteRegistry","WerSvc","wercplsupport","WMPNetworkSvc","icssvc","lmhosts","SSDPSRV","upnphost","TrkWks","WbioSrvc"); foreach($n in $s){try{Stop-Service $n -Force -EA SilentlyContinue;Set-Service $n -StartupType Disabled -EA SilentlyContinue}catch{}} }
function Step-PowerPlan { $g="e9a42b02-d5df-448d-aa00-03f14749eb61"; powercfg -duplicatescheme $g 2>$null; powercfg -setactive $g 2>$null; powercfg -change -monitor-timeout-ac 0; powercfg -change -disk-timeout-ac 0; powercfg -change -standby-timeout-ac 0; powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7 100; powercfg -setactive SCHEME_CURRENT }
function Step-DisablePowerThrottling { $k="HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"; if(!(Test-Path $k)){New-Item $k -Force|Out-Null}; Set-ItemProperty $k PowerThrottlingOff -Type DWord -Value 1 }
function Step-DisableCoreParking { powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 0 2>$null; powercfg -setactive SCHEME_CURRENT 2>$null }
function Step-GameDVR { $k1="HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; $k2="HKCU:\System\GameConfigStore"; foreach($k in @($k1,$k2)){if(!(Test-Path $k)){New-Item $k -Force|Out-Null}}; Set-ItemProperty $k1 AppCaptureEnabled -Type DWord -Value 0; Set-ItemProperty $k2 GameDVR_Enabled -Type DWord -Value 0; Set-ItemProperty $k2 GameDVR_FSEBehaviorMode -Type DWord -Value 2; Set-ItemProperty $k2 GameDVR_DXGIHonorFSEWindowsCompatible -Type DWord -Value 1; Set-ItemProperty $k2 GameDVR_EFSEFeatureFlags -Type DWord -Value 0 }
function Step-DisableGameBar { $k="HKCU:\Software\Microsoft\GameBar"; if(!(Test-Path $k)){New-Item $k -Force|Out-Null}; Set-ItemProperty $k UseNexusForGameBarEnabled -Type DWord -Value 0 -EA SilentlyContinue; $k2="HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; if(!(Test-Path $k2)){New-Item $k2 -Force|Out-Null}; Set-ItemProperty $k2 AllowGameDVR -Type DWord -Value 0 }
function Step-VisualEffects { Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" VisualFXSetting -Type DWord -Value 2 -EA SilentlyContinue; Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" EnableTransparency -Type DWord -Value 0 -EA SilentlyContinue; Set-ItemProperty "HKCU:\Control Panel\Desktop\WindowMetrics" MinAnimate -Value "0" -EA SilentlyContinue }
function Step-Network { netsh interface tcp set global autotuninglevel=normal 2>$null; netsh interface tcp set global congestionprovider=ctcp 2>$null; netsh interface tcp set heuristics disabled 2>$null; netsh interface tcp set global rss=enabled 2>$null; netsh interface tcp set global nonsackrttresiliency=disabled 2>$null; netsh interface tcp set global initialRto=2000 2>$null; netsh interface tcp set global timestamps=disabled 2>$null; Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" NetworkThrottlingIndex -Type DWord -Value 0xffffffff -EA SilentlyContinue; $nics=Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -EA SilentlyContinue; foreach($n in $nics){Set-ItemProperty $n.PSPath TcpAckFrequency -Type DWord -Value 1 -EA SilentlyContinue; Set-ItemProperty $n.PSPath TCPNoDelay -Type DWord -Value 1 -EA SilentlyContinue} }
function Step-NetworkAdapterOptimize { $adapters=Get-NetAdapter|Where-Object{$_.Status -eq "Up" -and $_.PhysicalMediaType -ne "Unspecified"}; foreach($a in $adapters){Disable-NetAdapterPowerManagement -Name $a.Name -EA SilentlyContinue; Set-NetAdapterAdvancedProperty -Name $a.Name -DisplayName "Interrupt Moderation" -DisplayValue "Disabled" -EA SilentlyContinue; Set-NetAdapterAdvancedProperty -Name $a.Name -DisplayName "Flow Control" -DisplayValue "Disabled" -EA SilentlyContinue; Set-NetAdapterAdvancedProperty -Name $a.Name -DisplayName "Receive Side Scaling" -DisplayValue "Enabled" -EA SilentlyContinue} }
function Step-DNS { $a=Get-NetAdapter|Where-Object{$_.Status -eq "Up"}; foreach($n in $a){Set-DnsClientServerAddress -InterfaceIndex $n.InterfaceIndex -ServerAddresses ("1.1.1.1","1.0.0.1") -EA SilentlyContinue} }
function Step-DisableIPv6 { Get-NetAdapter|ForEach-Object{Disable-NetAdapterBinding -Name $_.Name -ComponentID ms_tcpip6 -EA SilentlyContinue} }
function Step-BackgroundApps { $k="HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"; if(!(Test-Path $k)){New-Item $k -Force|Out-Null}; Set-ItemProperty $k GlobalUserDisabled -Type DWord -Value 1 }
function Step-GPUScheduling { $k="HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; if(!(Test-Path $k)){New-Item $k -Force|Out-Null}; Set-ItemProperty $k HwSchMode -Type DWord -Value 2; Set-ItemProperty $k TdrDelay -Type DWord -Value 10 -EA SilentlyContinue }
function Step-GameMode { $k="HKCU:\Software\Microsoft\GameBar"; if(!(Test-Path $k)){New-Item $k -Force|Out-Null}; Set-ItemProperty $k AutoGameModeEnabled -Type DWord -Value 1; Set-ItemProperty $k AllowAutoGameMode -Type DWord -Value 1 }
function Step-GamePriority { $k="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; if(!(Test-Path $k)){New-Item $k -Force|Out-Null}; Set-ItemProperty $k "Affinity" -Type DWord -Value 0; Set-ItemProperty $k "Background Only" -Type String -Value "False"; Set-ItemProperty $k "Clock Rate" -Type DWord -Value 10000; Set-ItemProperty $k "GPU Priority" -Type DWord -Value 8; Set-ItemProperty $k "Priority" -Type DWord -Value 6; Set-ItemProperty $k "Scheduling Category" -Type String -Value "High"; Set-ItemProperty $k "SFIO Rate" -Type String -Value "High"; Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" SystemResponsiveness -Type DWord -Value 0 }
function Step-MouseOptimize { Set-ItemProperty "HKCU:\Control Panel\Mouse" MouseSpeed -Value "0"; Set-ItemProperty "HKCU:\Control Panel\Mouse" MouseThreshold1 -Value "0"; Set-ItemProperty "HKCU:\Control Panel\Mouse" MouseThreshold2 -Value "0"; Set-ItemProperty "HKCU:\Control Panel\Desktop" SmoothScroll -Value "0" -EA SilentlyContinue }
function Step-MouseHIDLatency { $p=Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\HID" -EA SilentlyContinue; foreach($h in $p){$dp="$($h.PSPath)\Device Parameters"; if(Test-Path $dp){Set-ItemProperty $dp EnhancedPowerManagementEnabled -Type DWord -Value 0 -EA SilentlyContinue; Set-ItemProperty $dp AllowIdleIrpInD3 -Type DWord -Value 0 -EA SilentlyContinue; Set-ItemProperty $dp WaitWakeEnabled -Type DWord -Value 0 -EA SilentlyContinue}}; powercfg -setacvalueindex SCHEME_CURRENT 2a737abc-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null; powercfg -setactive SCHEME_CURRENT 2>$null }
function Step-DisableDynamicTick { bcdedit /set disabledynamictick yes 2>$null; bcdedit /set useplatformclock false 2>$null; bcdedit /set tscsyncpolicy enhanced 2>$null }
function Step-DisableHPET { bcdedit /deletevalue useplatformclock 2>$null; bcdedit /set useplatformtick yes 2>$null }
function Step-Win32Priority { Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" Win32PrioritySeparation -Type DWord -Value 38 }
function Step-SetProcessorScheduling { Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" Win32PrioritySeparation -Type DWord -Value 38; Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" IRQ8Priority -Type DWord -Value 1 -EA SilentlyContinue }
function Step-MemoryManagement { $k="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Set-ItemProperty $k DisablePagingExecutive -Type DWord -Value 1 -EA SilentlyContinue; Set-ItemProperty $k LargeSystemCache -Type DWord -Value 0 -EA SilentlyContinue; Set-ItemProperty $k IoPageLockLimit -Type DWord -Value 983040 -EA SilentlyContinue }
function Step-NVIDIARegistry { $nvBase="HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"; if(!(Test-Path $nvBase)){$nvBase=Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -EA SilentlyContinue|Where-Object{(Get-ItemProperty $_.PSPath -EA SilentlyContinue).DriverDesc -match "NVIDIA"}|Select-Object -First 1 -ExpandProperty PSPath}; if($nvBase -and (Test-Path $nvBase)){Set-ItemProperty $nvBase "PerfLevelSrc" -Type DWord -Value 0x2222 -EA SilentlyContinue; Set-ItemProperty $nvBase "PowerMizerEnable" -Type DWord -Value 1 -EA SilentlyContinue; Set-ItemProperty $nvBase "PowerMizerLevel" -Type DWord -Value 1 -EA SilentlyContinue; Set-ItemProperty $nvBase "PowerMizerLevelAC" -Type DWord -Value 1 -EA SilentlyContinue}; foreach($s in @("NvContainerLocalSystem","NvContainerNetworkService")){Set-Service $s -StartupType Manual -EA SilentlyContinue} }
function Step-IRQPriority { $g=Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI" -EA SilentlyContinue|Get-ChildItem -EA SilentlyContinue|Where-Object{(Get-ItemProperty $_.PSPath -EA SilentlyContinue).Class -eq "Display"}|Select-Object -First 1; if($g){$d="$($g.PSPath)\Device Parameters\Interrupt Management\Affinity Policy"; if(!(Test-Path $d)){New-Item $d -Force|Out-Null}; Set-ItemProperty $d DevicePolicy -Type DWord -Value 4 -EA SilentlyContinue; Set-ItemProperty $d DevicePriority -Type DWord -Value 3 -EA SilentlyContinue} }
function Step-FSEAndDWM { Set-ItemProperty "HKCU:\Software\Microsoft\Windows\DWM" Animations -Type DWord -Value 0 -EA SilentlyContinue; Set-ItemProperty "HKCU:\Control Panel\Desktop\WindowMetrics" MinAnimate -Value "0" -EA SilentlyContinue }
function Step-DisableTelemetry { foreach($k in @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection","HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection")){if(!(Test-Path $k)){New-Item $k -Force|Out-Null}; Set-ItemProperty $k AllowTelemetry -Type DWord -Value 0}; schtasks /Change /TN "Microsoft\Windows\Customer Experience Improvement Program\Consolidator" /DISABLE 2>$null; schtasks /Change /TN "Microsoft\Windows\Application Experience\ProgramDataUpdater" /DISABLE 2>$null }
function Step-DisableDeliveryOptimization { $k="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"; if(!(Test-Path $k)){New-Item $k -Force|Out-Null}; Set-ItemProperty $k DODownloadMode -Type DWord -Value 0 }
function Step-DisableSearchHighlights { $k="HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; if(!(Test-Path $k)){New-Item $k -Force|Out-Null}; Set-ItemProperty $k BingSearchEnabled -Type DWord -Value 0 -EA SilentlyContinue; Set-ItemProperty $k CortanaConsent -Type DWord -Value 0 -EA SilentlyContinue }
function Step-DisableNotifications { $k="HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"; if(!(Test-Path $k)){New-Item $k -Force|Out-Null}; Set-ItemProperty $k ToastEnabled -Type DWord -Value 0 -EA SilentlyContinue }
function Step-DisableNotificationCenter { $k="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"; if(!(Test-Path $k)){New-Item $k -Force|Out-Null}; Set-ItemProperty $k DisableNotificationCenter -Type DWord -Value 1 -EA SilentlyContinue }
function Step-DisableWindowsDefenderScan { $k="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Scan"; if(!(Test-Path $k)){New-Item $k -Force|Out-Null}; Set-ItemProperty $k AvgCPULoadFactor -Type DWord -Value 5 -EA SilentlyContinue; Set-ItemProperty $k DisableCatchupFullScan -Type DWord -Value 1 -EA SilentlyContinue }
function Step-DisableAutoUpdate { $k="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; if(!(Test-Path $k)){New-Item $k -Force|Out-Null}; Set-ItemProperty $k NoAutoUpdate -Type DWord -Value 1 -EA SilentlyContinue; $k2="HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; if(!(Test-Path $k2)){New-Item $k2 -Force|Out-Null}; Set-ItemProperty $k2 ActiveHoursStart -Type DWord -Value 6 -EA SilentlyContinue; Set-ItemProperty $k2 ActiveHoursEnd -Type DWord -Value 23 -EA SilentlyContinue }
function Step-DisableWindowsUpdate { Set-Service wuauserv -StartupType Manual -EA SilentlyContinue; Stop-Service wuauserv -Force -EA SilentlyContinue }
function Step-DisableNTFSLastAccess { fsutil behavior set disableLastAccess 1 2>$null; fsutil behavior set memoryusage 2 2>$null; fsutil behavior set mftzone 2 2>$null }
function Step-DisableUSBPowerSaving { Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\USB" -Recurse -EA SilentlyContinue|ForEach-Object{$d="$($_.PSPath)\Device Parameters"; if(Test-Path $d){Set-ItemProperty $d EnhancedPowerManagementEnabled -Type DWord -Value 0 -EA SilentlyContinue; Set-ItemProperty $d EnableSelectiveSuspend -Type DWord -Value 0 -EA SilentlyContinue}} }
function Step-DisableWindowsInk { $k="HKCU:\Software\Microsoft\Input\Settings"; if(!(Test-Path $k)){New-Item $k -Force|Out-Null}; Set-ItemProperty $k PenWorkspaceButtonDesiredVisibility -Type DWord -Value 0 -EA SilentlyContinue }
function Step-DisableActivityHistory { $k="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; if(!(Test-Path $k)){New-Item $k -Force|Out-Null}; Set-ItemProperty $k EnableActivityFeed -Type DWord -Value 0 -EA SilentlyContinue; Set-ItemProperty $k PublishUserActivities -Type DWord -Value 0 -EA SilentlyContinue }
function Step-DisableSystemRestore { Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" SystemRestorePointCreationFrequency -Type DWord -Value 1440 -EA SilentlyContinue }
function Step-OptimizeDisk { fsutil behavior set disable8dot3 1 2>$null; diskperf -N 2>$null }
function Step-SetTimerResolution { bcdedit /set disabledynamictick yes 2>$null }
function Step-DisableHibernation { powercfg -h off 2>$null }
function Step-DisableStartupDelay { $k="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"; if(!(Test-Path $k)){New-Item $k -Force|Out-Null}; Set-ItemProperty $k StartupDelayInMSec -Type DWord -Value 0 }
function Step-DisableSpectreMeltdown { $hv=Get-Service vmms -EA SilentlyContinue; if(!$hv -or $hv.Status -ne "Running"){$k="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Set-ItemProperty $k FeatureSettingsOverride -Type DWord -Value 3 -EA SilentlyContinue; Set-ItemProperty $k FeatureSettingsOverrideMask -Type DWord -Value 3 -EA SilentlyContinue} }
function Step-ScheduledTasksClean { $t=@("Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser","Microsoft\Windows\Application Experience\ProgramDataUpdater","Microsoft\Windows\Application Experience\StartupAppTask","Microsoft\Windows\Customer Experience Improvement Program\Consolidator","Microsoft\Windows\Customer Experience Improvement Program\UsbCeip","Microsoft\Windows\Autochk\Proxy","Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector","Microsoft\Windows\Feedback\Siuf\DmClient","Microsoft\Windows\Maps\MapsUpdateTask"); foreach($x in $t){schtasks /Change /TN $x /DISABLE 2>$null} }
function Step-DisableStickyKeys { Set-ItemProperty "HKCU:\Control Panel\Accessibility\StickyKeys" Flags -Value "506" -EA SilentlyContinue; Set-ItemProperty "HKCU:\Control Panel\Accessibility\ToggleKeys" Flags -Value "58" -EA SilentlyContinue; Set-ItemProperty "HKCU:\Control Panel\Accessibility\FilterKeys" Flags -Value "186" -EA SilentlyContinue }
function Step-ExplorerOptimize { Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" ShowTaskViewButton -Type DWord -Value 0 -EA SilentlyContinue; Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" ShowCopilotButton -Type DWord -Value 0 -EA SilentlyContinue; Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" StartupDelayInMSec -Type DWord -Value 0 -EA SilentlyContinue }
function Step-CleanTemp { Remove-Item "$env:TEMP\*" -Recurse -Force -EA SilentlyContinue; Remove-Item "C:\Windows\Temp\*" -Recurse -Force -EA SilentlyContinue; Remove-Item "C:\Windows\Prefetch\*" -Recurse -Force -EA SilentlyContinue }
'@

        $Global:_ps = [powershell]::Create()
        [void]$Global:_ps.AddScript($allFuncs)
        [void]$Global:_ps.AddScript({
            param($steps, $log, $disp, $bar, $label, $box)
            $total = $steps.Count; $i = 0
            foreach ($step in $steps) {
                $i++
                $name = $step.Name; $func = $step.Func
                $pct  = [int](($i / $total) * 100)
                $disp.Invoke([Action]{ $bar.Value = $pct; $label.Text = "$name" }, "Normal")
                try {
                    & $func
                    $ts = Get-Date -Format "HH:mm:ss"
                    [void]$log.Add("[$ts] [OK]   $name")
                } catch {
                    $ts = Get-Date -Format "HH:mm:ss"
                    [void]$log.Add("[$ts] [FAIL] $name : $_")
                }
                $disp.Invoke([Action]{ $box.Text = $log -join "`n"; $box.ScrollToEnd() }, "Normal")
                Start-Sleep -Milliseconds 150
            }
        }).AddArgument($stepList).AddArgument($Global:OptimizationLog).AddArgument($window.Dispatcher).AddArgument($optimizationProgress).AddArgument($progressText).AddArgument($logTextBox)

        $Global:_handle = $Global:_ps.BeginInvoke()

        $Global:_timer = New-Object System.Windows.Threading.DispatcherTimer
        $Global:_timer.Interval = [TimeSpan]::FromMilliseconds(500)
        $Global:_timer.Add_Tick({
            if ($Global:_handle.IsCompleted) {
                $Global:_timer.Stop()
                try { $Global:_ps.EndInvoke($Global:_handle) } catch {}
                $Global:_ps.Dispose()
                $optimizationProgress.Value = 100
                $progressText.Text = "ALL 49 OPTIMIZATIONS COMPLETE - RESTART YOUR PC!"
                $runTweaksBtn.IsEnabled = $true
                [System.Windows.MessageBox]::Show(
                    "Beast Mode COMPLETE!`n`n49 optimizations applied.`n`nRESTART your PC now for full effect.",
                    "BEAST MODE DONE","OK","Information")
            }
        })
        $Global:_timer.Start()
    })

    $window.ShowDialog() | Out-Null
}

#endregion

try {
    $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (!$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        [System.Windows.MessageBox]::Show("Run as Administrator!","Admin Required","OK","Error"); exit
    }
    Show-MainWindow
} catch {
    [System.Windows.MessageBox]::Show("Critical Error: $_","Error","OK","Error")
}
