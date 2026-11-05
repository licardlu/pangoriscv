param(
    [string]$BuildName = '',
    [Parameter(Mandatory=$true)][string]$EvidenceTag,
    [Parameter(Mandatory=$true)][string]$PdsShell,
    [string]$Bitstream = '',
    [string]$BitstreamSha256 = '',
    [string]$SerialPort = 'COM34',
    [int]$JtagPort = 65420,
    [int]$TimeoutSeconds = 65
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ($BuildName -ne '' -and $BuildName -notmatch '^[A-Za-z0-9_-]+$') { throw 'BuildName must be a single name' }
if ($BuildName -eq '' -and $Bitstream -eq '') {
    throw 'Give either -BuildName <name of a build under build/> or -Bitstream <path to an .sbit>'
}
if ($EvidenceTag -notmatch '^[A-Za-z0-9_/-]+$' -or $EvidenceTag.Contains('..')) { throw 'Invalid evidence tag' }

if ($BuildName -ne '') {
    # Re-program a bitstream produced by `python tools/build.py build --name <BuildName>`.
    $BuildDir = Join-Path $Root "build/$BuildName"
    if (-not (Test-Path -LiteralPath $BuildDir -PathType Container)) {
        throw "No such build directory: $BuildDir. Use -Bitstream to program a shipped bitstream."
    }
    $Result = Get-Content (Join-Path $BuildDir 'build_result.json') -Raw | ConvertFrom-Json
    $BitstreamPath = Join-Path $Root $Result.bitstream
    $ExpectedSha = $Result.sha256
    $BuildRecord = "build/$BuildName"
    $RecordedBitstream = $Result.bitstream
} else {
    # Program a bitstream that ships with the package, e.g. the one in
    # bitstream/current/. No build database is needed for this.
    $BitstreamPath = (Resolve-Path -LiteralPath $Bitstream).Path
    $ExpectedSha = $BitstreamSha256
    $BuildRecord = ''
    $RecordedBitstream = $BitstreamPath
    $BuildDir = $Root
}
if (-not (Test-Path -LiteralPath $BitstreamPath -PathType Leaf)) { throw "Bitstream missing: $BitstreamPath" }
$ActualSha = (Get-FileHash -LiteralPath $BitstreamPath -Algorithm SHA256).Hash.ToLower()
if ($ExpectedSha -ne '' -and $ActualSha -ne $ExpectedSha.ToLower()) {
    throw "Bitstream hash mismatch: expected $ExpectedSha, got $ActualSha"
}
$Bitstream = $BitstreamPath
$EvidenceDir = Join-Path $Root "evidence/$EvidenceTag"
if (Test-Path -LiteralPath $EvidenceDir) { throw 'Evidence directory already exists; never overwrite a board run' }
$null = New-Item -ItemType Directory -Path $EvidenceDir
if (-not (Test-Path -LiteralPath $PdsShell -PathType Leaf)) { throw 'PdsShell must exist' }
$Programmer = Join-Path (Split-Path $PdsShell) 'cdt_cfg.exe'
$ProgramPath = Join-Path $EvidenceDir 'program.tcl'
$TracePath = (Join-Path $EvidenceDir 'program_trace.txt').Replace('\','/')
$BitstreamTcl = $Bitstream.Replace('\','/')
$Tcl = @"
set sbit {$BitstreamTcl}
set fh [open {$TracePath} w]
puts `$fh "sbit = `$sbit"
puts `$fh "exists = [file exists `$sbit]"
flush `$fh
if {[catch {cfg_scan_chain} m]} {puts `$fh "scan ERR: `$m"} else {puts `$fh "scan OK: `$m"}
flush `$fh
if {[catch {cfg_assign_file -file `$sbit} m]} {puts `$fh "assign ERR: `$m"} else {puts `$fh "assign OK: `$m"}
flush `$fh
if {[catch {cfg_program} m]} {puts `$fh "program ERR: `$m"} else {puts `$fh "program OK: `$m"}
flush `$fh
if {[catch {cfg_scan_chain} m]} {puts `$fh "scan2 ERR: `$m"} else {puts `$fh "scan2 OK: `$m"}
if {[catch {cfg_read_device_property -mode 0} m]} {puts `$fh "id ERR: `$m"} else {puts `$fh "id OK: `$m"}
puts `$fh "PROGRAM_DONE"
close `$fh
"@
[IO.File]::WriteAllText($ProgramPath,$Tcl,[Text.UTF8Encoding]::new($false))
$Port = [IO.Ports.SerialPort]::new($SerialPort,115200,[IO.Ports.Parity]::None,8,[IO.Ports.StopBits]::One)
$Port.ReadTimeout = 200
$Port.DtrEnable = $false
$Port.RtsEnable = $false
$OldJtagPort = $env:PANGO_JTAG_PORT
$Capture = [Text.StringBuilder]::new()
$Stopwatch = [Diagnostics.Stopwatch]::StartNew()
$Process = $null
try {
    $Port.Open()
    $Port.DiscardInBuffer()
    $env:PANGO_JTAG_PORT = "$JtagPort"
    $Process = Start-Process -FilePath $Programmer -ArgumentList @('-file',('"' + $ProgramPath + '"'),'-ip','127.0.0.1','-port',"$JtagPort") -WorkingDirectory $BuildDir -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $EvidenceDir 'program_stdout.log') -RedirectStandardError (Join-Path $EvidenceDir 'program_stderr.log')
    while ($Stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        $Chunk = $Port.ReadExisting()
        if ($Chunk.Length -gt 0) {
            $null = $Capture.Append($Chunk)
            [IO.File]::WriteAllText((Join-Path $EvidenceDir 'uart.log'),$Capture.ToString(),[Text.UTF8Encoding]::new($false))
        }
        $TraceComplete = (Test-Path -LiteralPath (Join-Path $EvidenceDir 'program_trace.txt')) -and ((Get-Content (Join-Path $EvidenceDir 'program_trace.txt') -Raw) -match '(?m)^PROGRAM_DONE\r?$')
        if ($Capture.ToString() -match '(?m)^BENCH_DONE\r?\n' -and $TraceComplete) { break }
        Start-Sleep -Milliseconds 80
    }
    $Trace = Get-Content (Join-Path $EvidenceDir 'program_trace.txt') -Raw
    if ($Trace -notmatch '(?m)^program OK: 1\r?$' -or $Trace -notmatch '(?im)^id OK:\s*(?:0x)?00602899\s*$') { throw 'Programming success/device ID gate failed' }
    if ($Capture.ToString() -notmatch '(?m)^BENCH_DONE\r?\n') { throw 'No completed board benchmark' }
    $ClientClosedAfterSuccess = $false
    if (-not $Process.HasExited) {
        # cdt_cfg remains an interactive client after its Tcl file completes.
        # Close only this helper after PROGRAM_DONE and BENCH_DONE; keep the
        # persistent cdt_js JTAG server and running FPGA untouched.
        $Process.Kill()
        $Process.WaitForExit()
        $ClientClosedAfterSuccess = $true
    } elseif ($Process.ExitCode -ne 0) { throw "Programmer exit code $($Process.ExitCode)" }
    $Metadata = [ordered]@{
        build = $BuildRecord
        bitstream = $RecordedBitstream
        bitstream_sha256 = $ActualSha
        serial_port = $SerialPort
        baud = 115200
        jtag_port = $JtagPort
        jtag_id = '0x00602899'
        program_ok = $true
        client_closed_after_explicit_success = $ClientClosedAfterSuccess
        captured_at = [DateTimeOffset]::Now.ToString('o')
        capture_wall_seconds = $Stopwatch.Elapsed.TotalSeconds
        program_mode = 'Reference cfg_assign_file/cfg_program flow; SRAM configuration'
    }
    [IO.File]::WriteAllText((Join-Path $EvidenceDir 'board_capture.json'),($Metadata | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
    Write-Output "BOARD_CAPTURE_COMPLETE $EvidenceDir"
    Write-Output $Capture.ToString()
} finally {
    if ($null -ne $Process -and -not $Process.HasExited) { $Process.Kill(); $Process.WaitForExit() }
    if ($Port.IsOpen) { $Port.Close() }
    $Port.Dispose()
    if ($null -eq $OldJtagPort) { Remove-Item Env:PANGO_JTAG_PORT -ErrorAction SilentlyContinue } else { $env:PANGO_JTAG_PORT = $OldJtagPort }
    [IO.File]::WriteAllText((Join-Path $EvidenceDir 'uart.log'),$Capture.ToString(),[Text.UTF8Encoding]::new($false))
}
