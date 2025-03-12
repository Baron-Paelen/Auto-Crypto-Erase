Made by Andrew Yegiayan :-)


# Automatic Secure Erasure Script!
## What is it?

I've created this script for the UCSC ITS Depot Technicians in order to automate the very boring process of wiping SSDs and HDDs one at a time.

The script will gather disk data, prompt the user to select disks, and then perform the proper wiping procedures as needed. There are built in protections to stop you from nuking C: drive as well.

## How do I use it?

First and foremost, you will need to be on *Windows 11 Pro*. Windows 10 may work, but is untested. *Windows Pro is necessary to enable BitLocker encryption drivers*.
Whether you boot off of a liveboot USB of Windows 11 or use a native Windows 11 install, *you will need administrator privelages* for the script to function properly.

Make sure all the drives you want to erase are, in fact, plugged into the computer with data and power connections. I would try to avoid the USB 2.0 to SATA adapters as they are ridicuously slow during encryption.

**If at any point you need to stop the script for whatever reason (either by X-ing the window or `Ctrl+C`):**
- If wiping SSDs: Open the "Manage BitLocker" Settings page, and disable any ongoing encryptions.
- If wiping HDDs: Close any open black CMD windows that are running the format command.

### Method 1 (Quick Execution)

1. Open *PowerShell* as *administrator*.

2. Simply run the following:
```powershell
irm https://raw.githubusercontent.com/ucscitsdepot/Auto-Secure-Erase/refs/heads/main/secure-erase.ps1 | iex
```
or
```powershell
irm https://tinyurl.com/its-secure-erase | iex
```
...and follow the prompts from the script.

### Method 2 (Manual Execution)

0. Download the script (or the whole repo) from the GitHub repository and place it somewhere accessible like the Desktop.

1. Open *PowerShell* as *administrator*. You will need to `cd` into the directory that the script is stored in.

2. Simply run `./secure-erase.ps1`, and follow the prompts from the script.

3. You will be updated periodically as the script progresses. In general, the script follows three stages:
    1. Clean, format, and name each disk. This is where you may see permission errors - Run *PowerShell* as admin.
    2. Begins wiping each disk.
    3. Periodically checks on the encryption progress of each disk. You may see errors here - make sure drives haven't been unplugged.
    4. When a drive is done encrypting, it will repeat step 1. Once that is complete you will see a success message for that drive, and will no longer see updates for it.
        - This happens while other drives are encrypting, so you may miss the success. (don't worry)

4. You will know the script is finished when:
    - SSDs: The script has exited and no more periodic updates are posted to your PowerShell window. A completion message will be posted as well.
    - HDDs: All black CMD windows have closed, and disk activity for selected disks is no longer at 100% in task manager


### Troubleshooting
1. Sometimes, disks may fail the automated process. This usually presents itself as a periodic wall of red and black error text. You can try:
    - Restarting the script after ending any ongoing formats or encryptions.
    - Erasing fewer disks at a time. This may help if you are using USB hubs, as those can get overwhelmed.
    - Running the disk(s) in a different enclosure. Some enclosures don't play nice with all disks.
    - Sometimes, drives are just DOA and can be tossed in the shred box.

3. You may run into a PowerShell error that says the script is not allowed to run.
This can be fixed via the [Set-ExecutionPolicy](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy?view=powershell-7.4) command. For our purposes, the `Unrestricted` policy is enough.
Run `Set-ExecutionPolicy Unrestricted` and agree to the prompt. **If this is not a Depot computer, please read the given link to only change the execution policy for the current session**.




## For Future Maintainers
Some things that can be improved or changed for QOL:
- Run the Unspecified drive prompts before the initial clean/formats begin. This way, users can do everything upon starting the script and then walk away. Currently, users must wait to see if any drives need to have their Type (HDD/SDD) specified before secure erasure actually begins.
- Check and disable in-progress BitLocker encryptions either on script failure/exit, or on script startup. This reduces the number of things the user has to do on a failed wiping attempt.





---
---
---

# Old and Deprecated. Can ignore safely
## This is my automatic cryptographic erasure script for ITS SSDs!
### powershell ALL version 
*(use this if you want to wipe multiple drives at once)*
This is the newest iteration. IT WILL WIPE AND FORMAT ALL DRIVES OTHER THAN THE C DRIVE. be careful :)
To use it, you must open an elevated powershell window, `cd` into this directory, and just run `./super_auto.ps1`. I will try to add a simpler start up script to avoid this.

### powershell SINGLE version 
*(use this if you are wiping a specific drive e.g. using the liveboot W11 drive to wipe another computer)*
This is the 2nd gen script. It will wipe and format only the drive who's letter and disk number you enter. There isn't protection against formatting the C drive (yet) so be careful :)
To use it, open an elevated powershell window, `cd` into this directory, and run `./auto_ssd.ps1 [Drive Letter] [Disk Number]`. Make sure that the drive letter and disk number refer to the same physical disk!

### python version
This is the original one. Don't use it, it's weird and buggy and doesn't always start bitlocker. Purely here for posterity's sake.
