# should be used like this: 
# 1. run ./crypto-erase.ps1
# 2. script enumerates all drives and asks for the drive(s) to erase
# 3. for each drive selected, run the diskpart series of commands, either via diskpart script or manual entry
# 4. for each drive selected, use `manage-bde.exe` to enable bitlocker with a random password each
# 5. for each drive, spin until the drive is fully encrypted
# 5.5 perhaps list percentages of encryption progress periodically. say a drive is done encrypting or fully done wiping as needed.
# 6. once a drive is done, rerun the diskpart series of commands to wipe the drive

function New-RandomPassword {
    [CmdletBinding()]
    [OutputType([string])]
    Param(
        [int]$Length = 16,
        [switch]$IncludeSpecialChars
    )
    
    # Define character sets
    $Uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    $Lowercase = 'abcdefghijklmnopqrstuvwxyz'
    $Numbers = '0123456789'
    $Special = '!@#$%^&*()_+-=[]{}|;:,.<>?'
    
    # Combine character sets based on parameters
    $CharSet = $Uppercase + $Lowercase + $Numbers
    if ($IncludeSpecialChars) {
        $CharSet += $Special
    }
    
    # Ensure we have at least one of each required character type
    $Password = @()
    $Password += $Uppercase[(Get-Random -Maximum $Uppercase.Length)]
    $Password += $Lowercase[(Get-Random -Maximum $Lowercase.Length)]
    $Password += $Numbers[(Get-Random -Maximum $Numbers.Length)]
    
    # Fill the rest with random characters
    for ($i = $Password.Count; $i -lt $Length; $i++) {
        $Password += $CharSet[(Get-Random -Maximum $CharSet.Length)]
    }
    
    # Shuffle the password array
    $Password = $Password | Sort-Object {Get-Random}
    
    # Return the password as a string
    return -join $Password
}

# echo "Generating random password..."
# $Password = New-RandomPassword -Length 25 -IncludeSpecialChars
# echo "Password is: $Password"

# enumerate all disks and their associated drive letters
function Get-DiskInformation {
    [CmdletBinding()]
    param()
    
    try {
        # Get disk information using Get-WmiObject
        $disks = Get-WmiObject -Class Win32_LogicalDisk | Select-Object @{
            Name = 'DriveLetter'
            Expression = {$_.DeviceID}
        },
        @{
            Name = 'DriveType'
            Expression = {
                switch($_.DriveType) {
                    0 {'Unknown'}
                    1 {'No Root Directory'}
                    2 {'Removable Disk'}
                    3 {'Local Disk'}
                    4 {'Network Drive'}
                    5 {'Compact Disc'}
                    6 {'RAM Disk'}
                    default {'Unspecified'}
                }
            }
        },
        @{
            Name = 'SizeGB'
            Expression = {[math]::Round($_.Size / 1GB, 2)}
        },
        @{
            Name = 'FreeSpaceGB'
            Expression = {[math]::Round($_.FreeSpace / 1GB, 2)}
        },
        @{
            Name = 'UsedSpaceGB'
            Expression = {[math]::Round(($_.Size - $_.FreeSpace) / 1GB, 2)}
        },
        @{
            Name = 'PercentFree'
            Expression = {
                if ($_.Size -gt 0) {
                    [math]::Round(($_.FreeSpace / $_.Size) * 100, 1)
                } else {
                    0
                }
            }
        },
        @{
            Name = 'VolumeName'
            Expression = {$_.VolumeName}
        }

        # Add error handling for no disks found
        if ($null -eq $disks) {
            Write-Warning "No disks were found on this system."
            return $null
        }

        # Format and return the results
        return $disks | Sort-Object DriveLetter
    }
    catch {
        Write-Error "An error occurred while retrieving disk information: $_"
        return $null
    }
}

# Add an example function to format the output as a nice table
# function Show-DiskInformation {
#     [CmdletBinding()]
#     param()
    
#     $diskInfo = Get-DiskInformation
    
#     if ($null -ne $diskInfo) {
#         Write-Host "`nDisk Information Summary:" -ForegroundColor Cyan
#         Write-Host "========================" -ForegroundColor Cyan
        
#         $diskInfo | ForEach-Object {
#             Write-Host "`nDrive $($_.DriveLetter) ($($_.DriveType))" -ForegroundColor Yellow
#             if ($_.VolumeName) {
#                 Write-Host "Volume Name: $($_.VolumeName)"
#             }
#             Write-Host "Total Size: $($_.SizeGB) GB"
#             Write-Host "Used Space: $($_.UsedSpaceGB) GB"
#             Write-Host "Free Space: $($_.FreeSpaceGB) GB"
#             Write-Host "Percent Free: $($_.PercentFree)%"
            
#             # Add warning for low disk space
#             if ($_.PercentFree -lt 10) {
#                 Write-Host "WARNING: Low disk space!" -ForegroundColor Red
#             }
#         }
#     }
# }

function Get-DiskSelection {
    [CmdletBinding()]
    param()
    
    try {
        # Get physical disks and volumes
        $physicalDisks = Get-PhysicalDisk | Sort-Object DeviceId
        $volumes = Get-Volume | Where-Object DriveLetter
        $partitions = Get-Partition | Where-Object DriveLetter
        
        # Create array to store disk information
        $script:diskInfoArray = @()
        
        # Display header
        Write-Host "`nAvailable Disks:" -ForegroundColor Cyan
        Write-Host "================`n" -ForegroundColor Cyan
        
        # Process each disk
        foreach ($disk in $physicalDisks) {
            # Get associated partitions and drive letters for this disk
            $diskPartitions = $partitions | Where-Object DiskNumber -eq $disk.DeviceId
            $driveLetters = ($diskPartitions | ForEach-Object { $_.DriveLetter }) -join ', '
            
            # Calculate total capacity
            $totalCapacity = 0
            foreach ($partition in $diskPartitions) {
                $volume = $volumes | Where-Object DriveLetter -eq $partition.DriveLetter
                if ($volume) {
                    $totalCapacity += $volume.Size
                }
            }
            
            # Create disk info object
            $diskInfo = [PSCustomObject]@{
                DiskNumber = $disk.DeviceId
                FriendlyName = $disk.FriendlyName
                DriveLetters = $driveLetters
                CapacityGB = [math]::Round($totalCapacity / 1GB, 2)
            }
            
            # Add to array
            $script:diskInfoArray += $diskInfo
            
            # Display disk information
            Write-Host "Disk $($disk.DeviceId):" -ForegroundColor Yellow
            Write-Host "  Name: $($disk.FriendlyName)"
            Write-Host "  Drive Letters: $driveLetters"
            Write-Host "  Capacity: $([math]::Round($totalCapacity / 1GB, 2)) GB`n"
        }
        
        # Prompt for selection
        Write-Host "Enter disk number(s) to select (comma-separated), or 'q' to quit:" -ForegroundColor Green
        $selection = Read-Host
        
        if ($selection -eq 'q') {
            return $null
        }
        
        # Process selection
        $selectedNumbers = $selection -split ',' | ForEach-Object { $_.Trim() }
        $selectedDisks = $script:diskInfoArray | Where-Object { $selectedNumbers -contains $_.DiskNumber }
        
        if ($selectedDisks) {
            return $selectedDisks
        } else {
            Write-Warning "No valid disk(s) selected."
            return $null
        }
    }
    catch {
        Write-Error "An error occurred while processing disk information: $_"
        return $null
    }
}

function Show-StoredDiskInfo {
    if ($script:diskInfoArray) {
        Write-Host "`nStored Disk Information:" -ForegroundColor Cyan
        Write-Host "======================`n" -ForegroundColor Cyan
        
        foreach ($disk in $script:diskInfoArray) {
            Write-Host "Disk $($disk.DiskNumber):" -ForegroundColor Yellow
            Write-Host "  Name: $($disk.FriendlyName)"
            Write-Host "  Drive Letters: $($disk.DriveLetters)"
            Write-Host "  Capacity: $($disk.CapacityGB) GB`n"
        }
    } else {
        Write-Warning "No disk information stored. Please run Get-DiskSelection first."
    }
}



# Get disk information and make a selection
$selectedDisks = Get-DiskSelection

Write-Host "`nSelected Disk(s):" -ForegroundColor Cyan
Write-Host "==================`n" -ForegroundColor Cyan
foreach ($disk in $script:selectedDisks) {
            Write-Host "Disk $($disk.DiskNumber):" -ForegroundColor Yellow
            Write-Host "  Name: $($disk.FriendlyName)"
            Write-Host "  Drive Letters: $($disk.DriveLetters)"
            Write-Host "  Capacity: $($disk.CapacityGB) GB`n"
        }

# # Show all stored disk information again at any time
# Show-StoredDiskInfo

# # Access the stored array directly if needed
# $script:diskInfoArray

# # Filter stored information
# $script:diskInfoArray | Where-Object { $_.CapacityGB -gt 100 }

$Password = New-RandomPassword -Length 25 -IncludeSpecialChars

$SecureString = ConvertTo-SecureString $Password -AsPlainText -Force
Enable-BitLocker -MountPoint "D:" -EncryptionMethod Aes256 -UsedSpaceOnly -Pin $SecureString -TPMandPinProtector