$filePath = Get-ChildItem "C:\temp\kape\KAPE" -ErrorAction SilentlyContinue
if ($null -eq $filePath) {
    & "C:\temp\kape\7za.exe" x KAPE.zip
}
& 'C:\temp\kape\kape\kape.exe' --tsource C: --target KapeTriage --tdest C:\temp\kapeOutput --vhdx C_KapeTriage_$env:COMPUTERNAME --scs "XXXX_ADD_IP_OR_HOSTNAME" --scu sftp --scpw XXXX_ADD_PASSWORD_XXXX --scd upload --tflush
#remove Kape when finished
cd C:\temp
Remove-Item C:\temp\Kape -Recurse -Force
Remove-Item C:\Temp\KapeOutput -Recurse -Force
