param(
  [Parameter(Mandatory = $true)][string]$Action,
  [string]$A = '',
  [string]$B = '',
  [string]$C = '',
  [string]$D = ''
)
# 手机 ADA-AL00U（USB）操作小工具：shot/tap/swipe/start/stop/log/dump/install
# 用法：
#   pwsh tools/phone.ps1 shot docs/shots/1734_xxx.png
#   pwsh tools/phone.ps1 tap 612 1857
#   pwsh tools/phone.ps1 swipe 1000 1800 200 1800 500
#   pwsh tools/phone.ps1 start
#   pwsh tools/phone.ps1 log MainScreen
$hdc = 'G:\DevEco Studio 26\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$t = '2UCUT24724009680'
$bundle = 'com.dlzz.carriagereturn'

switch ($Action) {
  'shot' {
    $remote = '/data/local/tmp/_shot.jpeg'
    & $hdc -t $t shell "snapshot_display -f $remote" | Out-Null
    $tmp = [System.IO.Path]::ChangeExtension($A, '.capture.jpeg')
    & $hdc -t $t file recv "$remote" $tmp | Out-Null
    if (Test-Path $tmp) {
      & python -c "from PIL import Image; im=Image.open(r'$tmp'); im.save(r'$A')"
      Remove-Item $tmp -Force
      Write-Output "shot -> $A"
    } else { Write-Output "shot FAILED -> $A" }
  }
  'tap' { & $hdc -t $t shell "uitest uiInput click $A $B" | Out-Null; Write-Output "tap $A $B" }
  'swipe' { & $hdc -t $t shell "uitest uiInput swipe $A $B $C $D" | Out-Null; Write-Output "swipe $A $B $C $D" }
  'start' {
    & $hdc -t $t shell "aa force-stop $bundle" | Out-Null
    Start-Sleep -Milliseconds 600
    & $hdc -t $t shell "aa start -a EntryAbility -b $bundle" | Out-Null
    Start-Sleep -Seconds 6
    Write-Output 'started'
  }
  'stop' { & $hdc -t $t shell "aa force-stop $bundle" | Out-Null; Write-Output 'stopped' }
  'log' {
    & $hdc -t $t shell "hilog -x" 2>&1 | Select-String -Pattern $A | Select-Object -Last 40 | ForEach-Object { $_.Line }
  }
  'dump' {
    & $hdc -t $t shell "uitest dumpLayout -p /data/local/tmp/_dump.json" | Out-Null
    & $hdc -t $t file recv /data/local/tmp/_dump.json $A | Out-Null
    Write-Output "dump -> $A"
  }
  'install' { & $hdc -t $t install -r $A }
  'on' { & $hdc -t $t shell "power-shell timeout -o 3600000" | Out-Null; & $hdc -t $t shell "power-shell wakeup" | Out-Null; Write-Output 'awake' }
  default { Write-Output "unknown action: $Action" }
}
