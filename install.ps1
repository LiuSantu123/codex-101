# Published at releases/latest/download/install.ps1; payloads stay on one release.
# codex-provider-connect: user-local native Windows bootstrap; no administrator needed.
param([string]$Url = $env:CODEX_PROVIDER_URL, [string]$Model, [switch]$Repair, [switch]$Reconfigure, [switch]$RestartIfIdle, [switch]$Lab)

& {
    param([string]$ProviderUrl, [string]$ModelId, [bool]$DoRepair, [bool]$DoReconfigure, [bool]$DoRestartIfIdle, [bool]$DoLab)
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    if (-not [Environment]::Is64BitOperatingSystem) { throw '64-bit Windows is required.' }

    $Release = $env:CODEX_CONNECT_REF
    if (-not $Release) {
        if ($env:CODEX_CONNECT_BASE) { throw 'Set CODEX_CONNECT_REF when using CODEX_CONNECT_BASE.' }
        $Releases = @(Invoke-RestMethod -UseBasicParsing -Uri 'https://api.github.com/repos/Molaison/codex-101/releases?per_page=30' -Headers @{Accept='application/vnd.github+json'} -TimeoutSec 30)
        $Eligible = @()
        foreach ($Item in $Releases) {
            if ($Item.draft -or $Item.tag_name -notmatch '^v\d+\.\d+\.\d+$') { continue }
            $Names = @($Item.assets | ForEach-Object { $_.name })
            if (($Names -contains 'install.sh') -and ($Names -contains 'install.ps1') -and
                ($Names -contains 'codex_provider.py') -and ($Names -contains 'model_catalog.json')) {
                $Eligible += $Item
            }
        }
        $Selected = $Eligible | Where-Object { -not $_.prerelease } | Select-Object -First 1
        if (-not $Selected) { $Selected = $Eligible | Select-Object -First 1 }
        if (-not $Selected) { throw 'No published codex-101 release contains all four installer assets.' }
        $Release = $Selected.tag_name
    }
    $Base = if ($env:CODEX_CONNECT_BASE) { $env:CODEX_CONNECT_BASE } elseif ($env:CODEX_CONNECT_REF) {
        "https://raw.githubusercontent.com/Molaison/codex-101/$Release"
    } else { "https://github.com/Molaison/codex-101/releases/download/$Release" }
    $Root = Join-Path $env:LOCALAPPDATA 'codex-provider-connect'
    $Bin = Join-Path $env:USERPROFILE '.local\bin'
    $Launcher = Join-Path $Bin 'codex.exe'
    $Python = Join-Path $Root 'python\python.exe'
    $Helper = Join-Path $Root 'codex_provider.py'
    $CatalogPath = Join-Path $Root 'model_catalog.json'
    $Stamp = Join-Path $Root 'payload-ref'
    New-Item -ItemType Directory -Force -Path $Root, $Bin | Out-Null
    $Temporary = Join-Path ([IO.Path]::GetTempPath()) ('codex-provider-install-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $Temporary | Out-Null
    try {
        if (-not (Test-Path -LiteralPath $Python)) {
            $Archive = Join-Path $Temporary 'python.zip'
            $PythonUrl = 'https://www.python.org/ftp/python/3.13.7/python-3.13.7-embed-amd64.zip'
            $Expected = 'f6cca216a359be84797cabb54149ce5e062afb16cc7567eb7fc51cacb2d86b65'
            Invoke-WebRequest -UseBasicParsing -Uri $PythonUrl -OutFile $Archive
            if ((Get-FileHash -Algorithm SHA256 -LiteralPath $Archive).Hash.ToLowerInvariant() -ne $Expected) {
                throw 'Python archive SHA256 mismatch; nothing was executed.'
            }
            Expand-Archive -LiteralPath $Archive -DestinationPath (Join-Path $Temporary 'python')
            Move-Item -LiteralPath (Join-Path $Temporary 'python') -Destination (Join-Path $Root 'python')
        }
        $Tagged = $Release -match '^v\d+\.\d+\.\d+$'
        $ExpectedVersion = 'VERSION = "' + $Release.TrimStart('v') + '"'
        $Cached = $false
        if ($Tagged -and -not $env:CODEX_CONNECT_BASE -and (Test-Path -LiteralPath $Stamp) -and
            (Test-Path -LiteralPath $Helper) -and (Test-Path -LiteralPath $CatalogPath)) {
            try {
                $Parsed = Get-Content -Raw -LiteralPath $CatalogPath | ConvertFrom-Json
                $Cached = ((Get-Content -Raw -LiteralPath $Stamp).Trim() -eq $Release) -and
                    (Select-String -LiteralPath $Helper -SimpleMatch $ExpectedVersion -Quiet) -and
                    $Parsed.models -and ($Parsed.models.Count -gt 0)
                if ($Cached) {
                    & $Python -X utf8 -c 'import ast,sys; ast.parse(open(sys.argv[1], encoding="utf-8").read())' $Helper
                    $Cached = $LASTEXITCODE -eq 0
                }
            } catch { $Cached = $false }
        }
        if ($Cached) {
            Write-Host "Reusing local $Release helper and model catalog; no payload download."
        } else {
            $Download = Join-Path $Temporary 'codex_provider.py'
            Invoke-WebRequest -UseBasicParsing -Uri "$Base/codex_provider.py" -OutFile $Download
            # 入口脚本自带默认版本；若它指向的载荷不是同一版本，宁可失败也不要静默装旧版。
            if ($Tagged -and -not (Select-String -LiteralPath $Download -SimpleMatch $ExpectedVersion -Quiet)) {
                throw "Downloaded codex_provider.py does not match $Release; nothing was installed."
            }
            $Catalog = Join-Path $Temporary 'model_catalog.json'
            Invoke-WebRequest -UseBasicParsing -Uri "$Base/model_catalog.json" -OutFile $Catalog
            $Parsed = Get-Content -Raw -LiteralPath $Catalog | ConvertFrom-Json
            if (-not $Parsed.models -or $Parsed.models.Count -eq 0) { throw 'Invalid model catalog; existing setup was not replaced.' }
            Move-Item -Force -LiteralPath $Catalog -Destination $CatalogPath
            Move-Item -Force -LiteralPath $Download -Destination $Helper
            [IO.File]::WriteAllText($Stamp, $Release, [Text.UTF8Encoding]::new($false))
        }
        $Arguments = @('_native-setup')
        if ($DoRepair) { $Arguments += '--repair' }
        if ($DoReconfigure) { $Arguments += '--reconfigure' }
        if ($DoRestartIfIdle) { $Arguments += '--restart-if-idle' }
        if ($DoLab) { $Arguments += '--lab' }
        elseif ($ProviderUrl) { $Arguments += @('--url', $ProviderUrl) }
        if ($ModelId) { $Arguments += @('--model', $ModelId) }
        & $Python -X utf8 $Helper @Arguments
        if ($LASTEXITCODE -ne 0) { throw 'Setup is not verified. Re-run the same fixed download command; no READY was issued.' }
        if ($DoLab) {
            $LabBin = Join-Path $env:LOCALAPPDATA 'CodexLab\bin'
            $LabLauncher = Join-Path $LabBin 'codex.cmd'
            if (-not (Test-Path -LiteralPath $LabLauncher)) { throw 'Lab official Codex launcher is missing; no READY was issued.' }
            $env:Path = "$LabBin;$env:Path"
            Write-Host "`n[READY] Verified with official Codex. Run codex in a new terminal."
            Write-Host "If an existing codex overrides it, run: & `"$LabLauncher`""
            return
        }
        $ExistingCodex = Get-Command codex -ErrorAction SilentlyContinue
        if (-not $ExistingCodex -and (Test-Path -LiteralPath $Launcher)) {
            $Current = [Environment]::GetEnvironmentVariable('Path', 'User')
            if (($Current -split ';') -notcontains $Bin) { [Environment]::SetEnvironmentVariable('Path', "$Bin;$Current", 'User') }
            $env:Path = "$Bin;$env:Path"
        }
        Write-Host "`n[READY] Native configuration, model menu, and real read-only tool check passed."
        if (Get-Command codex -ErrorAction SilentlyContinue) {
            Write-Host 'Start: codex (existing client preserved)'
        } elseif (Test-Path -LiteralPath $Launcher) {
            Write-Host "Start: & `"$Launcher`" (or codex in a new terminal)"
        } else {
            Write-Host 'Continue using the existing client specified by CODEX_BINARY; its entry was not replaced.'
        }
        Write-Host 'Install, update, or repair: re-run the same fixed download command; add -Reconfigure to change the key.'
        Write-Host 'Passed checks are reused; add -Repair only to force a new check.'

    }
    finally {
        Remove-Item -LiteralPath $Temporary -Recurse -Force
    }
} $Url $Model ([bool]$Repair) ([bool]$Reconfigure) ([bool]$RestartIfIdle) ([bool]$Lab)
