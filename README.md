# KapeStrike

KapeStrike is a collection of powershell scripts designed to streamline collecting Kape triage packages via Crowdstrike's RTR function by utilizing the amazing module PsFalcon and parse the data with multiple tools including supertimeline creation with plaso.

It can handle single or multiple hosts as well as queue collections for offline hosts

## Prerequisite

- An RTR API key with rights to run scripts in RTR
- __[PsFalcon](https://github.com/CrowdStrike/psfalcon)__ installed on the examiner's machine
- Files and scriptes staged in Crowdstrike
- WSL2 with Log2Timeline and Mactime installed on the system which will parse the evidence
  - mactime: https://ubuntu.pkgs.org/18.04/ubuntu-universe-amd64/sleuthkit_4.4.2-3_amd64.deb.html
  - log2timeline: https://plaso.readthedocs.io/en/latest/sources/user/Ubuntu-Packaged-Release.html
- A storage solution to write the captures (e.g. sftp server)
  - https://docs.microsoft.com/en-us/samples/azure-samples/sftp-creation-template/sftp-on-azure/  
  - https://docs.aws.amazon.com/transfer/latest/userguide/create-server-sftp.html
  - etc


## Set Up

### Crowdstrike

1. Upload the Invoke-Kape-Remote.ps1 file to "Custom Scripts" and change the connection details to match your environment ![image](https://user-images.githubusercontent.com/38758896/156845690-0a77fec3-58c9-4b73-8662-d6b466658534.png)

1. Upload a zipped copy of KAPE.exe, and a standalone 7za.exe to "PUT" Files.
  I remove the bin folder to cutdown on file size since we do the parsing off system ![image](https://user-images.githubusercontent.com/38758896/156846705-4b5bbef6-2ad8-4830-9e43-7be232fcba3d.png)

## Analyst's System

1. Install PsFalcon on the system which will be kicking off collections:  [Install Instructions](https://github.com/CrowdStrike/psfalcon/wiki/Installation)

1. Import the Invoke-Kape.ps1 function to the same system which will be kicking off collections and change the $toolsDrivePath variable to match your tool folder

## Evidence Parsing

1. On the system that will be used to parse the evidence import the Parse-Evidence.ps1 function

## Usage

You can supply single or multi hosts with slight behavioral changes depending, but functionality is the same. 

For multiple hosts there is an optional -OutPath flag which will create a CSV containing hostnames and offline/online status

To kick off a collection run the Invoke-Kape function and supply the target hostname(s) and the RTR API key details ![image](https://user-images.githubusercontent.com/38758896/156847599-a34ba6e1-534b-4863-9107-918621f1358d.png)


![image](https://user-images.githubusercontent.com/38758896/156849469-ec5d3667-440a-471f-8479-2a719a8de740.png)



## TO DO

Finish usage section, and list tooks


### Current Support Tools



  
