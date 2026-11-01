# Run cdt_ins (Fabric Inserter batch) to produce the ILA .fic, working around the
# "Expiration Reminder" license dialog that otherwise blocks batch mode.
$ErrorActionPreference = 'Stop'
$A = 'E:\file\pango\project\evidence\records\bottleneck_audit'
$ila = Join-Path $A 'contest_final\ila'
$ins = 'E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\bin\cdt_ins.exe'
$gen = Join-Path $ila 'make_ila_fic.ps1'
$tcl = Join-Path $ila 'make_ila_fic.tcl'
$fic = Join-Path $ila 'pangoriscv_coremark.fic'
$log = Join-Path $ila 'log\ins.log'

# 0) regenerate the tcl + probe map (net index resolution)
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $gen
if ($LASTEXITCODE -ne 0) { throw "generator failed" }

# 1) clean slate
Get-Process cdt_ins -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1
Remove-Item $log -Force -ErrorAction SilentlyContinue
Remove-Item $fic -Force -ErrorAction SilentlyContinue
Get-ChildItem $ila -Directory -Filter 'temp_*' -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# 2) launch the inserter (no stdout pipe: the batch tcl must not use puts)
Add-Type -AssemblyName System.Windows.Forms
$fwd = $tcl -replace '\\', '/'
$p = Start-Process -FilePath $ins -ArgumentList @('-device','PG2L100H','-package','FBG676','-speedgrade','-6','-file',$fwd) -WorkingDirectory $ila -PassThru
Write-Host ("cdt_ins pid=" + $p.Id)

$deadline = (Get-Date).AddSeconds(1200)
$dismissed = 0
$why = 'timeout'
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 3
    if (-not (Get-Process -Id $p.Id -ErrorAction SilentlyContinue)) { $why = 'process-exited'; break }
    $dlg = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -match 'Expiration|Reminder|License|Overwrite|Confirm' }
    if ($dlg) {
        foreach ($d in $dlg) {
            try {
                $ws = New-Object -ComObject WScript.Shell
                $null = $ws.AppActivate($d.Id)
                Start-Sleep -Milliseconds 300
                [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
                $dismissed++
                Write-Host ("dismissed [" + $d.MainWindowTitle + "] pid " + $d.Id)
            } catch { Write-Host ("dismiss failed: " + $_.Exception.Message) }
        }
        Start-Sleep -Seconds 1
        continue
    }
    if ((Test-Path $fic) -and ((Get-Item $fic).Length -gt 400) -and (Test-Path $log)) {
        $done = Select-String -Path $log -Pattern 'ins_save successfully' -Quiet
        if ($done) { $why = 'fic-saved'; Start-Sleep -Seconds 2; break }
    }
    if (Test-Path $log) {
        $bad = Select-String -Path $log -Pattern '^E: ' -Quiet
        if ($bad) { $why = 'tool-error'; break }
    }
}
$still = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
if ($still) { $still | Stop-Process -Force; Write-Host 'stopped cdt_ins' }
Start-Sleep -Seconds 1

Write-Host ("why=" + $why + " dismissed=" + $dismissed)
if (Test-Path $fic) { Write-Host ('fic bytes=' + (Get-Item $fic).Length) } else { Write-Host 'fic MISSING' }
Write-Host '=== ins.log: executing/errors/core info ==='
if (Test-Path $log) {
    Select-String -Path $log -Pattern '^(Executing|E:|W: Inserter|Core Information|Trigger Port|Match Unit|Data Same|Data Max|Trigger At|Enable Storage|Clock Port|Reset Port)' |
        ForEach-Object { Write-Host $_.Line }
}

# 3) publish the fic into the ILA debug build tree
$dbg = Join-Path $A 'contest_final\ila_debug\src\platform\pango_native\pangoriscv_coremark.fic'
if ((Test-Path $fic) -and ((Get-Item $fic).Length -gt 400) -and (Test-Path (Split-Path $dbg))) {
    Copy-Item $fic $dbg -Force
    Write-Host ('copied fic -> ' + $dbg + '  sha256=' + (Get-FileHash $dbg -Algorithm SHA256).Hash)
} else {
    Get-Item $dbg -ErrorAction SilentlyContinue | Where-Object { $_.Length -eq 0 } | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host 'fic not valid: debug tree copy skipped/removed'
}
