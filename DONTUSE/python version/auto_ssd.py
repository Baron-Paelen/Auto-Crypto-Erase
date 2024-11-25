import os, sys, subprocess, random, time

def check_drive(driveletter):
    if len(driveletter) != 1:
        print ("Drive should be 1 character!")
        return False
    if os.path.exists(driveletter + ":"):
        print(f"Drive {driveletter} exists. Proceeding...")
        return True
    else:
        print(f"Drive {driveletter} DOES NOT EXIST!")
        return False

def generate_pw(length=16):
    characters = "qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890!@#$%^&*()-=_+<>?,.[]"
    pw = ''.join(random.choice(characters) for x in range(length))
    return pw
    
def bitlocker_status(driveletter):
    result = subprocess.run(['powershell', "-Command", f'Get-BitLockerVolume -MountPoint "{driveletter}" | Select-Object -ExpandProperty EncryptionPercentage'], capture_output=True, text=True)
    out = result.stdout.strip()

    if result.returncode != 0:
        print(f'There was an error in bitlocker_status()!: {out}')
        return False

    return int(output) == 100

    
if len(sys.argv) != 2:
    print("Invalid number of arguments.")
    exit()

drive = sys.argv[1].upper()

if not check_drive(drive):
    exit()




with open("./dp_script.txt", 'r') as file:
    contents = file.read()[:-1]

with open("./dp_script.txt", 'w') as file:
    file.write(contents + drive)

diskpart_cmd = "diskpart /s C:\\Users\\labeluser\\Desktop\\Auto-SSD\\dp_script.txt > C:\\Users\\labeluser\\Desktop\\Auto-SSD\\out.txt"
dp_shell_cmd = f'Start-Process powershell.exe -ArgumentList \'{diskpart_cmd}\''
output_dp = subprocess.Popen(["powershell", "-Command", dp_shell_cmd], shell=True).wait()
# streamdata = output_dp.communicate()[0]

time.sleep(15)

bitlocker_cmd = f'Enable-BitLocker -MountPoint "{drive}:" -PasswordProtector -Password $(ConvertTo-SecureString -String "{generate_pw()}" -AsPlainText -Force)'
powershell_cmd = f'Start-Process powershell.exe -Verb runAs -ArgumentList \'{bitlocker_cmd}\''
output_bitlocker = subprocess.Popen(["powershell", "-Command", powershell_cmd], shell=True)
streamdata = output_bitlocker.communicate()[0]


if output_bitlocker.returncode == 0:
    print("BitLocker started successfully! Please wait...")
else:
    print("BitLocker failed to enable. :(")

# while not bitlocker_status(drive):
#     time.sleep(5)
# print("bitlocker done!")

# subprocess.run(["format", drive, "/FS:NTFS", "/Q"])
# print("Yay! Drive has been wiped!")