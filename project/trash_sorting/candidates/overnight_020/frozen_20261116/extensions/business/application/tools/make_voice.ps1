param([string]$Voice='Microsoft Huihui Desktop',[switch]$CategoriesOnly)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Speech
$root=Split-Path $PSScriptRoot -Parent
$dir=Join-Path $root 'assets/audio'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$s=New-Object System.Speech.Synthesis.SpeechSynthesizer
$s.SelectVoice($Voice)
$format=New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(48000,[System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,[System.Speech.AudioFormat.AudioChannel]::Mono)
$lines=@{
 'PROMPT.WAV'='请选择垃圾桶。'
 'CORRECT.WAV'='恭喜你，答对了！'
 'WRONG.WAV'='哎呀，答错了。'
 'TIMEOUT.WAV'='选择超时，请移走垃圾后重试。'
 'KITCHEN.WAV'='这是厨余垃圾。'
 'HAZARDOUS.WAV'='这是有害垃圾。'
 'OTHER.WAV'='这是其他垃圾。'
 'RECYCLABLE.WAV'='这是可回收垃圾。'
}
foreach($name in $lines.Keys){
 $category=$name -in @('KITCHEN.WAV','HAZARDOUS.WAV','OTHER.WAV','RECYCLABLE.WAV')
 if($CategoriesOnly -and -not $category){continue}
 $s.Rate=0;if($category){$s.Rate=1}
 $s.SetOutputToWaveFile((Join-Path $dir $name),$format);$s.Speak($lines[$name]);$s.SetOutputToNull()
}
$s.Dispose()
Write-Output 'VOICE_ASSETS_PASS 48kHz mono PCM16; local installed system voice, see THIRD_PARTY_NOTICES.md'
