:: should be used like this: 
:: 1. run ./crypto-erase.bat
:: 2. script enumerates all drives and asks for the drive(s) to erase
:: 3. for each drive selected, run the diskpart series of commands, either via diskpart script or manual entry
:: 4. for each drive selected, use `manage-bde.exe` to enable bitlocker with a random password each
:: 5. for each drive, spin until the drive is fully encrypted
:: 5.5 perhaps list percentages of encryption progress periodically. say a drive is done encrypting or fully done wiping as needed.
:: 6. once a drive is done, rerun the diskpart series of commands to wipe the drive

@echo off
setlocal enabledelayedexpansion

:::::::::::::::::::::::::::::::::::::
:: random password maker
:generate_password
set "length=16"
set "charset=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
set "password="

for /L %%i in (1,1,%length%) do (
    set /a "randIndex=!random! %% 62"
    set "password=!password!!charset:~!randIndex!,1!"
)
set "generated_password=!password!"
exit /b
:::::::::::::::::::::::::::::::::::::


:: Call the function
call :generate_password

:: Display the generated password
echo Generated Password: %generated_password%
