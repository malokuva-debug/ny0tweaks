#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Windows 11 Gaming Optimizer - GUI Edition
.DESCRIPTION
    Web-executable GUI tool for Windows 11 gaming optimization
    Usage: iwr -useb YOUR_URL | iex
.NOTES
    Version: 2.0 GUI Edition
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Global variables
$Global:DetectedHardware = @{}
$Global:OptimizationLog = @()

#region Hardware Detection Functions

function Get-SystemInfo {
    $hwInfo = @{
        CPU = @{}
        GPU = @{}
        RAM = @{}
        Motherboard = @{}
        Storage = @{}
        OS = @{}
    }
    
    try {
        # CPU Information
        $cpu = Get-CimInstance -ClassName Win32_Processor
        $hwInfo.CPU = @{
            Name = $cpu.Name
            Manufacturer = if ($cpu.Name -like "*Intel*") { "Intel" } elseif ($cpu.Name -like "*AMD*") { "AMD" } else { "Unknown" }
            Cores = $cpu.NumberOfCores
            LogicalProcessors = $cpu.NumberOfLogicalProcessors
            MaxClockSpeed = $cpu.MaxClockSpeed
            CurrentClockSpeed = $cpu.CurrentClockSpeed
            Generation = Get-CPUGeneration -cpuName $cpu.Name
        }
        
        # GPU Information
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
        
        # RAM Information
        $ram = Get-CimInstance -ClassName Win32_PhysicalMemory
        $totalRAM = ($ram | Measure-Object -Property Capacity -Sum).Sum
        $hwInfo.RAM = @{
            TotalGB = [math]::Round($totalRAM / 1GB, 2)
            Modules = $ram.Count
            Speed = ($ram | Select-Object -First 1).Speed
            Manufacturer = ($ram | Select-Object -First 1).Manufacturer
            PartNumber = ($ram | Select-Object -First 1).PartNumber
        }
        
        # Motherboard Information
        $mobo = Get-CimInstance -ClassName Win32_BaseBoard
        $hwInfo.Motherboard = @{
            Manufacturer = $mobo.Manufacturer
            Product = $mobo.Product
            Version = $mobo.Version
        }
        
        # Storage Information
        $storage = Get-PhysicalDisk
        $hwInfo.Storage = @{
            Drives = @()
        }
        foreach ($drive in $storage) {
            $hwInfo.Storage.Drives += @{
                Model = $drive.FriendlyName
                MediaType = $drive.MediaType
                Size = [math]::Round($drive.Size / 1GB, 2)
                BusType = $drive.BusType
            }
        }
        
        # OS Information
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $hwInfo.OS = @{
            Name = $os.Caption
            Version = $os.Version
            BuildNumber = $os.BuildNumber
            Architecture = $os.OSArchitecture
        }
        
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
    }
    elseif ($cpuName -like "*AMD*") {
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
    
    $instructions = ""
    $cpuMfg = $hardware.CPU.Manufacturer
    $gpuMfg = $hardware.GPU.Manufacturer
    $moboMfg = $hardware.Motherboard.Manufacturer
    
    # CPU-specific instructions
    $instructions += "═══════════════════════════════════════════════════════`n"
    $instructions += "  CPU OPTIMIZATION - $($hardware.CPU.Name)`n"
    $instructions += "═══════════════════════════════════════════════════════`n`n"
    
    if ($cpuMfg -eq "Intel") {
        $instructions += "✓ Intel Turbo Boost Technology: ENABLED`n"
        $instructions += "✓ Intel Turbo Boost Max 3.0: ENABLED (if available)`n"
        $instructions += "✓ Enhanced Intel SpeedStep: ENABLED`n"
        $instructions += "✓ Hyper-Threading: ENABLED`n"
        $instructions += "✓ CPU C-States: DISABLED (for lowest latency)`n"
        $instructions += "  - C1E Support: DISABLED`n"
        $instructions += "  - C3/C6/C7 State: DISABLED`n"
        $instructions += "  - Package C State: DISABLED`n"
    }
    elseif ($cpuMfg -eq "AMD") {
        $instructions += "✓ Precision Boost Overdrive (PBO): ENABLED`n"
        $instructions += "✓ Core Performance Boost: ENABLED`n"
        $instructions += "✓ SMT (Simultaneous Multi-Threading): ENABLED`n"
        $instructions += "✓ Global C-State Control: DISABLED (for lowest latency)`n"
        $instructions += "✓ CPPC (Collaborative Processor Performance Control): ENABLED`n"
        $instructions += "✓ CPPC Preferred Cores: ENABLED`n"
    }
    
    # RAM Instructions
    $instructions += "`n═══════════════════════════════════════════════════════`n"
    $instructions += "  MEMORY OPTIMIZATION - $($hardware.RAM.TotalGB)GB @ $($hardware.RAM.Speed)MHz`n"
    $instructions += "═══════════════════════════════════════════════════════`n`n"
    
    if ($cpuMfg -eq "Intel") {
        $instructions += "✓ XMP (Extreme Memory Profile): ENABLED - Profile 1`n"
    }
    elseif ($cpuMfg -eq "AMD") {
        $instructions += "✓ DOCP/EXPO (AMD Memory Profile): ENABLED - Profile 1`n"
    }
    $instructions += "✓ Memory Fast Boot: ENABLED`n"
    $instructions += "✓ Gear Down Mode: DISABLED (if stable)`n"
    $instructions += "✓ Command Rate: 1T (if stable, otherwise 2T)`n"
    
    # GPU Instructions
    $instructions += "`n═══════════════════════════════════════════════════════`n"
    $instructions += "  GPU/PCIe OPTIMIZATION - $($hardware.GPU.Name)`n"
    $instructions += "═══════════════════════════════════════════════════════`n`n"
    
    $instructions += "✓ Above 4G Decoding: ENABLED`n"
    $instructions += "✓ Resizable BAR (Re-Size BAR): ENABLED`n"
    if ($gpuMfg -eq "AMD") {
        $instructions += "  (AMD Smart Access Memory)`n"
    }
    $instructions += "✓ PCIe Slot 1 Speed: Gen 4.0 (or Gen 3.0 if Gen 4 unstable)`n"
    $instructions += "✓ PCIe ASPM: DISABLED`n"
    $instructions += "✓ Primary Display: PCIe / Auto`n"
    
    # Storage Instructions
    $instructions += "`n═══════════════════════════════════════════════════════`n"
    $instructions += "  STORAGE OPTIMIZATION`n"
    $instructions += "═══════════════════════════════════════════════════════`n`n"
    
    $instructions += "✓ SATA Mode: AHCI (not IDE)`n"
    foreach ($drive in $hardware.Storage.Drives) {
        if ($drive.MediaType -eq "SSD" -or $drive.BusType -eq "NVMe") {
            $instructions += "✓ $($drive.Model) - Ensure M.2 slot is Gen 3.0/4.0`n"
        }
    }
    
    # Motherboard-specific
    $instructions += "`n═══════════════════════════════════════════════════════`n"
    $instructions += "  MOTHERBOARD SPECIFIC - $($hardware.Motherboard.Manufacturer)`n"
    $instructions += "═══════════════════════════════════════════════════════`n`n"
    
    switch -Wildcard ($moboMfg) {
        "*ASUS*" {
            $instructions += "Location: AI Tweaker / Extreme Tweaker menu`n"
            $instructions += "✓ Performance Bias: Performance`n"
            $instructions += "✓ MultiCore Enhancement (MCE): ENABLED`n"
            $instructions += "✓ ASUS Performance Enhancement: ENABLED`n"
        }
        "*MSI*" {
            $instructions += "Location: OC / Overclocking menu`n"
            $instructions += "✓ Game Boost: Level 2-4 (monitor temps!)`n"
            $instructions += "✓ A-XMP: ENABLED`n"
            $instructions += "✓ Memory Fast Boot: ENABLED`n"
        }
        "*Gigabyte*" {
            $instructions += "Location: M.I.T. (Motherboard Intelligent Tweaker)`n"
            $instructions += "✓ Performance Boost: Turbo`n"
            $instructions += "✓ Extreme Memory Profile (XMP): Profile 1`n"
            $instructions += "✓ High Bandwidth: ENABLED`n"
        }
        "*AORUS*" {
            $instructions += "Location: M.I.T. (Motherboard Intelligent Tweaker)`n"
            $instructions += "✓ Performance Boost: Turbo`n"
            $instructions += "✓ Extreme Memory Profile (XMP): Profile 1`n"
            $instructions += "✓ High Bandwidth: ENABLED`n"
        }
        "*ASRock*" {
            $instructions += "Location: OC Tweaker menu`n"
            $instructions += "✓ Automatic OC: Level 1-3 (monitor temps!)`n"
            $instructions += "✓ XMP 2.0 Profile: Load Profile`n"
        }
        default {
            $instructions += "Check your motherboard manual for equivalent settings`n"
        }
    }
    
    # Additional optimizations
    $instructions += "`n═══════════════════════════════════════════════════════`n"
    $instructions += "  ADDITIONAL BIOS OPTIMIZATIONS`n"
    $instructions += "═══════════════════════════════════════════════════════`n`n"
    
    $instructions += "✓ Fast Boot: ENABLED`n"
    $instructions += "✓ Boot Mode: UEFI (not Legacy/CSM)`n"
    $instructions += "✓ Secure Boot: DISABLED`n"
    $instructions += "✓ CSM (Compatibility Support Module): DISABLED`n"
    $instructions += "✓ ErP Ready: DISABLED`n"
    $instructions += "✓ Intel VT-d / AMD IOMMU: DISABLED (unless using VMs)`n"
    
    # GPU Control Panel Instructions
    $instructions += "`n═══════════════════════════════════════════════════════`n"
    $instructions += "  GPU CONTROL PANEL SETTINGS`n"
    $instructions += "═══════════════════════════════════════════════════════`n`n"
    
    if ($gpuMfg -eq "NVIDIA") {
        $instructions += "NVIDIA Control Panel → Manage 3D Settings:`n"
        $instructions += "✓ Power Management Mode: Prefer Maximum Performance`n"
        $instructions += "✓ Texture Filtering Quality: Performance`n"
        $instructions += "✓ Low Latency Mode: Ultra (if supported)`n"
        $instructions += "✓ Max Frame Rate: Off or Monitor refresh + 3`n"
        $instructions += "✓ Vertical Sync: Use game settings`n"
    }
    elseif ($gpuMfg -eq "AMD") {
        $instructions += "AMD Radeon Software → Gaming → Graphics:`n"
        $instructions += "✓ Radeon Anti-Lag: Enabled`n"
        $instructions += "✓ Radeon Boost: Enabled (if acceptable)`n"
        $instructions += "✓ Radeon Chill: Disabled or match refresh rate`n"
        $instructions += "✓ Image Sharpening: User preference`n"
        $instructions += "✓ Texture Filtering Quality: Performance`n"
    }
    elseif ($gpuMfg -eq "Intel") {
        $instructions += "Intel Arc Control:`n"
        $instructions += "✓ Power Settings: Maximum Performance`n"
        $instructions += "✓ XeSS: Enable in supported games`n"
    }
    
    return $instructions
}

#endregion

#region Optimization Functions

function Invoke-GamingOptimizations {
    param($progressCallback)
    
    $steps = @(
        @{ Name = "Creating Restore Point"; Action = { Create-SystemRestorePoint } },
        @{ Name = "Disabling Unnecessary Services"; Action = { Disable-UnnecessaryServices } },
        @{ Name = "Optimizing Power Settings"; Action = { Optimize-PowerSettings } },
        @{ Name = "Disabling Game DVR"; Action = { Disable-GameDVR } },
        @{ Name = "Optimizing Visual Effects"; Action = { Optimize-VisualEffects } },
        @{ Name = "Optimizing Network Settings"; Action = { Optimize-NetworkSettings } },
        @{ Name = "Disabling Background Apps"; Action = { Disable-BackgroundApps } },
        @{ Name = "Enabling GPU Scheduling"; Action = { Enable-GPUScheduling } },
        @{ Name = "Enabling Game Mode"; Action = { Enable-GameMode } },
        @{ Name = "Optimizing Mouse Settings"; Action = { Optimize-MouseSettings } },
        @{ Name = "Disabling Fullscreen Optimizations"; Action = { Disable-FullscreenOptimizations } },
        @{ Name = "Configuring Windows Update"; Action = { Configure-WindowsUpdate } },
        @{ Name = "Cleaning Temp Files"; Action = { Clean-TempFiles } }
    )
    
    $currentStep = 0
    $totalSteps = $steps.Count
    
    foreach ($step in $steps) {
        $currentStep++
        $progressCallback.Invoke($currentStep, $totalSteps, $step.Name)
        
        try {
            & $step.Action
            Add-OptimizationLog "✓ $($step.Name)" "Success"
        } catch {
            Add-OptimizationLog "✗ $($step.Name): $_" "Error"
        }
        
        Start-Sleep -Milliseconds 500
    }
}

function Create-SystemRestorePoint {
    try {
        Enable-ComputerRestore -Drive "C:\"
        Checkpoint-Computer -Description "Gaming Optimizer - $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -RestorePointType "MODIFY_SETTINGS"
    } catch {
        throw $_
    }
}

function Disable-UnnecessaryServices {
    $services = @("DiagTrack", "dmwappushservice", "SysMain", "WSearch", "TabletInputService", 
                  "wisvc", "RetailDemo", "Fax", "MapsBroker", "lfsvc")
    
    foreach ($service in $services) {
        try {
            $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($svc) {
                Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
                Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
            }
        } catch { }
    }
}

function Optimize-PowerSettings {
    $ultimateGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    powercfg -duplicatescheme $ultimateGuid 2>$null
    powercfg -setactive $ultimateGuid 2>$null
    powercfg -change -monitor-timeout-ac 0
    powercfg -change -disk-timeout-ac 0
    powercfg -change -standby-timeout-ac 0
    powercfg -setacvalueindex SCHEME_CURRENT 2a737abc-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
    powercfg -setactive SCHEME_CURRENT
}

function Disable-GameDVR {
    $keys = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR", "HKCU:\System\GameConfigStore")
    foreach ($key in $keys) {
        if (!(Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    }
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Type DWord -Value 0
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Type DWord -Value 0
}

function Optimize-VisualEffects {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Type DWord -Value 2 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Type DWord -Value 0
}

function Optimize-NetworkSettings {
    netsh interface tcp set global autotuninglevel=normal 2>$null
    netsh interface tcp set global chimney=enabled 2>$null
    netsh interface tcp set global dca=enabled 2>$null
    netsh interface tcp set global netdma=enabled 2>$null
    netsh interface tcp set global congestionprovider=ctcp 2>$null
    netsh interface tcp set heuristics disabled 2>$null
}

function Disable-BackgroundApps {
    if (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications")) {
        New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Type DWord -Value 1
}

function Enable-GPUScheduling {
    $gpuKey = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    if (!(Test-Path $gpuKey)) { New-Item -Path $gpuKey -Force | Out-Null }
    Set-ItemProperty -Path $gpuKey -Name "HwSchMode" -Type DWord -Value 2
}

function Enable-GameMode {
    $gameModeKey = "HKCU:\Software\Microsoft\GameBar"
    if (!(Test-Path $gameModeKey)) { New-Item -Path $gameModeKey -Force | Out-Null }
    Set-ItemProperty -Path $gameModeKey -Name "AutoGameModeEnabled" -Type DWord -Value 1
}

function Optimize-MouseSettings {
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Type String -Value "0"
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Type String -Value "0"
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Type String -Value "0"
}

function Disable-FullscreenOptimizations {
    $fsoKey = "HKCU:\System\GameConfigStore"
    if (!(Test-Path $fsoKey)) { New-Item -Path $fsoKey -Force | Out-Null }
    Set-ItemProperty -Path $fsoKey -Name "GameDVR_FSEBehaviorMode" -Type DWord -Value 2
    Set-ItemProperty -Path $fsoKey -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Type DWord -Value 1
}

function Configure-WindowsUpdate {
    $wuKey = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    if (!(Test-Path $wuKey)) { New-Item -Path $wuKey -Force | Out-Null }
    Set-ItemProperty -Path $wuKey -Name "ActiveHoursStart" -Type DWord -Value 8 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $wuKey -Name "ActiveHoursEnd" -Type DWord -Value 23 -ErrorAction SilentlyContinue
}

function Clean-TempFiles {
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
}

function Add-OptimizationLog {
    param($message, $type)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $Global:OptimizationLog += "[$timestamp] $message"
}

#endregion

#region Restore Point Functions

function Get-RestorePoints {
    try {
        $points = Get-ComputerRestorePoint | Select-Object -Property SequenceNumber, 
            @{Name='CreationTime';Expression={$_.ConvertToDateTime($_.CreationTime)}}, 
            Description, 
            @{Name='Type';Expression={
                switch ($_.RestorePointType) {
                    0 { "Application Install" }
                    1 { "Application Uninstall" }
                    10 { "Device Driver Install" }
                    12 { "Modify Settings" }
                    13 { "Cancelled Operation" }
                    default { "Other" }
                }
            }}
        return $points
    } catch {
        return @()
    }
}

#endregion

#region GUI Functions

function Show-MainWindow {
    # Detect hardware first
    $Global:DetectedHardware = Get-SystemInfo
    
    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Windows 11 Gaming Optimizer - Beast Mode" 
        Height="700" Width="1000" 
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
        
        <!-- Header -->
        <Border Grid.Row="0" Background="#FF007ACC" CornerRadius="5" Padding="15" Margin="0,0,0,10">
            <StackPanel>
                <TextBlock Text="🎮 WINDOWS 11 GAMING OPTIMIZER - BEAST MODE" 
                          FontSize="24" FontWeight="Bold" Foreground="White" HorizontalAlignment="Center"/>
                <TextBlock Name="SystemInfoText" Text="Detecting hardware..." 
                          FontSize="12" Foreground="White" HorizontalAlignment="Center" Margin="0,5,0,0"/>
            </StackPanel>
        </Border>
        
        <!-- Tab Control -->
        <TabControl Grid.Row="1" Background="#FF252526" BorderBrush="#FF007ACC" BorderThickness="1">
            
            <!-- Instructions Tab -->
            <TabItem Header="📋 Instructions">
                <Grid Background="#FF1E1E1E">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    
                    <TextBlock Grid.Row="0" Text="Hardware-Specific BIOS &amp; GPU Settings" 
                              FontSize="18" FontWeight="Bold" Foreground="#FF007ACC" Margin="10"/>
                    
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="10">
                        <TextBox Name="InstructionsTextBox" 
                                Text="Loading instructions..." 
                                Background="#FF2D2D30" 
                                Foreground="White" 
                                FontFamily="Consolas" 
                                FontSize="12"
                                IsReadOnly="True" 
                                TextWrapping="Wrap" 
                                BorderThickness="0"
                                Padding="10"/>
                    </ScrollViewer>
                    
                    <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="10">
                        <Button Name="CopyInstructionsBtn" Content="📋 Copy to Clipboard" Width="150" Margin="0,0,10,0"/>
                        <Button Name="RefreshHardwareBtn" Content="🔄 Refresh Hardware" Width="150"/>
                    </StackPanel>
                </Grid>
            </TabItem>
            
            <!-- Restore Point Tab -->
            <TabItem Header="💾 Restore Points">
                <Grid Background="#FF1E1E1E">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    
                    <TextBlock Grid.Row="0" Text="System Restore Points Management" 
                              FontSize="18" FontWeight="Bold" Foreground="#FF007ACC" Margin="10"/>
                    
                    <DataGrid Name="RestorePointsGrid" 
                             Grid.Row="1" 
                             Margin="10"
                             AutoGenerateColumns="False" 
                             IsReadOnly="True"
                             Background="#FF2D2D30"
                             Foreground="White"
                             BorderBrush="#FF007ACC"
                             GridLinesVisibility="None"
                             HeadersVisibility="Column"
                             SelectionMode="Single">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="ID" Binding="{Binding SequenceNumber}" Width="60"/>
                            <DataGridTextColumn Header="Date/Time" Binding="{Binding CreationTime}" Width="180"/>
                            <DataGridTextColumn Header="Description" Binding="{Binding Description}" Width="*"/>
                            <DataGridTextColumn Header="Type" Binding="{Binding Type}" Width="150"/>
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
                        <Button Name="CreateRestorePointBtn" Content="➕ Create Restore Point" Width="180" Margin="0,0,10,0"/>
                        <Button Name="RefreshRestorePointsBtn" Content="🔄 Refresh List" Width="120"/>
                    </StackPanel>
                </Grid>
            </TabItem>
            
            <!-- Tweaks Tab -->
            <TabItem Header="⚡ Tweaks">
                <Grid Background="#FF1E1E1E">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    
                    <TextBlock Grid.Row="0" Text="Automated Gaming Optimizations" 
                              FontSize="18" FontWeight="Bold" Foreground="#FF007ACC" Margin="10"/>
                    
                    <!-- Warning Section -->
                    <Border Grid.Row="1" Background="#FFFF6B00" CornerRadius="5" Padding="15" Margin="10">
                        <StackPanel>
                            <TextBlock Text="⚠️ WARNING" FontSize="16" FontWeight="Bold" Foreground="White"/>
                            <TextBlock TextWrapping="Wrap" Foreground="White" Margin="0,5,0,0">
                                <Run Text="This will make SIGNIFICANT system changes including:"/>
                                <LineBreak/>
                                <Run Text="• Disable Windows services (Search, Xbox, telemetry)"/>
                                <LineBreak/>
                                <Run Text="• Modify power settings and visual effects"/>
                                <LineBreak/>
                                <Run Text="• Optimize network and GPU settings"/>
                                <LineBreak/>
                                <Run Text="• Require system restart for full effect"/>
                                <LineBreak/>
                                <LineBreak/>
                                <Run Text="A restore point will be created automatically."/>
                            </TextBlock>
                        </StackPanel>
                    </Border>
                    
                    <!-- Progress and Log Section -->
                    <Grid Grid.Row="2" Margin="10">
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>
                        
                        <StackPanel Grid.Row="0" Margin="0,0,0,10">
                            <TextBlock Name="ProgressText" Text="Ready to optimize..." Foreground="White" FontSize="14" Margin="0,0,0,5"/>
                            <ProgressBar Name="OptimizationProgress" Height="25" Background="#FF2D2D30" Foreground="#FF007ACC" BorderBrush="#FF007ACC"/>
                        </StackPanel>
                        
                        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                            <TextBox Name="LogTextBox" 
                                    Background="#FF2D2D30" 
                                    Foreground="#FF00FF00" 
                                    FontFamily="Consolas" 
                                    FontSize="11"
                                    IsReadOnly="True" 
                                    TextWrapping="Wrap" 
                                    BorderThickness="1"
                                    BorderBrush="#FF007ACC"
                                    Padding="10"/>
                        </ScrollViewer>
                    </Grid>
                    
                    <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Center" Margin="10">
                        <Button Name="RunTweaksBtn" Content="🚀 RUN OPTIMIZATIONS" Width="200" Height="40" FontSize="16" FontWeight="Bold" Margin="0,0,10,0"/>
                        <Button Name="RestartBtn" Content="🔄 Restart System" Width="150" Height="40" IsEnabled="False"/>
                    </StackPanel>
                </Grid>
            </TabItem>
            
        </TabControl>
        
        <!-- Footer -->
        <Border Grid.Row="2" Background="#FF2D2D30" CornerRadius="5" Padding="10" Margin="0,10,0,0">
            <TextBlock Text="Gaming Optimizer v2.0 | Created for Windows 11 | Use at your own risk" 
                      FontSize="10" Foreground="Gray" HorizontalAlignment="Center"/>
        </Border>
    </Grid>
</Window>
"@

    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)
    
    # Get controls
    $systemInfoText = $window.FindName("SystemInfoText")
    $instructionsTextBox = $window.FindName("InstructionsTextBox")
    $copyInstructionsBtn = $window.FindName("CopyInstructionsBtn")
    $refreshHardwareBtn = $window.FindName("RefreshHardwareBtn")
    $restorePointsGrid = $window.FindName("RestorePointsGrid")
    $createRestorePointBtn = $window.FindName("CreateRestorePointBtn")
    $refreshRestorePointsBtn = $window.FindName("RefreshRestorePointsBtn")
    $runTweaksBtn = $window.FindName("RunTweaksBtn")
    $restartBtn = $window.FindName("RestartBtn")
    $progressText = $window.FindName("ProgressText")
    $optimizationProgress = $window.FindName("OptimizationProgress")
    $logTextBox = $window.FindName("LogTextBox")
    
    # Update system info
    $systemInfoText.Text = "CPU: $($Global:DetectedHardware.CPU.Name) | GPU: $($Global:DetectedHardware.GPU.Name) | RAM: $($Global:DetectedHardware.RAM.TotalGB)GB"
    
    # Load instructions
    $instructionsTextBox.Text = Get-BIOSInstructions -hardware $Global:DetectedHardware
    
    # Load restore points
    $restorePointsGrid.ItemsSource = Get-RestorePoints
    
    # Event Handlers
    $copyInstructionsBtn.Add_Click({
        [System.Windows.Clipboard]::SetText($instructionsTextBox.Text)
        [System.Windows.MessageBox]::Show("Instructions copied to clipboard!", "Success", "OK", "Information")
    })
    
    $refreshHardwareBtn.Add_Click({
        $Global:DetectedHardware = Get-SystemInfo
        $systemInfoText.Text = "CPU: $($Global:DetectedHardware.CPU.Name) | GPU: $($Global:DetectedHardware.GPU.Name) | RAM: $($Global:DetectedHardware.RAM.TotalGB)GB"
        $instructionsTextBox.Text = Get-BIOSInstructions -hardware $Global:DetectedHardware
    })
    
    $createRestorePointBtn.Add_Click({
        try {
            Enable-ComputerRestore -Drive "C:\"
            Checkpoint-Computer -Description "Manual - Gaming Optimizer $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -RestorePointType "MODIFY_SETTINGS"
            [System.Windows.MessageBox]::Show("Restore point created successfully!", "Success", "OK", "Information")
            $restorePointsGrid.ItemsSource = Get-RestorePoints
        } catch {
            [System.Windows.MessageBox]::Show("Failed to create restore point: $_", "Error", "OK", "Error")
        }
    })
    
    $refreshRestorePointsBtn.Add_Click({
        $restorePointsGrid.ItemsSource = Get-RestorePoints
    })
    
    $runTweaksBtn.Add_Click({
        $result = [System.Windows.MessageBox]::Show("Are you sure you want to run all optimizations?`n`nThis will:`n• Create a restore point`n• Modify system settings`n• Require a restart`n`nClick YES to continue.", "Confirm Optimization", "YesNo", "Warning")
        
        if ($result -eq "Yes") {
            $runTweaksBtn.IsEnabled = $false
            $logTextBox.Text = ""
            $Global:OptimizationLog = @()
            
            $progressCallback = {
                param($current, $total, $stepName)
                $window.Dispatcher.Invoke([Action]{
                    $optimizationProgress.Value = ($current / $total) * 100
                    $progressText.Text = "Step $current of $total : $stepName"
                    $logTextBox.Text = ($Global:OptimizationLog -join "`n")
                    $logTextBox.ScrollToEnd()
                })
            }
            
            # Run in background
            $runspace = [runspacefactory]::CreateRunspace()
            $runspace.Open()
            $runspace.SessionStateProxy.SetVariable("progressCallback", $progressCallback)
            
            $powershell = [powershell]::Create()
            $powershell.Runspace = $runspace
            [void]$powershell.AddScript({
                param($callback)
                Invoke-GamingOptimizations -progressCallback $callback
            }).AddArgument($progressCallback)
            
            $asyncResult = $powershell.BeginInvoke()
            
            # Monitor completion
            $timer = New-Object System.Windows.Threading.DispatcherTimer
            $timer.Interval = [TimeSpan]::FromMilliseconds(500)
            $timer.Add_Tick({
                if ($asyncResult.IsCompleted) {
                    $timer.Stop()
                    $powershell.EndInvoke($asyncResult)
                    $powershell.Dispose()
                    $runspace.Close()
                    
                    $window.Dispatcher.Invoke([Action]{
                        $progressText.Text = "✓ Optimization Complete!"
                        $restartBtn.IsEnabled = $true
                        $runTweaksBtn.IsEnabled = $true
                        [System.Windows.MessageBox]::Show("Optimization complete!`n`nPlease restart your system for all changes to take effect.", "Success", "OK", "Information")
                    })
                }
            })
            $timer.Start()
        }
    })
    
    $restartBtn.Add_Click({
        $result = [System.Windows.MessageBox]::Show("Restart system now?", "Restart", "YesNo", "Question")
        if ($result -eq "Yes") {
            Restart-Computer -Force
        }
    })
    
    $window.ShowDialog() | Out-Null
}

#endregion

# Main Execution
try {
    # Check if running as admin
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        [System.Windows.MessageBox]::Show("This script must be run as Administrator!`n`nPlease right-click PowerShell and select 'Run as Administrator'.", "Admin Required", "OK", "Error")
        exit
    }
    
    Show-MainWindow
    
} catch {
    [System.Windows.MessageBox]::Show("Critical Error: $_", "Error", "OK", "Error")
}
