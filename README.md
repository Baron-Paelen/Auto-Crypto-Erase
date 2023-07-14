Made by Andrew Yegiayan :-)

# This is my automatic cryptographic erasure script for ITS SSDs!

## powershell ALL version 
*(use this if you want to wipe multiple drives at once)*
This is the newest iteration. IT WILL WIPE AND FORMAT ALL DRIVES OTHER THAN THE C DRIVE. be careful :)
To use it, you must open an elevated powershell window, `cd` into this directory, and just run `./super_auto.ps1`. I will try to add a simpler start up script to avoid this.

## powershell SINGLE version 
*(use this if you are wiping a specific drive e.g. using the liveboot W11 drive to wipe another computer)*
This is the 2nd gen script. It will wipe and format only the drive who's letter and disk number you enter. There isn't protection against formatting the C drive (yet) so be careful :)
To use it, open an elevated powershell window, `cd` into this directory, and run `./auto_ssd.ps1 [Drive Letter] [Disk Number]`. Make sure that the drive letter and disk number refer to the same physical disk!

## python version
*(dont use)*
This is the original one. Don't use it, it's weird and buggy and doesn't always start bitlocker. Purely here for posterity's sake.
