# generate random pw
function Gen-PW {
    $chars = "qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890!@#$%^&*()-=_+<>?,.[]"
    $pw = ""
    $rand = New-Object System.Random

    for ($i = 0; $i -lt 25; $i++) {
        $pw += $chars[$rand.Next(0, $chars.Length)]
    }

    # Write-Host "Password is: $pw" -ForegroundColor Green
    return $pw
}

# get all drives
$drives = Get-WmiObject -Class Win32_Volume | Where-Object {$_.DriveLetter -ne $null -and $_.DriveLetter -ne "C:" -and $_.DriveLetter -ne "X:" -and $_.DriveLetter -ne "Y:" -and $_.DriveLetter -ne "Z:"} | Select-Object -ExpandProperty DriveLetter
for ($i = 0; $i -lt $drives.Length; $i++) {
    manage-bde -protectors -delete $drives[$i]
}
$drives = $drives.replace(":", "")

# $lenny = $drives.Length
# Write-Host "len drives $lenny"
# exit

# iterate over drives. $i will be the number used in diskpart
for ($i=1; $i -le $drives.Length; $i++) {
    # current drive letter
    $curdrive = $drives[$i-1]
    Write-Host "`nNow on Drive $curdrive!" -ForegroundColor Green

    # diskpart script for $i and $curdrive
    $dpscript = @"
    list disk
    select disk $i
    clean
    create partition primary
    active
    format fs=ntfs quick
    assign letter $curdrive
"@

    # write this to a file to run as a diskpart script
    $dpscript | Out-File -FilePath "dpscriptwowow.txt" -Encoding ascii

    # run the dp script and then clean it up
    diskpart /s "dpscriptwowow.txt"
    Write-Host "`nDiskpart commands for drive $curdrive completed successfully!" -ForegroundColor Green
    Remove-Item -Path "dpscriptwowow.txt"

    # enable bitlocker on $curdrive
    $pw = Gen-PW
    $blres = Enable-BitLocker -MountPoint $curdrive -EncryptionMethod Aes256 -PasswordProtector -Password $(ConvertTo-SecureString -String "$pw" -AsPlainText -Force) #-UsedSpaceOnly
    if ($blres) {
        Write-Host "`nBitlocker started successfully on drive $curdrive!" -ForegroundColor Green
    } else {
        Write-Host "`nBitlocker failed to start on drive $curdrive! Exiting..." -ForegroundColor Red -BackgroundColor Black
        exit
    }
}

# iterate over all the drives again to check if they're done
$drivesremaining = $drives.Length
while ($drivesremaining -gt 0) {

    # print drive progress
    for ($i=1; $i -le $drives.Length; $i++) {
        $curdrive = $drives[$i-1]
        
        # get drive progress
        $info = Get-BitLockerVolume -MountPoint $curdrive -ErrorAction SilentlyContinue
        if ($info.VolumeStatus -eq "FullyEncrypted") { # if a drive is encrypted, decrement $drivesremaining
            $drivesremaining--
        } else {
            $percent = $info.EncryptionPercentage
            Write-Host "`n`tDrive $curdrive encryption at $percent%..." -ForegroundColor Yellow
        }
    }

    Start-Sleep -Seconds 20
    
    # spacing
    Write-Host "`n`n`n"
}

Write-Host "All drives encrypted!`n`n`n" -ForegroundColor Green

# using diskpart to format the drives again
for ($i=1; $i -le $drives.Length; $i++) {
    # current drive letter
    $curdrive = $drives[$i-1]
    Write-Host "`nNow formatting Drive $curdrive!" -ForegroundColor Green

    # diskpart script for $i and $curdrive
    $dpscript = @"
    list disk
    select disk $i
    clean
    create partition primary
    active
    format fs=ntfs quick
    assign letter $curdrive
"@

    # write this to a file to run as a diskpart script
    $dpscript | Out-File -FilePath "dpscriptwowow.txt" -Encoding ascii

    # run the dp script and then clean it up
    diskpart /s "dpscriptwowow.txt"
    Write-Host "`nDrive $curdrive formatted successfully!" -ForegroundColor Green
    Remove-Item -Path "dpscriptwowow.txt"
}