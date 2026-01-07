<#
.SYNOPSIS
Mice System Tools - Sing-box Controller (Windows Edition + Scoop + Git Separation)
#>

# Path Configuration
$REPO_DIR = Join-Path $HOME "sing-box-repo"
$CONF_DIR = Join-Path $HOME "sing-box-config"
$BIN_LINK = Join-Path $HOME ".local/bin/sbc.ps1"

# Derived Paths
$ENV_FILE = Join-Path $CONF_DIR ".env"
$TEMPLATE_FILE = Join-Path $REPO_DIR "config.template.json"
$TARGET_CONF = Join-Path $CONF_DIR "config.json"
$MANIFEST = Join-Path $REPO_DIR "sing-box.json"

$SERVICE_ID = "sing-box"
$EXECUTABLE = "sing-box-service.exe" # Copied from WinSW

# Ensure correct working directory (Runtime)
if (-not (Test-Path $CONF_DIR)) {
    # If config dir doesn't exist, we can't do much, but let's try to create it if we are initializing?
    # Usually we expect setup to handle this.
    # Write-Host "Config dir missing: $CONF_DIR"
} else {
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
            # Match KEY=VALUE, ignoring comments
            if ($_ -match "^\s*([^#=]+)=(.*)$") {
                $key = $matches[1].Trim()
                $val = $matches[2].Trim()
                
                # Strip wrapping quotes if present
                if ($val.Length -ge 2) {
                    if (($val.StartsWith('"') -and $val.EndsWith('"')) -or 
                        ($val.StartsWith("'") -and $val.EndsWith("'"))) {
                        $val = $val.Substring(1, $val.Length - 2)
                    }
                }
                
                [Environment]::SetEnvironmentVariable($key, $val, "Process")
            }
        }
    } else {
        Write-Host "⚠️ Warning: .env file not found at $ENV_FILE" -ForegroundColor $Red
    }
}

function Render-Config {
    Write-Host "Evaluating configuration template..." -ForegroundColor $Yellow
    if (-not (Test-Path $TEMPLATE_FILE)) { 
        Write-Host "❌ Template not found at $TEMPLATE_FILE" -ForegroundColor $Red
        return 
    }
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
        if (Test-Path "$CONF_DIR\sing-box.exe") {
             scoop shim sing-box # Force shim update sometimes helps
        }
        sing-box check -c $TARGET_CONF -D $CONF_DIR
    }
    "update" {
        Write-Host "📡 Pulling scripts updates (Repo)..." -ForegroundColor $Yellow
        if (Test-Path $REPO_DIR) {
            Push-Location $REPO_DIR
            git pull
            Pop-Location
        } else {
            Write-Host "⚠️ Repo directory not found at $REPO_DIR" -ForegroundColor $Red
        }
        
        # Binary update
        Write-Host "📦 Updating binaries via Scoop..." -ForegroundColor $Yellow
        # Uninstall/Install to force update from local manifest
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
        scoop config aria2-enabled false
        scoop install winsw
        
        # Install sing-box from local manifest
        if (Get-Command "sing-box" -ErrorAction SilentlyContinue) {
             Write-Host "sing-box already installed, checking version..."
             scoop uninstall sing-box-mice
             scoop install $MANIFEST
        } else {
             scoop install $MANIFEST
        }
        scoop config aria2-enabled true 

        # Setup WinSW
        $WinSWPath = "$(scoop prefix winsw)\winsw.exe"
        if (Test-Path $WinSWPath) {
             Copy-Item $WinSWPath ".\$EXECUTABLE" -Force
             Write-Host "✅ WinSW Copied." -ForegroundColor $Green
        } else {
             Write-Host "❌ WinSW not found at $WinSWPath" -ForegroundColor $Red
             exit 1
        }
        
        # Ensure config file match
        if (Test-Path "sing-box-service.xml") {
             Write-Host "✅ Service config found." -ForegroundColor $Green
        } else {
             Write-Host "❌ sing-box-service.xml missing!" -ForegroundColor $Red
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
