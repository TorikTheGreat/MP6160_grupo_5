@echo off
setlocal
REM Script de simulacion UVM - Rol C (MP6160 EC4)
REM Compila, elabora y corre axi4_directed_test y axi4_random_test.

REM ---- 1. Cargar entorno Vivado ----
if exist "C:\Xilinx\Vivado\2024.1\settings64.bat" (
    call "C:\Xilinx\Vivado\2024.1\settings64.bat"
) else if exist "C:\Vivado\2024.1\settings64.bat" (
    call "C:\Vivado\2024.1\settings64.bat"
) else (
    echo No se encontro Vivado 2024.1. Edita este script con la ruta correcta.
    exit /b 1
)

REM ---- 2. Ir a la raiz del repo (este script vive en tb\uvm\) ----
cd /d "%~dp0..\.."

REM ---- 3. Compilar ----
echo === xvlog ===
xvlog -sv -L uvm -i tb/uvm -f tb/uvm/filelist_uvm.f
if errorlevel 1 (
    echo FALLO xvlog. Revisa el log arriba.
    exit /b 1
)

REM ---- 4. Elaborar ----
echo === xelab ===
xelab -L uvm -timescale 1ns/1ps work.tb_top_rolC -s rolC_snapshot
if errorlevel 1 (
    echo FALLO xelab. Revisa el log arriba.
    exit /b 1
)

REM ---- 5. Correr cada test como proceso Vivado independiente ----
REM (xsim con -testplusarg tiene un bug de parseo si se reusa una sesion
REM  de shell ya usada; invocar via 'vivado -mode batch' evita el problema
REM  porque cada llamada arranca un proceso Vivado fresco.)
echo === axi4_directed_test ===
vivado -mode batch -source tb\uvm\run_directed.tcl -nolog -nojournal

echo === axi4_random_test ===
vivado -mode batch -source tb\uvm\run_random.tcl -nolog -nojournal

echo.
echo === Listo ===
echo Logs generados: directed_test.log, random_test.log (en la raiz del repo)
echo Nota: los UVM_ERROR de mismatch de datos son esperados mientras el DUT
echo sea el dummy_slave (sin memoria real). Ver tb\uvm\REPORTE_VERIFICACION.md
endlocal