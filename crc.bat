@echo off
setlocal EnableExtensions

set "SREC=C:\Program Files\srecord\bin\srec_cat.exe"
set "OBJCOPY="

if /I "%~1" NEQ "--version" goto :usage
if "%~2"=="" goto :usage
if /I "%~3" NEQ "--build" goto :usage
if "%~4"=="" goto :usage

if /I "%~5"=="--objcopy" (
    if "%~6"=="" goto :usage
    set "OBJCOPY=%~6"
    if NOT "%~7"=="" goto :usage
) else if NOT "%~5"=="" (
    goto :usage
)

if /I "%~4"=="R" (
    set "BUILD=Release"
) else if /I "%~4"=="D" (
    set "BUILD=Debug"
) else (
    goto :usage
)

set "VERSION=%~2"
set "VERSION_NUM=%version:.=%"

set "fw_path=build\RA6T2-%BUILD%\ra6t2_build"
set "in_file=%fw_path%\RA6T2.hex"
set "in_elf=%fw_path%\RA6T2.elf"
set "out_path=%fw_path%\FW"
set "bin_file=%out_path%\Corrv%VERSION_NUM%.bin"
set "out_file=%out_path%\Corrv%VERSION_NUM%.hex"
set "out_elf=%out_path%\RA6T2.crc.elf"
set "tmp_hex=%out_path%\tmp_base.hex"
set "tmp_meta=%out_path%\tmp_meta.bin"

if not exist "%out_path%" mkdir "%out_path%"

if not exist "%SREC%" (
    echo srec_cat no encontrado en "%SREC%"
    exit /B 1
)

if not exist "%in_file%" (
    echo No existe "%in_file%"
    exit /B 1
)

if not exist "%in_elf%" (
    echo No existe "%in_elf%"
    exit /B 1
)

if defined OBJCOPY (
    if not exist "%OBJCOPY%" (
        echo objcopy no encontrado en "%OBJCOPY%"
        exit /B 1
    )
)

REM ============================================================
REM Imagen absoluta:
REM 0xE000..0xE003 = CRC provisional
REM 0xE004..0xE007 = ultima direccion: 0x0003FFFF
REM 0xE008..0x3FFFF = metadata restante + firmware
REM ============================================================

"%SREC%" -disable-sequence-warning ^
  "(" "%in_file%" -intel -fill 0xFF 0x00000 0x40000 -crop 0x0E008 0x40000 ")" ^
  -generate 0x0E000 0x0E004 -constant-l-e 0x00000000 4 ^
  -generate 0x0E004 0x0E008 -constant-l-e 0x0003FFFF 4 ^
  -output "%tmp_hex%" -intel

if errorlevel 1 exit /B 1

REM Convertir a BIN. Ahora el offset se aplica solo despues de tener la imagen absoluta correcta.
"%SREC%" "%tmp_hex%" -intel ^
  -crop 0x0E000 0x40000 ^
  -offset -0x0E000 ^
  -output "%bin_file%" -binary

if errorlevel 1 exit /B 1

REM Calcular CRC igual que el bootloader:
REM crc inicial = 0xFFFFFFFF
REM rango       = bin[0x0004..final]
REM metadata    = ~crc, little-endian en bin[0x0000..0x0003]
set "BIN_FILE=%bin_file%"
set "META_FILE=%tmp_meta%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p=$env:BIN_FILE;" ^
  "$m=$env:META_FILE;" ^
  "$d=[IO.File]::ReadAllBytes($p);" ^
  "if($d.Length -ne 0x32000){throw ('Tamano BIN incorrecto: 0x{0:X}' -f $d.Length)}" ^
  "$last=([int64]$d[4]) -bor (([int64]$d[5]) -shl 8) -bor (([int64]$d[6]) -shl 16) -bor (([int64]$d[7]) -shl 24);" ^
  "if($last -ne 0x3FFFF){throw ('Campo 0xE004 incorrecto: 0x{0:X8}' -f $last)}" ^
  "$mask=[int64]4294967295;" ^
  "$poly=[int64]3988292384;" ^
  "$crc=$mask;" ^
  "for($i=4;$i -lt $d.Length;$i++){" ^
  "  $crc=($crc -bxor [int64]$d[$i]) -band $mask;" ^
  "  for($j=0;$j -lt 8;$j++){" ^
  "    if(($crc -band 1) -ne 0){$crc=(($crc -shr 1) -bxor $poly) -band $mask}else{$crc=($crc -shr 1) -band $mask}" ^
  "  }" ^
  "}" ^
  "$crcInv=(-bnot $crc) -band $mask;" ^
  "$d[0]=[byte]($crcInv -band 255);" ^
  "$d[1]=[byte](($crcInv -shr 8) -band 255);" ^
  "$d[2]=[byte](($crcInv -shr 16) -band 255);" ^
  "$d[3]=[byte](($crcInv -shr 24) -band 255);" ^
  "[IO.File]::WriteAllBytes($p,$d);" ^
  "[IO.File]::WriteAllBytes($m,[byte[]]$d[0..511]);" ^
  "Write-Host ('CRC interno = 0x{0:X8}' -f $crc);" ^
  "Write-Host ('CRC final   = 0x{0:X8} / {1}' -f $crcInv,$crcInv);"

if errorlevel 1 exit /B 1

REM Regenerar HEX final desde el BIN parcheado.
"%SREC%" "%bin_file%" -binary ^
  -offset 0x0E000 ^
  -output "%out_file%" -intel

if errorlevel 1 exit /B 1

if defined OBJCOPY (
    "%OBJCOPY%" --update-section .META_DATA="%tmp_meta%" "%in_elf%" "%out_elf%"
    if errorlevel 1 exit /B 1
)

del "%tmp_hex%" >nul 2>nul
del "%tmp_meta%" >nul 2>nul

echo OK
echo HEX: "%out_file%"
echo BIN: "%bin_file%"
if defined OBJCOPY echo ELF: "%out_elf%"
exit /B 0

endlocal

:usage
echo Uso: crc.bat --version "1.0.0.0" --build R/D [--objcopy "ruta\arm-none-eabi-objcopy.exe"]
exit /B 1
