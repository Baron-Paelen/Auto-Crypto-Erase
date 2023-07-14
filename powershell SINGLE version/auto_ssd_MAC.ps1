param (
    # [Parameter(Mandatory = $true)]
    # [ValidateNotNullOrEmpty()]
    # [string]$DriveLetter,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DiskNumber
)

# check if drive exists
# $exists = Test-Path -LiteralPath "${DriveLetter}:\"
# if (-not $exists) {
#     Write-Host "`nDrive $DriveLetter does not exist!" -ForegroundColor Red
#     exit
# }
# Write-Host "`nDrive $DriveLetter found!" -ForegroundColor Green


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

# diskpart script
$dpscript = @"
list disk
select disk $DiskNumber
clean
create partition primary
active
format fs=ntfs quick
assign letter Z
"@

# write this to a file to run as a diskpart script
$dpscript | Out-File -FilePath "dpscriptwowow.txt" -Encoding ascii

# run the dp script
diskpart /s "dpscriptwowow.txt"
Write-Host "`nDiskpart commands completed successfully!" -ForegroundColor Green
Remove-Item -Path "dpscriptwowow.txt"

# enable bitlocker on DriveLetter
$pw = Gen-PW
$blres = Enable-BitLocker -MountPoint Z -EncryptionMethod Aes256 -PasswordProtector -Password $(ConvertTo-SecureString -String "$pw" -AsPlainText -Force) #-UsedSpaceOnly
if ($blres) {
    Write-Host "`nBitlocker started successfully!" -ForegroundColor Green
} else {
    Write-Host "`nBitlocker failed to start! Exiting..." -ForegroundColor Red -BackgroundColor Black
    exit
}

# checking if encryption is done yet
$encrypted = $false
while (-not $encrypted) {
    $info = Get-BitLockerVolume -MountPoint Z -ErrorAction SilentlyContinue

    if ($info.VolumeStatus -eq "FullyEncrypted") {
        $encrypted = $true
    } else {
        $percent = $info.EncryptionPercentage
        Write-Host "`nDrive Z encryption at $percent%..." -ForegroundColor Yellow
        Start-Sleep -Seconds 20
    }
}

Write-Host "`nDrive Z finished encrypting!" -ForegroundColor Green


# format again
# copy pasted from above
$dpscript = @"
list disk
select disk $DiskNumber
clean
create partition primary
active
format fs=ntfs quick
assign letter Z
"@

$dpscript | Out-File -FilePath "dpscriptwowow.txt" -Encoding ascii

diskpart /s "dpscriptwowow.txt"
Write-Host "`nDiskpart commands completed successfully!" -ForegroundColor Green
Remove-Item -Path "dpscriptwowow.txt"

Write-Host "`nDrive !" -ForegroundColor Green
