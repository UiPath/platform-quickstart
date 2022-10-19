#This script is used to generate '<KERB_APP_KEYTAB>' used to setting up Kerberos authentication using unique AD account per service group.
#It needs to be run in windows domain joined machines, and run as administrator.

$ad_fqdn = Read-Host -Prompt 'AD domain FQDN (e.g., mydomain.local)'

$usercheck_success = $false
while (!$usercheck_success)
{
	try{
		$ad_username = Read-Host -Prompt 'AD username / sAMAccountName (e.g., aduser)'
		$ad_user_psw = Read-Host -AsSecureString 'AD user password'
		$credential = New-Object System.Net.NetworkCredential($ad_username, $ad_user_psw)
		Write-Output 'Validating AD user:'
		Get-ADUser -Identity $ad_username
		$usercheck_success = $true
		Write-Output 'Successfully validated AD user '$ad_username
	}
	catch 
	{
    		Write-Warning "Failed to validate user: $($error[0])"
	}
}	

$default_output_folder_path = 'C:\temp\ServiceKeytabOutputs'
$output_folder_path = Read-Host -Prompt 'Output folder path (the default path is "C:\temp\ServiceKeytabOutputs" - press "Enter" to continue with the default path)'
$output_folder_path = ($default_output_folder_path,$output_folder_path)[[bool]$output_folder_path]

If(!(Test-Path $output_folder_path))
{
      New-Item -ItemType Directory -Force -Path $output_folder_path
}

$keytab_file_path = $output_folder_path + '\krb5.keytab'

#Generate keytab
$upper_ad_fqdn = $ad_fqdn.ToUpper()
ktpass -princ $ad_username@$upper_ad_fqdn -pass $credential.Password  -pType KRB5_NT_PRINCIPAL -out $keytab_file_path -crypto AES256-SHA1 -setpass

#Encode keytab
$keytab = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($keytab_file_path))

$output_file_path = $output_folder_path + '\output.txt'
New-Item $output_file_path -ItemType File -Value ("Here are the parameters for kerberos setup per service group:"+ [Environment]::NewLine)
Add-Content $output_file_path 'AdUserName:'
Add-Content $output_file_path $ad_username
Add-Content $output_file_path 'UserKeytab:'
Add-Content $output_file_path $keytab
Write-Output 'Please use parameters in the output file to configure Kerberos per service group: '$output_file_path


