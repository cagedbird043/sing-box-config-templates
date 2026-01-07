<#
.SYNOPSIS
Mice System Tools - Sing-box Controller (Windows Edition + Scoop)
#>

# Path Configuration
$CONF_DIR = Join-Path $HOME "sing-box-config"
$BIN_DIR = Join-Path $HOME ".local/bin"
$SCRIPT_NAME = "sbc.ps1"

# Derived Paths
$ENV_FILE = Join-Path $CONF_DIR ".env"
$TEMPLATE_FILE = Join-Path $CONF_DIR "config.template.json"
$TARGET_CONF = Join-Path $CONF_DIR "config.json"
$MANIFEST = Join-Path $CONF_DIR "sing-box.json"

$SERVICE_ID = "sing-box"
$EXECUTABLE = "sing-box-service.exe" # Copied from WinSW

# Ensure correct working directory
if (Test-Path $CONF_DIR) {
    Set-Location $CONF_DIR
}

# Colors
$Green = "Green"
$Red = "Red"
$Yellow = "Yellow"

function Show-Usage {
    Write-Host "Usage: sbc {start|stop|restart|status|update|check|log|install|uninstall}"
}

function Ensure-Scoop {
    if (-not (Get-Command "scoop" -ErrorAction SilentlyContinue)) {
        Write-Host "📦 Installing Scoop..." -ForegroundColor $Yellow
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        irm get.scoop.sh | iex
        Write-Host "✅ Scoop installed." -ForegroundColor $Green
    }
}

function Load-Env {
    if (Test-Path $ENV_FILE) {
        Get-Content $ENV_FILE | ForEach-Object {
            if ($_ -match "^\s*([^#=]+)=(.*)$") {
                [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process")
            }
        }
    } else {
        Write-Host "⚠️ Warning: .env file not found." -ForegroundColor $Red
    }
}

function Render-Config {
    Write-Host "Evaluating configuration template..." -ForegroundColor $Yellow
    if (-not (Test-Path $TEMPLATE_FILE)) { return }
    $content = Get-Content $TEMPLATE_FILE -Raw
    $matches = [regex]::Matches($content, '\$\{([^}]+)\}')
    foreach ($match in $matches) {
        $varName = $match.Groups[1].Value
        $val = [Environment]::GetEnvironmentVariable($varName, "Process")
        if ($null -ne $val) {
            $content = $content.Replace($match.Value, $val)
        }
    }
    Set-Content $TARGET_CONF $content -Encoding UTF8
    Write-Host "✅ Configuration rendered." -ForegroundColor $Green
}

$Command = $args[0]
if (-not $Command) { $Command = "status" }

switch ($Command) {
    "start" { Start-Service $SERVICE_ID; Write-Host "✅ Service started." -ForegroundColor $Green }
    "stop" { Stop-Service $SERVICE_ID; Write-Host "🛑 Service stopped." -ForegroundColor $Yellow }
    "restart" { Restart-Service $SERVICE_ID; Write-Host "✨ Service restarted." -ForegroundColor $Green }
    "status" { Get-Service $SERVICE_ID }
    "log" {
        $LogFile = Join-Path $CONF_DIR "sing-box.out.log"
        if (Test-Path $LogFile) { Get-Content $LogFile -Tail 50 -Wait } 
        else { Write-Host "Log file not found." -ForegroundColor $Red }
    }
    "check" {
        scoop shim sing-box # Re-shim to ensure path
        sing-box check -c $TARGET_CONF -D $CONF_DIR
    }
    "update" {
        Write-Host "📡 Pulling scripts updates..." -ForegroundColor $Yellow
        git pull
        
        # Self-update script
        $RepoScript = Join-Path $CONF_DIR $SCRIPT_NAME
        $BinScript = Join-Path $BIN_DIR $SCRIPT_NAME
        if (Test-Path $RepoScript) {
             if (-not (Test-Path $BIN_DIR)) { New-Item -ItemType Directory -Path $BIN_DIR | Out-Null }
             Copy-Item $RepoScript $BinScript -Force
        }

        Write-Host "📦 Updating binaries via Scoop..." -ForegroundColor $Yellow
        # Update via manifest file requires re-install or specific handling if bucket non-existent
        # Trying install first to handle upgrades if checkver detects change
        # Note: 'scoop install' fails if already installed unless '-u' (update) is used? 
        # No, scoop update for local file is tricky.
        # Strategy: uninstall sing-box-mice -> install
        # Or: check if version changed?
        
        # Simplest consistent approach for this custom setup:
        scoop uninstall sing-box-mice
        scoop install $MANIFEST

        Load-Env
        Render-Config
        Restart-Service $SERVICE_ID
        Write-Host "✨ System updated and restarted." -ForegroundColor $Green
    }
    "install" {
        Ensure-Scoop
        Write-Host "📦 Installing Dependencies..." -ForegroundColor $Yellow
        scoop install winsw
        
        # Install sing-box from local manifest
        if (Get-Command "sing-box" -ErrorAction SilentlyContinue) {
             Write-Host "sing-box already installed, ensuring version..."
             scoop uninstall sing-box-mice
             scoop install $MANIFEST
        } else {
             scoop install $MANIFEST
        }

        # Setup WinSW
        $WinSWPath = "$(scoop prefix winsw)\winsw.exe"
        if (Test-Path $WinSWPath) {
             Copy-Item $WinSWPath ".\$EXECUTABLE" -Force
             Write-Host "✅ WinSW Copied." -ForegroundColor $Green
        } else {
             Write-Host "❌ WinSW not found at $WinSWPath" -ForegroundColor $Red
             exit 1
        }

        Load-Env
        Render-Config
        & "./$EXECUTABLE" install
        & "./$EXECUTABLE" start
        Write-Host "✅ Service installed." -ForegroundColor $Green
    }
    "uninstall" {
        & "./$EXECUTABLE" stop
        & "./$EXECUTABLE" uninstall
    }
    Default { Show-Usage }
}
