# KapeStrike

KapeStrike is a collection of powershell scripts designed to streamline the collection of Kape triage packages via Crowdstrike's RTR function and can handle single or multiple hosts as well as queue collections for offline hosts by utilizing the amazing module PsFalcon in addition too parsing the data with multiple tools, massive shout out to Erik Zimmerman, including supertimeline creation with plaso 

Consists of 3 scripts:

- Invoke-Falcon.ps1 which uses PsFalcon to start an RTR session and kick off a kape triage collection
- Invoke-Falcon-Remote.ps1 is intended to be ran during the RTR session and will unzip kape, kick off a collection, upload it to an SFTP server as VHDX, then remove the files from the host. 
- Parse-Artifacts.ps1 takes the mounted VHDX drive letter and runs through various tools to parse the data including super timeline creation with plaso. 

## Prerequisite

- An RTR API key with rights to run scripts in RTR
- __[PsFalcon](https://github.com/CrowdStrike/psfalcon)__ installed on the examiner's machine
- Files and scriptes staged in Crowdstrike
- On the host which will parse the evidence:
  - WSL2 with [Log2Timeline](https://plaso.readthedocs.io/en/latest/sources/user/Ubuntu-Packaged-Release.html) and [sluethkit](https://ubuntu.pkgs.org/18.04/ubuntu-universe-amd64/sleuthkit_4.4.2-3_amd64.deb.html) installed 
  - A tools folder with the required tools on the host parsing the evidence 
  - EZ tools can be installed from Erik Zimmerman's github: https://ericzimmerman.github.io/#!index.md 
- A storage solution to write the captures (e.g. sftp server)
  - https://docs.microsoft.com/en-us/samples/azure-samples/sftp-creation-template/sftp-on-azure/  
  - https://docs.aws.amazon.com/transfer/latest/userguide/create-server-sftp.html
  - etc



## Set Up

### Crowdstrike

1. Upload the Invoke-Kape-Remote.ps1 file to "Custom Scripts" and change the connection details to match your environment

 ![image](https://user-images.githubusercontent.com/38758896/156845690-0a77fec3-58c9-4b73-8662-d6b466658534.png)

1. Upload a zipped copy of KAPE.exe, and a standalone 7za.exe to "PUT" Files.
  I remove the bin folder to cutdown on file size since we do the parsing off system

 ![image](https://user-images.githubusercontent.com/38758896/156846705-4b5bbef6-2ad8-4830-9e43-7be232fcba3d.png)

## Collection

1. Install PsFalcon on the system which will be kicking off collections: 

 [Install Instructions](https://github.com/CrowdStrike/psfalcon/wiki/Installation)

1. Import the Invoke-Kape.ps1 function to the same system 


## Evidence Parsing

1. On the system that will be used to parse the evidence import the Parse-Evidence.ps1 function and change the $toolsDrivePath variable on line 26 to your tools folder 

![image](https://user-images.githubusercontent.com/38758896/156852314-bf1dd193-b681-40d4-b861-98c063283aaf.png)
2. It expects the tools folder to be laid out in a rather flat way, with only applications with dependant files in their own folder

 ![image](https://user-images.githubusercontent.com/38758896/156857946-c7c276c0-e558-493a-afd9-bc847e06e0b7.png)



## Usage

### Invoke-Falcon.ps1

You can supply single or multi hosts with slight behavioral changes depending, but functionality is the same. 

To kick off a collection run the Invoke-Kape function and supply the target hostname(s) and the RTR API key details 

![image](https://user-images.githubusercontent.com/38758896/156859306-448fd6ea-f405-4d17-ad26-b15ded2ba549.png)

For multiple hosts there is an optional -OutPath flag which will create a CSV containing hostnames and offline/online status

![image](https://user-images.githubusercontent.com/38758896/156859231-d381d53e-1535-415d-8c25-0107848b7a29.png)

### Parse-Evidence.ps1

After downloading the collection mount the vhdx and take note of the drive letter

Run the Parse-Artifacts function and supply the mounted drive letter, the output path for the parsed files, and optionally a date time filter for the super timeline in YYYY-MM-DD format 

![image](https://user-images.githubusercontent.com/38758896/156859406-0a282b02-39d1-4c88-af5b-2e2337b893f8.png)

When it's finished running your output folder will have evidence parsed and labeled

![image](https://user-images.githubusercontent.com/38758896/156857673-ca47a808-a782-41b6-8789-ed6053f3e41a.png)




### Current Supported Evidence and Tools:
- $MFT Filesystem
  - MFTeCMD.exe
- Windows Event Logs
  - Chainsaw.exe
  - EvtxECmd.exe
- Amcache 
  - AmcacheParser.exe
- ShimCache
  - AppCompatCacheParser.exe
- Prefetch
  - PECmd.exe
- Registry Evidence of Execution
  - RegistryExplorer.exe 
- Timeline
  - Filesystem Timeline
  - Supertimeline     


## TO DO

Add flexability to Parse-Evidence to select which artifacts or all

Add better searching for tools for more flexible file structures

Add SRUM and Win10 timeline to parse-evidence


  
