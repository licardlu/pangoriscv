# Capture the board's UART output to a text file (no third-party modules:
# uses System.IO.Ports, which ships with Windows PowerShell).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File capture_uart.ps1 `
#       -Port COM13 -Seconds 40 -Out .\uart_capture.txt
#
# 115200 8N1 is what the delivered firmware configures (CPU_FREQ_MHZ=27,
# BAUD_DIV=234 -> 27e6/(234+1)/16 = 115200 approximately).
#
# IMPORTANT: "captured 0 chars" does NOT mean the design is silent. The CoreMark
# image prints its whole report ONCE, ~10.7 s after configuration, and start.S
# then spins forever (see docs/lessons/mistakes-log.md 7.6). This capture must be
# running BEFORE the FPGA is programmed -- use flash_and_capture.ps1, which starts
# this script first, then flashes.
param(
  [string]$Port = 'COM13',
  [int]$Baud = 115200,
  [int]$Seconds = 40,
  [string]$Out = 'uart_capture.txt'
)
$ErrorActionPreference = 'Stop'
$sp = New-Object System.IO.Ports.SerialPort $Port, $Baud, 'None', 8, 'One'
$sp.ReadTimeout = 1000
$sp.DtrEnable = $false
$sp.RtsEnable = $false
$sb = New-Object System.Text.StringBuilder
try {
  $sp.Open()
} catch {
  Write-Host "FAILED to open $Port : $($_.Exception.Message)"
  exit 2
}
Write-Host "opened $Port @ $Baud for $Seconds s ..."
$deadline = (Get-Date).AddSeconds($Seconds)
$buffer = New-Object byte[] 4096
while ((Get-Date) -lt $deadline) {
  try {
    $n = $sp.Read($buffer, 0, $buffer.Length)
    if ($n -gt 0) {
      [void]$sb.Append([System.Text.Encoding]::ASCII.GetString($buffer, 0, $n))
      Write-Host -NoNewline ([System.Text.Encoding]::ASCII.GetString($buffer, 0, $n))
    }
  } catch [System.TimeoutException] {
    # no bytes this second: keep waiting
  } catch {
    Write-Host "`nread error: $($_.Exception.Message)"
    break
  }
}
try { $sp.Close() } catch {}
$text = $sb.ToString()
Set-Content -Path $Out -Value $text -Encoding ASCII
$bytes = [System.Text.Encoding]::ASCII.GetByteCount($text)
$sha = (Get-FileHash -Path $Out -Algorithm SHA256).Hash
Write-Host ""
Write-Host ("captured {0} chars / {1} bytes -> {2}" -f $text.Length, $bytes, $Out)
Write-Host "sha256 = $sha"
if ($text -match 'Correct operation validated') { Write-Host "REPORT: Correct operation validated PRESENT" }
if ($text -match 'Errors detected')            { Write-Host "REPORT: Errors detected PRESENT" }
if ($text -match 'Total ticks\s*:\s*(\d+)')    { Write-Host "REPORT: Total ticks = $($Matches[1])" }
