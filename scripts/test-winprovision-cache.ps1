param([Parameter(Mandatory)][string]$Helper)
$ErrorActionPreference = 'Stop'
$Helper = (Resolve-Path $Helper).Path
$probeRoot = Join-Path $env:TEMP ('winprovision-cache-probe-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $probeRoot | Out-Null
$pidFile = Join-Path $probeRoot 'worker.pid'
$readyFile = Join-Path $probeRoot 'ready'
$probe = @'
$ErrorActionPreference = 'Stop'
[IO.File]::WriteAllText('__PID_FILE__', [string]$PID)
$deadline = [DateTime]::UtcNow.AddSeconds(40)
while (-not (Test-Path -LiteralPath '__READY_FILE__')) {
    if ([DateTime]::UtcNow -gt $deadline) { throw 'Cache authorization was not provided.' }
    Start-Sleep -Milliseconds 100
}
$status = & '__HELPER__' status --json | ConvertFrom-Json
if (-not $status.CacheAvailable) { throw 'Scoped cache unavailable to the medium worker.' }
& '__HELPER__' --direct "$env:SystemRoot/System32/cmd.exe" /d /c exit 37
exit $LASTEXITCODE
'@
$probe = $probe.Replace('__PID_FILE__',$pidFile).Replace('__READY_FILE__',$readyFile).Replace('__HELPER__',$Helper)
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($probe))
$launcher = Start-Process -FilePath $Helper -ArgumentList @('--integrity','Medium','--direct',"$env:SystemRoot/System32/WindowsPowerShell/v1.0/powershell.exe",'-NoProfile','-NonInteractive','-EncodedCommand',$encoded) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $probeRoot 'stdout.txt') -RedirectStandardError (Join-Path $probeRoot 'stderr.txt')
$workerPid = 0
try {
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    while (-not (Test-Path -LiteralPath $pidFile)) {
        if ($launcher.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw 'Medium worker did not start.' }
        Start-Sleep -Milliseconds 100
    }
    $workerPid = [int](Get-Content -LiteralPath $pidFile -Raw)
    if ($workerPid -le 0) { throw 'Invalid worker PID.' }
    & $Helper cache on --pid $workerPid --duration 00:02:00
    if ($LASTEXITCODE -ne 0) { throw 'Cache authorization failed.' }
    [IO.File]::WriteAllText($readyFile,'ready')
    if (-not $launcher.WaitForExit(60000)) { throw 'Medium worker timed out.' }
    if ($launcher.ExitCode -ne 37) { throw "Unexpected cached worker exit: $($launcher.ExitCode)." }
    Write-Output 'Medium worker reused its explicit PID-scoped cache and preserved child exit 37.'
} finally {
    if ($workerPid -gt 0) { & $Helper cache off --pid $workerPid }
    Get-Content -LiteralPath (Join-Path $probeRoot 'stdout.txt') -ErrorAction SilentlyContinue
    Get-Content -LiteralPath (Join-Path $probeRoot 'stderr.txt') -ErrorAction SilentlyContinue
    if (-not $launcher.HasExited) { $launcher.Kill() }
    $launcher.Dispose()
}
exit 0
