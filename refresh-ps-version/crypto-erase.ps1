# should be used like this: 
# 1. run ./crypto-erase.ps1
# 2. script enumerates all drives and asks for the drive(s) to erase
# 3. for each drive selected, clean the drive, initialize it, format it, and assign a drive letter'
#    - refresh drive letters per disk by disk number bc formatting may change them
# 4. for each drive selected, use powershell cmdlets to enable bitlocker with a random password each
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

function Get-DiskInfo {
    [CmdletBinding()]
    param()
    
    try {
        # Get physical disks and volumes
        $physicalDisks = Get-PhysicalDisk | Sort-Object DeviceId
        $volumes = Get-Volume | Where-Object DriveLetter
        $partitions = Get-Partition | Where-Object DriveLetter
        
        # Create array to store disk information
        $diskInfoArray = @()
        
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
            
            # Create and add disk info object
            $diskInfoArray += [PSCustomObject]@{
                DiskNumber = $disk.DeviceId
                FriendlyName = $disk.FriendlyName
                DriveLetters = $driveLetters
                CapacityGB = [math]::Round($totalCapacity / 1GB, 2)
            }
        }

        Write-Host "Disk Info Array: $diskInfoArray"
        
        return $diskInfoArray
    }
    catch {
        Write-Error "An error occurred while gathering disk information: $_"
        return $null
    }
}

function Select-DiskFromList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Array]$DiskList
    )
    
    try {
        # Display header
        Write-Host "`nAvailable Disks:" -ForegroundColor Cyan
        Write-Host "================`n" -ForegroundColor Cyan
        
        # Display disk information
        foreach ($disk in $DiskList) {
            Write-Host "Disk $($disk.DiskNumber):" -ForegroundColor Yellow
            Write-Host "  Name: $($disk.FriendlyName)"
            Write-Host "  Drive Letters: $($disk.DriveLetters)"
            Write-Host "  Capacity: $($disk.CapacityGB) GB`n"
        }
        
        # Prompt for selection
        Write-Host "Enter disk number(s) to select (comma-separated), or 'q' to quit:" -ForegroundColor Green
        $selection = Read-Host
        
        if ($selection -eq 'q') {
            return $null
        }
        
        # Process selection
        $selectedNumbers = $selection -split ',' | ForEach-Object { $_.Trim() }
        $selectedDisks = $DiskList | Where-Object { $selectedNumbers -contains $_.DiskNumber }
        
        if ($selectedDisks) {
            return $selectedDisks
        } else {
            Write-Warning "No valid disk(s) selected."
            return $null
        }
    }
    catch {
        Write-Error "An error occurred during disk selection: $_"
        return $null
    }
}

# Helper function to display disk information
function Show-DiskInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Array]$DiskList
    )
    
    Write-Host "`nDisk Information:" -ForegroundColor Cyan
    Write-Host "================`n" -ForegroundColor Cyan
    
    foreach ($disk in $DiskList) {
        Write-Host "Disk $($disk.DiskNumber):" -ForegroundColor Yellow
        Write-Host "  Name: $($disk.FriendlyName)"
        Write-Host "  Drive Letters: $($disk.DriveLetters)"
        Write-Host "  Capacity: $($disk.CapacityGB) GB`n"
    }
}

function Initialize-NewDisk {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [PSCustomObject[]]$SelectedDisks,
        
        [Parameter(Mandatory=$false)]
        [string]$FileSystem = "NTFS",
        
        [Parameter(Mandatory=$false)]
        [switch]$Force
    )
    
    begin {
        # Function to get the next available drive letter
        function Get-NextAvailableDriveLetter {
            $usedLetters = (Get-Volume).Where{$_.DriveLetter}.DriveLetter
            $alphabet = 67..90 | ForEach-Object { [char]$_ } # C to Z
            $availableLetter = $alphabet | Where-Object { $_ -notin $usedLetters } | Select-Object -First 1
            return $availableLetter
        }
    }
    
    process {
        foreach ($disk in $SelectedDisks) {
            try {
                # Safety check - confirm disk number exists
                $physicalDisk = Get-PhysicalDisk | Where-Object DeviceId -eq $disk.DiskNumber
                if (-not $physicalDisk) {
                    Write-Error "Disk $($disk.DiskNumber) not found!"
                    continue
                }
                
                # Warning and confirmation for data destruction
                if (-not $Force) {
                    Write-Warning "This operation will DESTROY ALL DATA on disk $($disk.DiskNumber) ($($disk.FriendlyName))"
                    Write-Warning "Drive Letters: $($disk.DriveLetters)"
                    Write-Warning "Capacity: $($disk.CapacityGB) GB"
                    
                    $confirmation = Read-Host "Are you sure you want to proceed? (Yes/No)"
                    if ($confirmation -ne "Yes") {
                        Write-Host "Operation cancelled for disk $($disk.DiskNumber)" -ForegroundColor Yellow
                        continue
                    }
                }
                
                if ($PSCmdlet.ShouldProcess("Disk $($disk.DiskNumber)", "Initialize and format disk")) {
                    Write-Host "`nProcessing Disk $($disk.DiskNumber):" -ForegroundColor Cyan
                    
                    # Step 1: Clear/Clean the disk
                    Write-Host "  Cleaning disk..." -ForegroundColor Yellow
                    Clear-Disk -Number $disk.DiskNumber -RemoveData -RemoveOEM -Confirm:$false
                    
                    # Step 2: Initialize the disk
                    Write-Host "  Initializing disk..." -ForegroundColor Yellow
                    Initialize-Disk -Number $disk.DiskNumber -PartitionStyle GPT
                    
                    # Step 3: Get next available drive letter
                    $driveLetter = Get-NextAvailableDriveLetter
                    if (-not $driveLetter) {
                        throw "No available drive letters found!"
                    }
                    
                    # Step 4: Create partition, format it, and assign drive letter
                    Write-Host "  Creating partition and formatting..." -ForegroundColor Yellow
                    $partition = New-Partition -DiskNumber $disk.DiskNumber -UseMaximumSize -AssignDriveLetter
                    
                    Write-Host "  Formatting volume..." -ForegroundColor Yellow
                    $formatParams = @{
                        FileSystem = $FileSystem
                        NewFileSystemLabel = "New Volume"
                        Confirm = $false
                        Force = $true
                    }
                    
                    $volume = Format-Volume -Partition $partition @formatParams 
                    
                    # Summary
                    Write-Host "`n  Disk $($disk.DiskNumber) successfully initialized:" -ForegroundColor Green
                    Write-Host "    Drive Letter: $($partition.DriveLetter)" -ForegroundColor Green
                    Write-Host "    File System: $FileSystem" -ForegroundColor Green
                    Write-Host "    Capacity: $([math]::Round($volume.Size / 1GB, 2)) GB" -ForegroundColor Green
                }
            }
            catch {
                Write-Error "Error processing disk $($disk.DiskNumber): $_"
            }
        }
    }
    
    end {
        Write-Host "`nOperation completed" -ForegroundColor Green
    }
}

function Update-SelectedDiskInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject[]]$SelectedDisks
    )
    
    try {
        # Get fresh disk information
        $currentDiskInfo = Get-DiskInfo
        
        # Update each selected disk with current information
        $updatedSelection = $SelectedDisks | ForEach-Object {
            $currentDisk = $currentDiskInfo | Where-Object { $_.DiskNumber -eq $_.DiskNumber }
            if ($currentDisk) {
                $currentDisk
            } else {
                Write-Warning "Disk $($_.DiskNumber) no longer found in system"
                $_  # Return original if not found
            }
        }
        
        return $updatedSelection
    }
    catch {
        Write-Error "Error updating disk information: $_"
        return $SelectedDisks  # Return original on error
    }
}

# Just get disk information
$diskInfo = Get-DiskInfo


# Select disks from the list
$selectedDisks = Select-DiskFromList -DiskList $diskInfo

if ($selectedDisks -eq $null) {
    Write-Host "No disks selected. Exiting script." -ForegroundColor Yellow
    exit
}

Show-DiskInfo $selectedDisks

# Clean and format the disks
Initialize-NewDisk  $selectedDisks -Force


Update-SelectedDiskInfo $selectedDisks

# Enable BitLocker on all selected disks
foreach ($disk in $script:selectedDisks) {
    # Generate random password and convert to proper format 
    $Password = New-RandomPassword -Length 25 -IncludeSpecialChars
    $SecureString = ConvertTo-SecureString $Password -AsPlainText -Force
    
    $mountPoint = "$($disk.DriveLetters):\"
    $BitLockerResult = Enable-BitLocker -MountPoint $mountPoint -EncryptionMethod Aes256 -PasswordProtector -Password $SecureString #-WhatIf #-UsedSpaceOnly 

    if ($BitLockerResult) {
        Write-Host "BitLocker enabled on $($disk.DriveLetters) with random password" -ForegroundColor Green
    } else {
        Write-Error "Failed to enable BitLocker on $($disk.DriveLetters)"
    }
}

# Spin until all selected disks are fully encrypted. If a disk finishes encryption while still spinning, wipe it again.
$selectedDisksCopy = @() + $selectedDisks
while ($selectedDisksCopy.Count -gt 0) {
    Write-Host "----------------------------------------" -ForegroundColor Cyan # Divider
    # Write-Host $selectedD`isksCopy
    foreach ($disk in $selectedDisksCopy) {
        $mountPoint = "$($disk.DriveLetters):\"
        $encryptionStatus = Get-BitLockerVolume -MountPoint $mountPoint | Select-Object -ExpandProperty EncryptionPercentage
        
        if ($encryptionStatus -eq 100) {
            Write-Host "Disk $($disk.DriveLetters) is fully encrypted" -ForegroundColor Green
            Initialize-NewDisk -SelectedDisks $disk -Force
            $selectedDisksCopy = $selectedDisksCopy | Where-Object { $_.DiskNumber -ne $disk.DiskNumber }
            Write-Host $selectedDisksCopy
        } else {
            Write-Host "Disk $($disk.DriveLetters) encryption progress: $encryptionStatus%" -ForegroundColor Yellow
        }
    }

    # Wait for 15 seconds before checking again
    Start-Sleep -Seconds 15
}

# One more format to ensure the disk is clean
Initialize-NewDisk -SelectedDisks $selectedDisks -Force