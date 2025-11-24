param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("link", "unlink", "relink")]
    [string]$Action
)

# Get Steam installation path
$steamPath = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Valve\Steam' -ErrorAction SilentlyContinue).InstallPath

if (-not $steamPath) {
    Write-Error "Unable to find Steam installation path. Please ensure Steam is installed correctly."
    exit 1
}

$skinsPath = Join-Path $steamPath "steamui\skins"
$themeName = "elaina-steam-theme-dev"
$targetPath = Join-Path $skinsPath $themeName
$sourcePath = Join-Path $PSScriptRoot "..\dist"

# Relink operation (remove then create)
if ($Action -eq "relink") {
    Write-Host "Executing relink operation..." -ForegroundColor Cyan

    # Remove existing link first
    if (Test-Path $targetPath) {
        $item = Get-Item $targetPath
        if ($item.LinkType -eq "SymbolicLink" -or $item.LinkType -eq "Junction") {
            Write-Host "Removing existing link: $targetPath"
            try {
                Remove-Item $targetPath -Force -Recurse -ErrorAction Stop
                Write-Host "✓ Removed successfully" -ForegroundColor Green
            } catch {
                Write-Error "Failed to remove link: $_"
                exit 1
            }
        } else {
            Write-Error "Target path exists and is not a link: $targetPath"
            Write-Host "Please manually delete the directory and try again"
            exit 1
        }
    } else {
        Write-Host "Target path does not exist, skipping removal step" -ForegroundColor Yellow
    }

    # Set Action to link to continue with link logic
    $Action = "link"
    Write-Host ""
}

# Link operation
if ($Action -eq "link") {
    # Ensure skins directory exists
    if (-not (Test-Path $skinsPath)) {
        Write-Host "Creating skins directory: $skinsPath"
        New-Item -ItemType Directory -Path $skinsPath -Force | Out-Null
    }

    # Check if symbolic link or directory already exists
    if (Test-Path $targetPath) {
        $item = Get-Item $targetPath
        if ($item.LinkType -eq "SymbolicLink" -or $item.LinkType -eq "Junction") {
            Write-Host "Removing existing symbolic link: $targetPath"
            Remove-Item $targetPath -Force -Recurse
        } else {
            Write-Error "Target path already exists and is not a symbolic link: $targetPath"
            Write-Host "Please manually delete the directory and try again"
            exit 1
        }
    }

    # Create symbolic link
    Write-Host "Creating symbolic link..."
    Write-Host "Source path: $sourcePath"
    Write-Host "Target path: $targetPath"

    try {
        # Use Junction (does not require administrator privileges)
        $absoluteSourcePath = (Resolve-Path $sourcePath).Path
        $result = cmd /c mklink /J "$targetPath" "$absoluteSourcePath"

        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "✓ Directory junction created successfully!" -ForegroundColor Green
            Write-Host "Theme linked to: $targetPath"
        } else {
            throw "mklink command failed"
        }
    } catch {
        Write-Host ""
        Write-Error "Failed to create directory junction: $_"
        Write-Host ""
        Write-Host "Note: Creating symbolic links requires administrator privileges" -ForegroundColor Yellow
        Write-Host "Please run PowerShell or terminal as administrator and execute this command again" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "How to run as administrator:" -ForegroundColor Cyan
        Write-Host "1. Search for 'PowerShell' in the start menu" -ForegroundColor Cyan
        Write-Host "2. Right-click on 'Windows PowerShell'" -ForegroundColor Cyan
        Write-Host "3. Select 'Run as administrator'" -ForegroundColor Cyan
        Write-Host "4. Navigate to the project directory using cd" -ForegroundColor Cyan
        Write-Host "5. Re-run: pnpm run dev:link" -ForegroundColor Cyan
        exit 1
    }
}

# Unlink operation
if ($Action -eq "unlink") {
    # Check if symbolic link exists
    if (-not (Test-Path $targetPath)) {
        Write-Host "Symbolic link does not exist: $targetPath" -ForegroundColor Yellow
        Write-Host "No need to remove"
        exit 0
    }

    # Check if it is a symbolic link
    $item = Get-Item $targetPath
    if ($item.LinkType -ne "SymbolicLink" -and $item.LinkType -ne "Junction") {
        Write-Error "Target path is not a symbolic link: $targetPath"
        Write-Host "For safety reasons, please manually delete the directory"
        exit 1
    }

    # Remove symbolic link
    Write-Host "Removing symbolic link: $targetPath"

    try {
        Remove-Item $targetPath -Force -Recurse -ErrorAction Stop
        Write-Host ""
        Write-Host "✓ Symbolic link removed successfully!" -ForegroundColor Green
    } catch {
        Write-Host ""
        Write-Error "Failed to remove symbolic link: $_"
        Write-Host ""
        Write-Host "Note: Removing symbolic links may require administrator privileges" -ForegroundColor Yellow
        Write-Host "Please run PowerShell or terminal as administrator and execute this command again" -ForegroundColor Yellow
        exit 1
    }
}
