# Windows 11 Gaming Optimizer - GUI Edition 🎮

**Complete web-executable GUI tool for maximum Windows 11 gaming performance**

Similar to Chris Titus's Windows Utility, but specifically optimized for gaming!

---

## 🚀 Quick Start (For Users)

### One-Line Installation

```powershell
# Open PowerShell as Administrator, then run:
iwr -useb https://YOUR-DOMAIN.com/Win11-Gaming-Optimizer-GUI.ps1 | iex
```

*Replace `YOUR-DOMAIN.com` with the actual hosting URL*

---

## 📦 What's Included

### 1. **Win11-Gaming-Optimizer-GUI.ps1**
Modern WPF GUI application with three main tabs:

#### 📋 Instructions Tab
- **Hardware Auto-Detection**: Automatically detects CPU, GPU, RAM, Motherboard
- **CPU-Specific Settings**: Intel vs AMD optimized BIOS instructions
- **GPU-Specific Settings**: NVIDIA, AMD, or Intel Arc optimizations
- **Motherboard-Specific**: ASUS, MSI, Gigabyte, ASRock custom guides
- **Copy to Clipboard**: Easy reference while in BIOS

#### 💾 Restore Points Tab
- **View All Restore Points**: See all existing restore points
- **Create New**: One-click restore point creation
- **Detailed Info**: Date, time, description, and type
- **Easy Management**: Refresh and monitor restore points

#### ⚡ Tweaks Tab
- **One-Click Optimization**: Run all 13 tweaks automatically
- **Real-Time Progress**: Live progress bar and status updates
- **Detailed Logging**: See exactly what's happening
- **Safe Execution**: Auto-creates restore point first
- **Quick Restart**: Restart button enabled after completion

### 2. **index.html**
Beautiful landing page for web hosting with:
- Installation instructions
- Feature overview
- Expected performance gains
- Safety information
- Copy-paste commands

### 3. **Documentation**
- Complete deployment guide (this file)
- Troubleshooting section
- Safety notes
- Rollback procedures

---

## 🎯 Features Overview

### Automated Optimizations (13 Total)

1. ✅ **System Restore Point** - Auto-created before changes
2. ✅ **Service Optimization** - Disable telemetry, search, Xbox services
3. ✅ **Power Settings** - Ultimate Performance power plan
4. ✅ **Game DVR** - Disabled for better performance
5. ✅ **Visual Effects** - Optimized for performance
6. ✅ **Network Settings** - Gaming-focused TCP/IP tuning
7. ✅ **Background Apps** - Disabled for resource savings
8. ✅ **GPU Scheduling** - Hardware-accelerated scheduling enabled
9. ✅ **Game Mode** - Windows Game Mode enabled
10. ✅ **Mouse Input** - Acceleration disabled, 1:1 input
11. ✅ **Fullscreen Optimizations** - Configured for gaming
12. ✅ **Windows Update** - Active hours configured
13. ✅ **Temp Files** - System cleanup

---

## 📋 System Requirements

- **OS**: Windows 11 (22H2 or later)
- **Permissions**: Administrator required
- **PowerShell**: Version 5.1 or higher
- **RAM**: 8GB minimum (16GB+ recommended)
- **Disk**: 10GB free space (for restore point)
- **.NET**: 4.7.2 or higher (usually pre-installed on Windows 11)

---

## 🌐 Deployment Guide (For Hosts)

### Option 1: GitHub Pages (Recommended - Free)

1. **Create GitHub Repository**
```bash
git init
git add Win11-Gaming-Optimizer-GUI.ps1 index.html
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/yourusername/gaming-optimizer.git
git push -u origin main
```

2. **Enable GitHub Pages**
- Go to repository Settings → Pages
- Source: Deploy from main branch
- Root directory: `/`

3. **Your URL will be:**
```
https://yourusername.github.io/gaming-optimizer/Win11-Gaming-Optimizer-GUI.ps1
```

4. **Users run:**
```powershell
iwr -useb https://yourusername.github.io/gaming-optimizer/Win11-Gaming-Optimizer-GUI.ps1 | iex
```

---

### Option 2: Raw GitHub Link

1. **Upload to GitHub**
2. **Get Raw URL**
   - Navigate to the `.ps1` file
   - Click "Raw" button
   - Copy URL (e.g., `https://raw.githubusercontent.com/user/repo/main/Win11-Gaming-Optimizer-GUI.ps1`)

3. **Users run:**
```powershell
iwr -useb https://raw.githubusercontent.com/USER/REPO/main/Win11-Gaming-Optimizer-GUI.ps1 | iex
```

---

### Option 3: Custom Web Server

1. **Upload files to your web server**
```
/public_html/
  ├── index.html
  └── Win11-Gaming-Optimizer-GUI.ps1
```

2. **Configure MIME type** (if needed)
```
AddType application/octet-stream .ps1
```

3. **Enable CORS** (optional, for web requests)
```
Access-Control-Allow-Origin: *
```

4. **Users run:**
```powershell
iwr -useb https://yourdomain.com/Win11-Gaming-Optimizer-GUI.ps1 | iex
```

---

### Option 4: Pastebin / Gist (Quick & Easy)

1. **Create a GitHub Gist**
   - Go to https://gist.github.com/
   - Paste the script content
   - Create public Gist

2. **Get Raw URL**
   - Click "Raw" button
   - Copy URL

3. **Users run:**
```powershell
iwr -useb https://gist.githubusercontent.com/USER/GIST_ID/raw/FILENAME.ps1 | iex
```

---

## 🎨 Customization

### Branding

Edit the XAML in the script to customize:
- Window title
- Colors (change #007ACC to your brand color)
- Logo/Header text
- Footer information

```powershell
# Find and modify this section:
Title="Windows 11 Gaming Optimizer - Beast Mode"
Background="#FF1E1E1E"
```

### Add/Remove Optimizations

Modify the `Invoke-GamingOptimizations` function:

```powershell
$steps = @(
    @{ Name = "Your Custom Tweak"; Action = { Your-CustomFunction } },
    # Add your optimizations here
)
```

### Hardware Detection

Extend `Get-SystemInfo` to detect additional hardware:

```powershell
# Add to the function:
$hwInfo.YourComponent = @{
    Property1 = $value
    Property2 = $value
}
```

---

## 📖 User Guide

### For End Users

1. **Before Running**
   - Close all important applications
   - Ensure at least 10GB free disk space
   - Read the warnings in the GUI

2. **Running the Tool**
   ```powershell
   # Open PowerShell as Admin
   iwr -useb YOUR_URL | iex
   ```

3. **Instructions Tab**
   - Review hardware-specific BIOS settings
   - Copy instructions for reference
   - Apply BIOS changes manually

4. **Restore Points Tab**
   - Optional: Create manual restore point
   - View existing restore points
   - Note the latest point ID

5. **Tweaks Tab**
   - Read the warning
   - Click "RUN OPTIMIZATIONS"
   - Wait for completion (2-3 minutes)
   - Click "Restart System" when prompted

6. **After Restart**
   - Test your favorite games
   - Monitor temperatures
   - Check performance improvements

---

## 🛠️ Troubleshooting

### GUI Doesn't Appear

**Issue**: Script runs but no window shows

**Solution**:
```powershell
# Check .NET Framework version
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" | Select-Object Release, Version

# Reinstall .NET if needed (Windows 11 should have it)
# Or run in compatibility mode
```

---

### Execution Policy Error

**Issue**: "Running scripts is disabled on this system"

**Solution**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Or run with bypass:
```powershell
powershell -ExecutionPolicy Bypass -Command "iwr -useb YOUR_URL | iex"
```

---

### Hardware Detection Fails

**Issue**: "Unknown" hardware or incorrect detection

**Solution**:
- Click "Refresh Hardware" button
- Update Windows Management Instrumentation (WMI)
- Check Windows Update for driver updates

---

### Optimization Fails

**Issue**: Specific tweaks fail with errors

**Solution**:
1. Check the log output in Tweaks tab
2. Note which step failed
3. Manual fix:
   ```powershell
   # Re-enable a service if needed
   Set-Service -Name "ServiceName" -StartupType Automatic
   Start-Service -Name "ServiceName"
   ```

---

### System Unstable After Optimization

**Issue**: Crashes, freezes, or performance worse

**Solution**:
1. **Boot into Safe Mode** (F8 during startup)
2. **Restore from restore point**:
   ```powershell
   # In Safe Mode PowerShell:
   Get-ComputerRestorePoint
   Restore-Computer -RestorePoint X  # X = latest point number
   ```

Or via GUI:
- Settings → System → Recovery → Go back

---

## 🔒 Security Considerations

### Code Signing (Optional but Recommended)

For production deployment:

1. **Get a code signing certificate**
2. **Sign the script**:
```powershell
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert
Set-AuthenticodeSignature -FilePath "Win11-Gaming-Optimizer-GUI.ps1" -Certificate $cert
```

3. **Users verify**:
```powershell
Get-AuthenticodeSignature Win11-Gaming-Optimizer-GUI.ps1
```

---

### HTTPS Only

**Always use HTTPS** for the download URL to prevent man-in-the-middle attacks:

❌ Bad: `http://example.com/script.ps1`
✅ Good: `https://example.com/script.ps1`

GitHub Pages and Gist automatically use HTTPS.

---

## 📊 Analytics & Tracking (Optional)

Add usage tracking to understand adoption:

```powershell
# Add to main execution block:
try {
    Invoke-WebRequest -Uri "https://yourserver.com/track?event=launch" -Method POST -UseBasicParsing -TimeoutSec 2
} catch { }
```

---

## 🤝 Contributing

### Reporting Issues

Users can report issues with:
- Hardware configuration
- Error messages
- Step that failed
- Windows version

### Adding Features

To add new optimizations:
1. Create function in the script
2. Add to `$steps` array
3. Update documentation
4. Test thoroughly

---

## 📜 License & Disclaimer

**MIT License** - Free to use, modify, and distribute

**DISCLAIMER**:
```
This tool modifies system settings that may affect stability.
Use at your own risk. The creators are not responsible for:
- System instability
- Data loss
- Hardware damage
- Performance degradation
- Any other issues arising from use

ALWAYS maintain backups and restore points.
Test in a non-critical environment first.
```

---

## 🎯 Best Practices for Hosts

1. ✅ **Use HTTPS** - Security first
2. ✅ **Version Control** - Track changes via Git
3. ✅ **Changelog** - Document updates
4. ✅ **Test Before Deploy** - Test all changes
5. ✅ **Backup Old Versions** - Keep previous releases
6. ✅ **Monitor Issues** - Track user feedback
7. ✅ **Update Regularly** - Keep up with Windows updates

---

## 📈 Marketing Your Tool

### Sample Social Posts

**Twitter/X:**
```
🎮 New: Windows 11 Gaming Optimizer GUI

✅ Auto-detects hardware
✅ BIOS instructions per component
✅ One-click optimizations
✅ 10-30% latency reduction

One line to run:
iwr -useb YOUR_URL | iex

#Gaming #Windows11 #PCOptimization
```

**Reddit:**
```
Title: [Tool] Windows 11 Gaming Optimizer - GUI with hardware detection

I created a GUI tool that auto-detects your CPU/GPU/RAM and provides 
specific BIOS optimization instructions. Also includes one-click system 
tweaks for gaming performance.

Features:
- Hardware-specific BIOS guides
- Automated optimizations
- Restore point management
- Web-executable (like Chris Titus Tool)

[Download/Run Instructions]
```

---

## 🔄 Update Workflow

When updating the script:

1. **Test locally** with the new changes
2. **Update version number** in the script
3. **Document changes** in changelog
4. **Push to repository**
5. **Notify users** via your channels
6. **Users get updates** automatically (next run pulls latest)

---

## 💡 Pro Tips

### For Users:
- Run benchmarks before and after
- Monitor temps for first few hours
- Keep the BIOS instructions handy
- Screenshot the log output

### For Hosts:
- Use GitHub Releases for versioning
- Create a Discord for community support
- Document common issues
- Provide video tutorial

---

## 📞 Support

### For Users:
1. Check log output in Tweaks tab
2. Review troubleshooting section
3. Use restore point if unstable
4. Report issues with full details

### For Hosts:
1. Monitor repository issues
2. Update FAQ based on questions
3. Test on multiple configurations
4. Maintain compatibility matrix

---

## 🌟 Success Metrics

Track improvements with benchmarks:

**Before Optimization:**
- 3DMark score
- Cinebench R23
- LatencyMon DPC latency
- In-game FPS benchmarks

**After Optimization:**
- Re-run same tests
- Compare results
- Document gains
- Share testimonials

---

## 🎬 Demo Video Script

**Introduction (0:00-0:30)**
- Show the one-line command
- Emphasize ease of use

**Hardware Detection (0:30-1:00)**
- Show Instructions tab
- Highlight auto-detected components
- Show BIOS instructions

**Restore Points (1:00-1:30)**
- Create restore point
- Show list of points
- Explain safety

**Running Tweaks (1:30-3:00)**
- Run optimization
- Show progress
- Show log output
- Restart

**Results (3:00-4:00)**
- Before/after benchmarks
- Show FPS improvements
- Show latency reduction

---

**Ready to deploy? Host the files and share your URL!**

**Example final command:**
```powershell
iwr -useb https://yourdomain.com/Win11-Gaming-Optimizer-GUI.ps1 | iex
```

🚀 **Happy Gaming!**
