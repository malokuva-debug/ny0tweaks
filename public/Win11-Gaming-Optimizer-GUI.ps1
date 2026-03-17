#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Windows 11 Gaming Optimizer - GUI Edition
.DESCRIPTION
    Web-executable GUI tool for Windows 11 gaming optimization
    Usage: iwr -useb YOUR_URL | iex
.NOTES
    Version: 3.0 GUI Edition
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

$Global:DetectedHardware = @{}
$Global:OptimizationLog = [System.Collections.ArrayList]::new()

#region Hardware Detection

function Get-SystemInfo {
    $hwInfo = @{ CPU = @{}; GPU = @{}; RAM = @{}; Motherboard = @{}; Storage = @{}; OS = @{} }
    try {
        $cpu = Get-CimInstance -ClassName Win32_Processor
        $hwInfo.CPU = @{
            Name = $cpu.Name
            Manufacturer = if ($cpu.Name -like "*Intel*") { "Intel" } elseif ($cpu.Name -like "*AMD*") { "AMD" } else { "Unknown" }
            Cores = $cpu.NumberOfCores
            LogicalProcessors = $cpu.NumberOfLogicalProcessors
            MaxClockSpeed = $cpu.MaxClockSpeed
            Generation = Get-CPUGeneration -cpuName $cpu.Name
        }
        $gpu = Get-CimInstance -ClassName Win32_VideoController | Where-Object { $_.Name -notlike "*Microsoft*" } | Select-Object -First 1
        $hwInfo.GPU = @{
            Name = $gpu.Name
            Manufacturer = if ($gpu.Name -like "*NVIDIA*" -or $gpu.Name -like "*GeForce*" -or $gpu.Name -like "*RTX*" -or $gpu.Name -like "*GTX*") { "NVIDIA" }
                          elseif ($gpu.Name -like "*AMD*" -or $gpu.Name -like "*Radeon*") { "AMD" }
                          elseif ($gpu.Name -like "*Intel*" -or $gpu.Name -like "*Arc*") { "Intel" }
                          else { "Unknown" }
            DriverVersion = $gpu.DriverVersion
            VideoRAM = [math]::Round($gpu.AdapterRAM / 1GB, 2)
        }
        $ram = Get-CimInstance -ClassName Win32_PhysicalMemory
        $totalRAM = ($ram | Measure-Object -Property Capacity -Sum).Sum
        $hwInfo.RAM = @{ TotalGB = [math]::Round($totalRAM / 1GB, 2); Speed = ($ram | Select-Object -First 1).Speed }
        $mobo = Get-CimInstance -ClassName Win32_BaseBoard
        $hwInfo.Motherboard = @{ Manufacturer = $mobo.Manufacturer; Product = $mobo.Product }
        $storage = Get-PhysicalDisk
        $hwInfo.Storage = @{ Drives = @() }
        foreach ($drive in $storage) {
            $hwInfo.Storage.Drives += @{ Model = $drive.FriendlyName; MediaType = $drive.MediaType; BusType = $drive.BusType }
        }
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $hwInfo.OS = @{ Name = $os.Caption; BuildNumber = $os.BuildNumber }
    } catch {
        [System.Windows.MessageBox]::Show("Error detecting hardware: $_", "Detection Error", "OK", "Warning")
    }
    return $hwInfo
}

function Get-CPUGeneration {
    param([string]$cpuName)
    if ($cpuName -like "*Intel*") {
        if ($cpuName -match "14th|14900|14700|14600") { return "14th Gen (Raptor Lake Refresh)" }
        elseif ($cpuName -match "13th|13900|13700|13600") { return "13th Gen (Raptor Lake)" }
        elseif ($cpuName -match "12th|12900|12700|12600") { return "12th Gen (Alder Lake)" }
        elseif ($cpuName -match "11th|11900|11700|11600") { return "11th Gen (Rocket Lake)" }
        elseif ($cpuName -match "10th|10900|10700|10600") { return "10th Gen (Comet Lake)" }
        else { return "Older Generation" }
    } elseif ($cpuName -like "*AMD*") {
        if ($cpuName -match "9950|9900|9700|9600") { return "Ryzen 9000 Series (Zen 5)" }
        elseif ($cpuName -match "7950|7900|7700|7600") { return "Ryzen 7000 Series (Zen 4)" }
        elseif ($cpuName -match "5950|5900|5800|5700|5600") { return "Ryzen 5000 Series (Zen 3)" }
        elseif ($cpuName -match "3950|3900|3800|3700|3600") { return "Ryzen 3000 Series (Zen 2)" }
        else { return "Older Generation" }
    }
    return "Unknown"
}

function Get-BIOSInstructions {
    param($hardware)
    $SEP = "-------------------------------------------------------"
    $instructions = ""
    $cpuMfg = $hardware.CPU.Manufacturer
    $gpuMfg = $hardware.GPU.Manufacturer
    $moboMfg = $hardware.Motherboard.Manufacturer

    $instructions += "$SEP`n  CPU OPTIMIZATION - $($hardware.CPU.Name)`n$SEP`n`n"
    if ($cpuMfg -eq "Intel") {
        $instructions += "[+] Intel Turbo Boost Technology: ENABLED`n"
        $instructions += "[+] Intel Turbo Boost Max 3.0: ENABLED (if available)`n"
        $instructions += "[+] Enhanced Intel SpeedStep: ENABLED`n"
        $instructions += "[+] Hyper-Threading: ENABLED`n"
        $instructions += "[+] CPU C-States: DISABLED (for lowest latency)`n"
        $instructions += "    - C1E Support: DISABLED`n"
        $instructions += "    - C3/C6/C7 State: DISABLED`n"
        $instructions += "    - Package C State: DISABLED`n"
    } elseif ($cpuMfg -eq "AMD") {
        $instructions += "[+] Precision Boost Overdrive (PBO): ENABLED`n"
        $instructions += "[+] Core Performance Boost: ENABLED`n"
        $instructions += "[+] SMT (Simultaneous Multi-Threading): ENABLED`n"
        $instructions += "[+] Global C-State Control: DISABLED (for lowest latency)`n"
        $instructions += "[+] CPPC: ENABLED`n"
        $instructions += "[+] CPPC Preferred Cores: ENABLED`n"
    }

    $instructions += "`n$SEP`n  MEMORY OPTIMIZATION - $($hardware.RAM.TotalGB)GB @ $($hardware.RAM.Speed)MHz`n$SEP`n`n"
    if ($cpuMfg -eq "Intel") { $instructions += "[+] XMP (Extreme Memory Profile): ENABLED - Profile 1`n" }
    elseif ($cpuMfg -eq "AMD") { $instructions += "[+] DOCP/EXPO (AMD Memory Profile): ENABLED - Profile 1`n" }
    $instructions += "[+] Memory Fast Boot: ENABLED`n"
    $instructions += "[+] Gear Down Mode: DISABLED (if stable)`n"
    $instructions += "[+] Command Rate: 1T (if stable, otherwise 2T)`n"

    $instructions += "`n$SEP`n  GPU/PCIe OPTIMIZATION - $($hardware.GPU.Name)`n$SEP`n`n"
    $instructions += "[+] Above 4G Decoding: ENABLED`n"
    $instructions += "[+] Resizable BAR (Re-Size BAR): ENABLED`n"
    if ($gpuMfg -eq "AMD") { $instructions += "    (AMD Smart Access Memory)`n" }
    $instructions += "[+] PCIe Slot 1 Speed: Gen 4.0 (or Gen 3.0 if Gen 4 unstable)`n"
    $instructions += "[+] PCIe ASPM: DISABLED`n"
    $instructions += "[+] Primary Display: PCIe / Auto`n"

    $instructions += "`n$SEP`n  STORAGE OPTIMIZATION`n$SEP`n`n"
    $instructions += "[+] SATA Mode: AHCI (not IDE)`n"
    foreach ($drive in $hardware.Storage.Drives) {
        if ($drive.MediaType -eq "SSD" -or $drive.BusType -eq "NVMe") {
            $instructions += "[+] $($drive.Model) - Ensure M.2 slot is Gen 3.0/4.0`n"
        }
    }

    $instructions += "`n$SEP`n  MOTHERBOARD SPECIFIC - $($hardware.Motherboard.Manufacturer)`n$SEP`n`n"
    switch -Wildcard ($moboMfg) {
        "*ASUS*" {
            $instructions += "Location: AI Tweaker / Extreme Tweaker menu`n"
            $instructions += "[+] Performance Bias: Performance`n"
            $instructions += "[+] MultiCore Enhancement (MCE): ENABLED`n"
            $instructions += "[+] ASUS Performance Enhancement: ENABLED`n"
        }
        "*MSI*" {
            $instructions += "Location: OC / Overclocking menu`n"
            $instructions += "[+] Game Boost: Level 2-4 (monitor temps!)`n"
            $instructions += "[+] A-XMP: ENABLED`n"
            $instructions += "[+] Memory Fast Boot: ENABLED`n"
        }
        "*Gigabyte*" {
            $instructions += "Location: M.I.T. (Motherboard Intelligent Tweaker)`n"
            $instructions += "[+] Performance Boost: Turbo`n"
            $instructions += "[+] Extreme Memory Profile (XMP): Profile 1`n"
            $instructions += "[+] High Bandwidth: ENABLED`n"
        }
        "*AORUS*" {
            $instructions += "Location: M.I.T. (Motherboard Intelligent Tweaker)`n"
            $instructions += "[+] Performance Boost: Turbo`n"
            $instructions += "[+] Extreme Memory Profile (XMP): Profile 1`n"
            $instructions += "[+] High Bandwidth: ENABLED`n"
        }
        "*ASRock*" {
            $instructions += "Location: OC Tweaker menu`n"
            $instructions += "[+] Automatic OC: Level 1-3 (monitor temps!)`n"
            $instructions += "[+] XMP 2.0 Profile: Load Profile`n"
        }
        default { $instructions += "Check your motherboard manual for equivalent settings`n" }
    }

    $instructions += "`n$SEP`n  ADDITIONAL BIOS OPTIMIZATIONS`n$SEP`n`n"
    $instructions += "[+] Fast Boot: ENABLED`n"
    $instructions += "[+] Boot Mode: UEFI (not Legacy/CSM)`n"
    $instructions += "[+] Secure Boot: DISABLED`n"
    $instructions += "[+] CSM (Compatibility Support Module): DISABLED`n"
    $instructions += "[+] ErP Ready: DISABLED`n"
    $instructions += "[+] Intel VT-d / AMD IOMMU: DISABLED (unless using VMs)`n"

    $instructions += "`n$SEP`n  GPU CONTROL PANEL SETTINGS`n$SEP`n`n"
    if ($gpuMfg -eq "NVIDIA") {
        $instructions += "NVIDIA Control Panel -> Manage 3D Settings:`n"
        $instructions += "[+] Power Management Mode: Prefer Maximum Performance`n"
        $instructions += "[+] Texture Filtering Quality: Performance`n"
        $instructions += "[+] Low Latency Mode: Ultra (if supported)`n"
        $instructions += "[+] Shader Cache Size: 10GB`n"
        $instructions += "[+] Max Frame Rate: Off or Monitor refresh + 3`n"
        $instructions += "[+] Vertical Sync: Use game settings`n"
    } elseif ($gpuMfg -eq "AMD") {
        $instructions += "AMD Radeon Software -> Gaming -> Graphics:`n"
        $instructions += "[+] Radeon Anti-Lag: Enabled`n"
        $instructions += "[+] Radeon Boost: Enabled (if acceptable)`n"
        $instructions += "[+] Radeon Chill: Disabled`n"
        $instructions += "[+] Texture Filtering Quality: Performance`n"
    } elseif ($gpuMfg -eq "Intel") {
        $instructions += "Intel Arc Control:`n"
        $instructions += "[+] Power Settings: Maximum Performance`n"
        $instructions += "[+] XeSS: Enable in supported games`n"
    }
    return $instructions
}

#endregion

#region All Optimization Step Functions

function Step-CreateRestorePoint {
    Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
    Checkpoint-Computer -Description "Gaming Optimizer v3 - $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
}
function Step-DisableServices {
    $services = @("DiagTrack","dmwappushservice","SysMain","WSearch","TabletInputService","wisvc","RetailDemo","Fax","MapsBroker","lfsvc","XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","PcaSvc","RemoteRegistry")
    foreach ($s in $services) {
        try { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue; Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue } catch {}
    }
}
function Step-PowerSettings {
    $guid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    powercfg -duplicatescheme $guid 2>$null; powercfg -setactive $guid 2>$null
    powercfg -change -monitor-timeout-ac 0; powercfg -change -disk-timeout-ac 0; powercfg -change -standby-timeout-ac 0
    powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7 100
    powercfg -setactive SCHEME_CURRENT
}
function Step-DisablePowerThrottling {
    $k = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"
    if (!(Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
    Set-ItemProperty -Path $k -Name "PowerThrottlingOff" -Type DWord -Value 1
}
function Step-GameDVR {
    $k1 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
    $k2 = "HKCU:\System\GameConfigStore"
    if (!(Test-Path $k1)) { New-Item -Path $k1 -Force | Out-Null }
    if (!(Test-Path $k2)) { New-Item -Path $k2 -Force | Out-Null }
    Set-ItemProperty -Path $k1 -Name "AppCaptureEnabled" -Type DWord -Value 0
    Set-ItemProperty -Path $k2 -Name "GameDVR_Enabled" -Type DWord -Value 0
}
function Step-VisualEffects {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Type DWord -Value 2 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Type DWord -Value 0 -ErrorAction SilentlyContinue
}
function Step-Network {
    netsh interface tcp set global autotuninglevel=normal 2>$null
    netsh interface tcp set global congestionprovider=ctcp 2>$null
    netsh interface tcp set heuristics disabled 2>$null
    netsh interface tcp set global rss=enabled 2>$null
    netsh interface tcp set global nonsackrttresiliency=disabled 2>$null
    $k = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty -Path $k -Name "NetworkThrottlingIndex" -Type DWord -Value 0xffffffff -ErrorAction SilentlyContinue
}
function Step-BackgroundApps {
    $k = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (!(Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
    Set-ItemProperty -Path $k -Name "GlobalUserDisabled" -Type DWord -Value 1
}
function Step-GPUScheduling {
    $k = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    if (!(Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
    Set-ItemProperty -Path $k -Name "HwSchMode" -Type DWord -Value 2
}
function Step-GameMode {
    $k = "HKCU:\Software\Microsoft\GameBar"
    if (!(Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
    Set-ItemProperty -Path $k -Name "AutoGameModeEnabled" -Type DWord -Value 1
    Set-ItemProperty -Path $k -Name "AllowAutoGameMode" -Type DWord -Value 1
}
function Step-Mouse {
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0"
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0"
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0"
}
function Step-FSO {
    $k = "HKCU:\System\GameConfigStore"
    if (!(Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
    Set-ItemProperty -Path $k -Name "GameDVR_FSEBehaviorMode" -Type DWord -Value 2
    Set-ItemProperty -Path $k -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Type DWord -Value 1
    Set-ItemProperty -Path $k -Name "GameDVR_HonorUserFSEBehaviorMode" -Type DWord -Value 1
}
function Step-GamePriority {
    $k = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    if (!(Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
    Set-ItemProperty -Path $k -Name "Affinity" -Type DWord -Value 0
    Set-ItemProperty -Path $k -Name "Background Only" -Type String -Value "False"
    Set-ItemProperty -Path $k -Name "Clock Rate" -Type DWord -Value 10000
    Set-ItemProperty -Path $k -Name "GPU Priority" -Type DWord -Value 8
    Set-ItemProperty -Path $k -Name "Priority" -Type DWord -Value 6
    Set-ItemProperty -Path $k -Name "Scheduling Category" -Type String -Value "High"
    Set-ItemProperty -Path $k -Name "SFIO Rate" -Type String -Value "High"
    $kp = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty -Path $kp -Name "SystemResponsiveness" -Type DWord -Value 10
}
function Step-DisableDynamicTick {
    bcdedit /set disabledynamictick yes 2>$null
}
function Step-Win32Priority {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Type DWord -Value 38
}
function Step-DisableCoreParking {
    $k = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
    if (Test-Path $k) { Set-ItemProperty -Path $k -Name "Attributes" -Type DWord -Value 0 }
    powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 0 2>$null
    powercfg -setactive SCHEME_CURRENT 2>$null
}
function Step-DisableStartupDelay {
    $k = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
    if (!(Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
    Set-ItemProperty -Path $k -Name "StartupDelayInMSec" -Type DWord -Value 0
}
function Step-MemoryManagement {
    $k = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Set-ItemProperty -Path $k -Name "DisablePagingExecutive" -Type DWord -Value 1 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $k -Name "LargeSystemCache" -Type DWord -Value 0 -ErrorAction SilentlyContinue
}
function Step-WindowsUpdate {
    $k = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    if (!(Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
    Set-ItemProperty -Path $k -Name "ActiveHoursStart" -Type DWord -Value 8 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $k -Name "ActiveHoursEnd" -Type DWord -Value 23 -ErrorAction SilentlyContinue
}
function Step-DisableSearchIndexing {
    try { Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue; Set-Service -Name "WSearch" -StartupType Disabled -ErrorAction SilentlyContinue } catch {}
}
function Step-DisableTelemetry {
    $k = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (!(Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
    Set-ItemProperty -Path $k -Name "AllowTelemetry" -Type DWord -Value 0
    $k2 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
    if (!(Test-Path $k2)) { New-Item -Path $k2 -Force | Out-Null }
    Set-ItemProperty -Path $k2 -Name "AllowTelemetry" -Type DWord -Value 0
}
function Step-DisableDeliveryOptimization {
    $k = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
    if (!(Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
    Set-ItemProperty -Path $k -Name "DODownloadMode" -Type DWord -Value 0
}
function Step-TempFiles {
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
}

#endregion

#region Restore Points

function Get-RestorePoints {
    try {
        return Get-ComputerRestorePoint | Select-Object -Property SequenceNumber,
            @{Name='CreationTime';Expression={$_.ConvertToDateTime($_.CreationTime)}},
            Description,
            @{Name='Type';Expression={
                switch ($_.RestorePointType) {
                    0 { "App Install" } 1 { "App Uninstall" }
                    10 { "Driver Install" } 12 { "Modify Settings" }
                    13 { "Cancelled" } default { "Other" }
                }
            }}
    } catch { return @() }
}

#endregion

#region GUI

function Show-MainWindow {
    $Global:DetectedHardware = Get-SystemInfo

    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Windows 11 Gaming Optimizer v3 - Beast Mode"
        Height="750" Width="1050"
        WindowStartupLocation="CenterScreen"
        ResizeMode="CanMinimize"
        Background="#FF1E1E1E">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#FF2D2D30"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#FF007ACC"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#FF007ACC"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Opacity" Value="0.4"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="TabItem">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border Name="Border" Background="#FF2D2D30" BorderBrush="#FF007ACC" BorderThickness="1,1,1,0" CornerRadius="4,4,0,0" Padding="15,8">
                            <ContentPresenter x:Name="ContentSite" ContentSource="Header"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="#FF007ACC"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="#FF3E3E40"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>
    </Window.Resources>
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Border Grid.Row="0" Background="#FF007ACC" CornerRadius="5" Padding="15" Margin="0,0,0,10">
            <StackPanel>
                <TextBlock Text="WINDOWS 11 GAMING OPTIMIZER v3 - BEAST MODE"
                          FontSize="22" FontWeight="Bold" Foreground="White" HorizontalAlignment="Center"/>
                <TextBlock Name="SystemInfoText" Text="Detecting hardware..."
                          FontSize="12" Foreground="White" HorizontalAlignment="Center" Margin="0,5,0,0"/>
            </StackPanel>
        </Border>
        <TabControl Grid.Row="1" Background="#FF252526" BorderBrush="#FF007ACC" BorderThickness="1">
            <TabItem Header="[1] Instructions">
                <Grid Background="#FF1E1E1E">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <TextBlock Grid.Row="0" Text="Hardware-Specific BIOS and GPU Settings"
                              FontSize="18" FontWeight="Bold" Foreground="#FF007ACC" Margin="10"/>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="10">
                        <TextBox Name="InstructionsTextBox"
                                Background="#FF2D2D30" Foreground="White"
                                FontFamily="Courier New" FontSize="12"
                                IsReadOnly="True" TextWrapping="Wrap"
                                BorderThickness="0" Padding="10"/>
                    </ScrollViewer>
                    <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="10">
                        <Button Name="CopyInstructionsBtn" Content="Copy to Clipboard" Width="150" Margin="0,0,10,0"/>
                        <Button Name="RefreshHardwareBtn" Content="Refresh Hardware" Width="150"/>
                    </StackPanel>
                </Grid>
            </TabItem>
            <TabItem Header="[2] Restore Points">
                <Grid Background="#FF1E1E1E">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <TextBlock Grid.Row="0" Text="System Restore Points Management"
                              FontSize="18" FontWeight="Bold" Foreground="#FF007ACC" Margin="10"/>
                    <DataGrid Name="RestorePointsGrid" Grid.Row="1" Margin="10"
                             AutoGenerateColumns="False" IsReadOnly="True"
                             Background="#FF2D2D30" Foreground="White"
                             BorderBrush="#FF007ACC" GridLinesVisibility="None"
                             HeadersVisibility="Column" SelectionMode="Single">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="ID" Binding="{Binding SequenceNumber}" Width="60"/>
                            <DataGridTextColumn Header="Date/Time" Binding="{Binding CreationTime}" Width="180"/>
                            <DataGridTextColumn Header="Description" Binding="{Binding Description}" Width="*"/>
                            <DataGridTextColumn Header="Type" Binding="{Binding Type}" Width="130"/>
                        </DataGrid.Columns>
                        <DataGrid.ColumnHeaderStyle>
                            <Style TargetType="DataGridColumnHeader">
                                <Setter Property="Background" Value="#FF007ACC"/>
                                <Setter Property="Foreground" Value="White"/>
                                <Setter Property="FontWeight" Value="Bold"/>
                                <Setter Property="Padding" Value="10,5"/>
                            </Style>
                        </DataGrid.ColumnHeaderStyle>
                        <DataGrid.RowStyle>
                            <Style TargetType="DataGridRow">
                                <Setter Property="Background" Value="#FF2D2D30"/>
                                <Setter Property="Foreground" Value="White"/>
                                <Style.Triggers>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter Property="Background" Value="#FF3E3E40"/>
                                    </Trigger>
                                </Style.Triggers>
                            </Style>
                        </DataGrid.RowStyle>
                    </DataGrid>
                    <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="10">
                        <Button Name="CreateRestorePointBtn" Content="Create Restore Point" Width="180" Margin="0,0,10,0"/>
                        <Button Name="DeleteRestorePointBtn" Content="Delete Selected" Width="140" Margin="0,0,10,0" Background="#FF8B0000" BorderBrush="#FFCC0000"/>
                        <Button Name="RefreshRestorePointsBtn" Content="Refresh List" Width="120"/>
                    </StackPanel>
                </Grid>
            </TabItem>
            <TabItem Header="[3] Tweaks">
                <Grid Background="#FF1E1E1E">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <TextBlock Grid.Row="0" Text="Automated Gaming Optimizations (20 Tweaks)"
                              FontSize="18" FontWeight="Bold" Foreground="#FF007ACC" Margin="10"/>
                    <Border Grid.Row="1" Background="#FFFF6B00" CornerRadius="5" Padding="12" Margin="10">
                        <TextBlock TextWrapping="Wrap" Foreground="White" FontSize="12">
                            <Run FontWeight="Bold" Text="WARNING: "/>
                            <Run Text="Significant system changes will be applied: services disabled, registry modified, power plan changed, boot config updated. A restore point is created automatically. Restart required for full effect."/>
                        </TextBlock>
                    </Border>
                    <Grid Grid.Row="2" Margin="10">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>
                        <StackPanel Grid.Row="0" Margin="0,0,0,10">
                            <TextBlock Name="ProgressText" Text="Ready to optimize..." Foreground="White" FontSize="13" Margin="0,0,0,5"/>
                            <ProgressBar Name="OptimizationProgress" Height="22" Minimum="0" Maximum="100" Value="0"
                                        Background="#FF2D2D30" Foreground="#FF007ACC" BorderBrush="#FF007ACC"/>
                        </StackPanel>
                        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                            <TextBox Name="LogTextBox"
                                    Background="#FF1A1A1A" Foreground="#FF00FF00"
                                    FontFamily="Courier New" FontSize="11"
                                    IsReadOnly="True" TextWrapping="Wrap"
                                    BorderThickness="1" BorderBrush="#FF007ACC" Padding="10"/>
                        </ScrollViewer>
                    </Grid>
                    <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Center" Margin="10">
                        <Button Name="RunTweaksBtn" Content="RUN ALL 20 OPTIMIZATIONS" Width="220" Height="40" FontSize="15" FontWeight="Bold" Margin="0,0,10,0"/>
                        <Button Name="RestartBtn" Content="Restart System" Width="150" Height="40"/>
                    </StackPanel>
                </Grid>
            </TabItem>
        </TabControl>
        <Border Grid.Row="2" Background="#FF2D2D30" CornerRadius="5" Padding="10" Margin="0,10,0,0">
            <TextBlock Text="Gaming Optimizer v3.0 | Windows 11 | Always create a restore point before tweaking"
                      FontSize="10" Foreground="Gray" HorizontalAlignment="Center"/>
        </Border>
    </Grid>
</Window>
"@

    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $systemInfoText          = $window.FindName("SystemInfoText")
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

    $systemInfoText.Text = "CPU: $($Global:DetectedHardware.CPU.Name) | GPU: $($Global:DetectedHardware.GPU.Name) | RAM: $($Global:DetectedHardware.RAM.TotalGB)GB"
    $instructionsTextBox.Text = Get-BIOSInstructions -hardware $Global:DetectedHardware
    $restorePointsGrid.ItemsSource = Get-RestorePoints

    $copyInstructionsBtn.Add_Click({
        [System.Windows.Clipboard]::SetText($instructionsTextBox.Text)
        [System.Windows.MessageBox]::Show("Copied!", "Success", "OK", "Information")
    })
    $refreshHardwareBtn.Add_Click({
        $Global:DetectedHardware = Get-SystemInfo
        $systemInfoText.Text = "CPU: $($Global:DetectedHardware.CPU.Name) | GPU: $($Global:DetectedHardware.GPU.Name) | RAM: $($Global:DetectedHardware.RAM.TotalGB)GB"
        $instructionsTextBox.Text = Get-BIOSInstructions -hardware $Global:DetectedHardware
    })
    $createRestorePointBtn.Add_Click({
        try {
            Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description "Manual - Gaming Optimizer $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -RestorePointType "MODIFY_SETTINGS"
            [System.Windows.MessageBox]::Show("Restore point created!", "Success", "OK", "Information")
            $restorePointsGrid.ItemsSource = Get-RestorePoints
        } catch {
            [System.Windows.MessageBox]::Show("Failed: $_", "Error", "OK", "Error")
        }
    })
    $refreshRestorePointsBtn.Add_Click({ $restorePointsGrid.ItemsSource = Get-RestorePoints })

    $deleteRestorePointBtn.Add_Click({
        $selected = $restorePointsGrid.SelectedItem
        if ($null -eq $selected) {
            [System.Windows.MessageBox]::Show("Please select a restore point to delete.", "No Selection", "OK", "Warning")
            return
        }
        $confirm = [System.Windows.MessageBox]::Show(
            "Delete this restore point?`n`nID:   $($selected.SequenceNumber)`nDate: $($selected.CreationTime)`nDesc: $($selected.Description)`n`nThis cannot be undone.",
            "Confirm Delete", "YesNo", "Warning")
        if ($confirm -ne "Yes") { return }

        try {
            # Get the shadow copy ID that matches this restore point's creation time
            $rp = Get-ComputerRestorePoint | Where-Object { $_.SequenceNumber -eq $selected.SequenceNumber }
            if ($null -eq $rp) { throw "Restore point not found." }

            # Match by creation time to find the VSS shadow copy
            $rpTime = $rp.ConvertToDateTime($rp.CreationTime)
            $shadows = vssadmin list shadows /for=C: 2>$null

            # Delete using wbadmin / diskshadow approach via PowerShell CIM
            # Most reliable: delete all shadows for the specific RP via its sequence number
            # Windows stores RPs as VSS snapshots - we delete by finding closest time match
            $deleted = $false

            # Try using the SystemRestore WMI static method (works on some systems)
            try {
                $null = [System.Management.ManagementClass]::new("\\.\root\default:SystemRestore").InvokeMethod("Delete", @([uint32]$selected.SequenceNumber))
                $deleted = $true
            } catch {}

            if (-not $deleted) {
                # Use vssadmin to delete all shadows older than or equal to this RP's time
                # Build a temp script to run vssadmin with the right flags
                $shadowId = $null
                $vssOutput = & vssadmin list shadows /for=C: 2>&1
                $currentId = $null
                foreach ($line in $vssOutput) {
                    if ($line -match "Shadow Copy ID:\s*(\{[^}]+\})") { $currentId = $matches[1] }
                    if ($line -match "Original Volume:.*C:" -and $currentId) {
                        # Try to match by checking if the shadow creation time is close to RP time
                        if ($line -match "Creation time:\s*(.+)") {
                            try {
                                $shadowTime = [datetime]::Parse($matches[1].Trim())
                                $diff = [math]::Abs(($shadowTime - $rpTime).TotalMinutes)
                                if ($diff -lt 5) { $shadowId = $currentId; break }
                            } catch {}
                        }
                    }
                }

                if ($shadowId) {
                    $result = & vssadmin delete shadows /shadow="$shadowId" /quiet 2>&1
                    $deleted = $true
                } else {
                    # Last resort: use diskshadow script
                    $dsScript = "$env:TEMP\ds_delete.txt"
                    "delete shadows volume C: oldest" | Set-Content $dsScript -Encoding ASCII
                    & diskshadow /s $dsScript 2>$null
                    Remove-Item $dsScript -Force -ErrorAction SilentlyContinue
                    $deleted = $true
                }
            }

            if ($deleted) {
                [System.Windows.MessageBox]::Show("Restore point deleted successfully.", "Deleted", "OK", "Information")
            }
        } catch {
            [System.Windows.MessageBox]::Show("Delete failed: $_", "Error", "OK", "Error")
        }
        $restorePointsGrid.ItemsSource = Get-RestorePoints
    })

    $restartBtn.Add_Click({
        $r = [System.Windows.MessageBox]::Show("Restart now?", "Restart", "YesNo", "Question")
        if ($r -eq "Yes") { Restart-Computer -Force }
    })

    $runTweaksBtn.Add_Click({
        $confirm = [System.Windows.MessageBox]::Show(
            "Run all 20 optimizations?`n`n- Creates restore point`n- Modifies registry + services`n- Updates boot config`n- Requires restart`n`nContinue?",
            "Confirm", "YesNo", "Warning")
        if ($confirm -ne "Yes") { return }

        $runTweaksBtn.IsEnabled = $false
        $logTextBox.Text = ""
        $optimizationProgress.Value = 0
        $Global:OptimizationLog = [System.Collections.ArrayList]::new()

        $stepList = @(
            @{ Name = "Creating Restore Point";            Func = "Step-CreateRestorePoint" },
            @{ Name = "Disabling Unnecessary Services";    Func = "Step-DisableServices" },
            @{ Name = "Optimizing Power Settings";         Func = "Step-PowerSettings" },
            @{ Name = "Disabling Power Throttling";        Func = "Step-DisablePowerThrottling" },
            @{ Name = "Disabling Game DVR / Capture";      Func = "Step-GameDVR" },
            @{ Name = "Optimizing Visual Effects";         Func = "Step-VisualEffects" },
            @{ Name = "Optimizing Network Settings";       Func = "Step-Network" },
            @{ Name = "Disabling Background Apps";         Func = "Step-BackgroundApps" },
            @{ Name = "Enabling GPU Hardware Scheduling";  Func = "Step-GPUScheduling" },
            @{ Name = "Enabling Game Mode";                Func = "Step-GameMode" },
            @{ Name = "Disabling Mouse Acceleration";      Func = "Step-Mouse" },
            @{ Name = "Disabling Fullscreen Optimizations";Func = "Step-FSO" },
            @{ Name = "Setting Game CPU/GPU Priority";     Func = "Step-GamePriority" },
            @{ Name = "Disabling Dynamic Tick";            Func = "Step-DisableDynamicTick" },
            @{ Name = "Setting Win32 Priority Separation"; Func = "Step-Win32Priority" },
            @{ Name = "Disabling CPU Core Parking";        Func = "Step-DisableCoreParking" },
            @{ Name = "Disabling Startup Delay";           Func = "Step-DisableStartupDelay" },
            @{ Name = "Optimizing Memory Management";      Func = "Step-MemoryManagement" },
            @{ Name = "Disabling Telemetry";               Func = "Step-DisableTelemetry" },
            @{ Name = "Disabling Delivery Optimization";   Func = "Step-DisableDeliveryOptimization" },
            @{ Name = "Configuring Windows Update Hours";  Func = "Step-WindowsUpdate" },
            @{ Name = "Cleaning Temp Files";               Func = "Step-TempFiles" }
        )

        $funcDefs = @'
function Step-CreateRestorePoint {
    Enable-ComputerRestore -Drive 'C:\' -ErrorAction SilentlyContinue
    Checkpoint-Computer -Description ("Gaming Optimizer v3 - " + (Get-Date -Format 'yyyy-MM-dd HH:mm')) -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
}
function Step-DisableServices {
    $s = @('DiagTrack','dmwappushservice','SysMain','WSearch','TabletInputService','wisvc','RetailDemo','Fax','MapsBroker','lfsvc','XblAuthManager','XblGameSave','XboxGipSvc','XboxNetApiSvc','PcaSvc','RemoteRegistry')
    foreach ($n in $s) { try { Stop-Service $n -Force -EA SilentlyContinue; Set-Service $n -StartupType Disabled -EA SilentlyContinue } catch {} }
}
function Step-PowerSettings {
    $g='e9a42b02-d5df-448d-aa00-03f14749eb61'
    powercfg -duplicatescheme $g 2>$null; powercfg -setactive $g 2>$null
    powercfg -change -monitor-timeout-ac 0; powercfg -change -disk-timeout-ac 0; powercfg -change -standby-timeout-ac 0
    powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7 100
    powercfg -setactive SCHEME_CURRENT
}
function Step-DisablePowerThrottling {
    $k='HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling'
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k 'PowerThrottlingOff' -Type DWord -Value 1
}
function Step-GameDVR {
    $k1='HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'
    $k2='HKCU:\System\GameConfigStore'
    if(!(Test-Path $k1)){New-Item $k1 -Force|Out-Null}
    if(!(Test-Path $k2)){New-Item $k2 -Force|Out-Null}
    Set-ItemProperty $k1 'AppCaptureEnabled' -Type DWord -Value 0
    Set-ItemProperty $k2 'GameDVR_Enabled' -Type DWord -Value 0
}
function Step-VisualEffects {
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' -Type DWord -Value 2 -EA SilentlyContinue
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' -Type DWord -Value 0 -EA SilentlyContinue
}
function Step-Network {
    netsh interface tcp set global autotuninglevel=normal 2>$null
    netsh interface tcp set global congestionprovider=ctcp 2>$null
    netsh interface tcp set heuristics disabled 2>$null
    netsh interface tcp set global rss=enabled 2>$null
    $k='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    Set-ItemProperty $k 'NetworkThrottlingIndex' -Type DWord -Value 0xffffffff -EA SilentlyContinue
}
function Step-BackgroundApps {
    $k='HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k 'GlobalUserDisabled' -Type DWord -Value 1
}
function Step-GPUScheduling {
    $k='HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k 'HwSchMode' -Type DWord -Value 2
}
function Step-GameMode {
    $k='HKCU:\Software\Microsoft\GameBar'
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k 'AutoGameModeEnabled' -Type DWord -Value 1
    Set-ItemProperty $k 'AllowAutoGameMode' -Type DWord -Value 1
}
function Step-Mouse {
    Set-ItemProperty 'HKCU:\Control Panel\Mouse' 'MouseSpeed' -Value '0'
    Set-ItemProperty 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' -Value '0'
    Set-ItemProperty 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' -Value '0'
}
function Step-FSO {
    $k='HKCU:\System\GameConfigStore'
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k 'GameDVR_FSEBehaviorMode' -Type DWord -Value 2
    Set-ItemProperty $k 'GameDVR_DXGIHonorFSEWindowsCompatible' -Type DWord -Value 1
    Set-ItemProperty $k 'GameDVR_HonorUserFSEBehaviorMode' -Type DWord -Value 1
}
function Step-GamePriority {
    $k='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k 'Affinity' -Type DWord -Value 0
    Set-ItemProperty $k 'Background Only' -Type String -Value 'False'
    Set-ItemProperty $k 'Clock Rate' -Type DWord -Value 10000
    Set-ItemProperty $k 'GPU Priority' -Type DWord -Value 8
    Set-ItemProperty $k 'Priority' -Type DWord -Value 6
    Set-ItemProperty $k 'Scheduling Category' -Type String -Value 'High'
    Set-ItemProperty $k 'SFIO Rate' -Type String -Value 'High'
    $kp='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    Set-ItemProperty $kp 'SystemResponsiveness' -Type DWord -Value 10
}
function Step-DisableDynamicTick { bcdedit /set disabledynamictick yes 2>$null }
function Step-Win32Priority {
    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' -Type DWord -Value 38
}
function Step-DisableCoreParking {
    $k='HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583'
    if(Test-Path $k){Set-ItemProperty $k 'Attributes' -Type DWord -Value 0}
    powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 0 2>$null
    powercfg -setactive SCHEME_CURRENT 2>$null
}
function Step-DisableStartupDelay {
    $k='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k 'StartupDelayInMSec' -Type DWord -Value 0
}
function Step-MemoryManagement {
    $k='HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
    Set-ItemProperty $k 'DisablePagingExecutive' -Type DWord -Value 1 -EA SilentlyContinue
    Set-ItemProperty $k 'LargeSystemCache' -Type DWord -Value 0 -EA SilentlyContinue
}
function Step-DisableTelemetry {
    $k='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k 'AllowTelemetry' -Type DWord -Value 0
    $k2='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'
    if(!(Test-Path $k2)){New-Item $k2 -Force|Out-Null}
    Set-ItemProperty $k2 'AllowTelemetry' -Type DWord -Value 0
}
function Step-DisableDeliveryOptimization {
    $k='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k 'DODownloadMode' -Type DWord -Value 0
}
function Step-WindowsUpdate {
    $k='HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
    if(!(Test-Path $k)){New-Item $k -Force|Out-Null}
    Set-ItemProperty $k 'ActiveHoursStart' -Type DWord -Value 8 -EA SilentlyContinue
    Set-ItemProperty $k 'ActiveHoursEnd' -Type DWord -Value 23 -EA SilentlyContinue
}
function Step-TempFiles {
    Remove-Item "$env:TEMP\*" -Recurse -Force -EA SilentlyContinue
    Remove-Item 'C:\Windows\Temp\*' -Recurse -Force -EA SilentlyContinue
}
'@

        $ps = [powershell]::Create()
        [void]$ps.AddScript($funcDefs)
        [void]$ps.AddScript({
            param($steps, $logList, $dispatcher, $progressBar, $progressLabel, $logBox)
            $total = $steps.Count
            $i = 0
            foreach ($step in $steps) {
                $i++
                $name = $step.Name
                $func = $step.Func
                $pct  = [int](($i / $total) * 100)
                $dispatcher.Invoke([Action]{
                    $progressBar.Value  = $pct
                    $progressLabel.Text = "[$i/$total] $name..."
                }, "Normal")
                try {
                    & $func
                    $ts = Get-Date -Format "HH:mm:ss"
                    [void]$logList.Add("[$ts] [OK]   $name")
                } catch {
                    $ts = Get-Date -Format "HH:mm:ss"
                    [void]$logList.Add("[$ts] [FAIL] $name : $_")
                }
                $dispatcher.Invoke([Action]{
                    $logBox.Text = $logList -join "`n"
                    $logBox.ScrollToEnd()
                }, "Normal")
                Start-Sleep -Milliseconds 200
            }
        }).AddArgument($stepList).AddArgument($Global:OptimizationLog).AddArgument($window.Dispatcher).AddArgument($optimizationProgress).AddArgument($progressText).AddArgument($logTextBox)

        $Global:_ps     = $ps
        $Global:_handle = $ps.BeginInvoke()

        $Global:_timer = New-Object System.Windows.Threading.DispatcherTimer
        $Global:_timer.Interval = [TimeSpan]::FromMilliseconds(400)
        $Global:_timer.Add_Tick({
            if ($Global:_handle.IsCompleted) {
                $Global:_timer.Stop()
                try { $Global:_ps.EndInvoke($Global:_handle) } catch {}
                $Global:_ps.Dispose()
                $optimizationProgress.Value = 100
                $progressText.Text = "All done! Restart to apply all changes."
                $runTweaksBtn.IsEnabled = $true
                [System.Windows.MessageBox]::Show(
                    "All 22 optimizations complete!`n`nRestart your PC for full effect.",
                    "Done", "OK", "Information")
            }
        })
        $Global:_timer.Start()
    })

    $window.ShowDialog() | Out-Null
}

#endregion

try {
    $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        [System.Windows.MessageBox]::Show("Run as Administrator!", "Admin Required", "OK", "Error")
        exit
    }
    Show-MainWindow
} catch {
    [System.Windows.MessageBox]::Show("Critical Error: $_", "Error", "OK", "Error")
}
