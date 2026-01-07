<#
.SYNOPSIS
Mice System Tools - Sing-box Controller (Windows Edition)
#>

# Path Configuration
$CONF_DIR = Join-Path $HOME "sing-box-config"
$BIN_DIR = Join-Path $HOME ".local/bin"
$SCRIPT_NAME = "sbc.ps1"

# Derived Paths
$ENV_FILE = Join-Path $CONF_DIR ".env"
$TEMPLATE_FILE = Join-Path $CONF_DIR "config.template.json"
$TARGET_CONF = Join-Path $CONF_DIR "config.json"
$SERVICE_ID = "sing-box"
$EXECUTABLE = "sing-box-service.exe" 

# Ensure correct working directory for git and service operations
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

function Load-Env {
    if (Test-Path $ENV_FILE) {
        Get-Content $ENV_FILE | ForEach-Object {
            if ($_ -match "^\s*([^#=]+)=(.*)$") {
                [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process")
            }
        }
    } else {
        Write-Host "❌ Error: .env file not found at $ENV_FILE" -ForegroundColor $Red
        exit 1
    }
}

function Render-Config {
    Write-Host "Evaluating configuration template..." -ForegroundColor $Yellow
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
    Write-Host "✅ Configuration rendered to $TARGET_CONF" -ForegroundColor $Green
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
        & "./sing-box.exe" check -c $TARGET_CONF -D $CONF_DIR
    }
    "update" {
        Write-Host "📡 Pulling updates..." -ForegroundColor $Yellow
        git pull
        
        # Self-update script in bin
        $RepoScript = Join-Path $CONF_DIR $SCRIPT_NAME
        $BinScript = Join-Path $BIN_DIR $SCRIPT_NAME
        if (Test-Path $RepoScript) {
            if (-not (Test-Path $BIN_DIR)) { New-Item -ItemType Directory -Path $BIN_DIR | Out-Null }
            Copy-Item $RepoScript $BinScript -Force
            Write-Host "🔄 Script self-updated in $BIN_DIR" -ForegroundColor $Green
        }

        Load-Env
        Render-Config
        
        Restart-Service $SERVICE_ID
        Write-Host "✨ System updated and restarted." -ForegroundColor $Green
    }
    "install" {
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
