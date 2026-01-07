<#
.SYNOPSIS
Mice System Tools - Sing-box Controller (Windows Edition)
#>

$CONF_DIR = $PSScriptRoot
$ENV_FILE = Join-Path $CONF_DIR ".env"
$TEMPLATE_FILE = Join-Path $CONF_DIR "config.template.json"
$TARGET_CONF = Join-Path $CONF_DIR "config.json"
$SERVICE_ID = "sing-box"
$EXECUTABLE = "sing-box-service.exe" # WinSW renamed

# Colors for output
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
    
    # Simple envsubst implementation
    $content = Get-Content $TEMPLATE_FILE -Raw
    # Find all ${VAR} patterns
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

# Main Logic
$Command = $args[0]

switch ($Command) {
    "start" {
        Write-Host "Starting sing-box service..." -ForegroundColor $Green
        Start-Service $SERVICE_ID
    }
    "stop" {
        Write-Host "Stopping sing-box service..." -ForegroundColor $Yellow
        Stop-Service $SERVICE_ID
    }
    "restart" {
        Write-Host "Restarting sing-box service..." -ForegroundColor $Green
        Restart-Service $SERVICE_ID
        Write-Host "Service restarted."
    }
    "status" {
        Get-Service $SERVICE_ID
    }
    "log" {
        $LogFile = Join-Path $CONF_DIR "sing-box.out.log"
        if (Test-Path $LogFile) {
            Get-Content $LogFile -Tail 50 -Wait
        } else {
            Write-Host "Log file not found: $LogFile" -ForegroundColor $Red
        }
    }
    "check" {
        Write-Host "Checking configuration syntax..." -ForegroundColor $Yellow
        if (Test-Path $TARGET_CONF) {
            & "./sing-box.exe" check -c $TARGET_CONF
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Syntax check passed." -ForegroundColor $Green
            } else {
                Write-Host "❌ Syntax check failed." -ForegroundColor $Red
                exit 1
            }
        } else {
             Write-Host "❌ Config file not found." -ForegroundColor $Red
        }
    }
    "update" {
        Write-Host "📡 Pulling latest directives from command center..." -ForegroundColor $Yellow
        git pull
        
        Load-Env
        Render-Config
        
        Write-Host "Checking syntax..."
        & "./sing-box.exe" check -c $TARGET_CONF
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Syntax passed. Deploying..." -ForegroundColor $Green
            Restart-Service $SERVICE_ID
            Write-Host "✨ Synchronization complete! PC is now in orbit." -ForegroundColor $Green
        } else {
            Write-Host "❌ Rendered config invalid. Aborting." -ForegroundColor $Red
            exit 1
        }
    }
    "install" {
        Write-Host "Registering Windows Service..." -ForegroundColor $Yellow
        Load-Env
        Render-Config # Ensure config exists before starting
        & "./$EXECUTABLE" install
        & "./$EXECUTABLE" start
        Write-Host "✅ Service installed and started." -ForegroundColor $Green
    }
    "uninstall" {
        Write-Host "Unregistering Windows Service..." -ForegroundColor $Yellow
        & "./$EXECUTABLE" stop
        & "./$EXECUTABLE" uninstall
        Write-Host "✅ Service uninstalled." -ForegroundColor $Green
    }
    Default {
        Show-Usage
    }
}
