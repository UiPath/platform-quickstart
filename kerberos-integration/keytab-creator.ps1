#This script is used to generate 'KERB_DEFAULT_KEYTAB' used to setting up Kerberos authentication.
#It needs to be run in windows domain joined machines, and run as administrator.

$sf_fqdn = Read-Host -Prompt 'Automation Suite URL (e.g., automationsuite.mydomain.local)'

$ad_fqdn = Read-Host -Prompt 'AD domain FQDN (e.g., mydomain.local)'
$domain_info =  Get-ADDomain -Identity $ad_fqdn | select-object NetBIOSName
$nbname = $domain_info.NetBIOSName
Write-Output 'AD Domain NetBIOSName is:'$nbname

$create_new_user = Read-Host -Prompt 'Create new AD user? Y or N'
while("y","n" -notcontains $create_new_user.ToLower())
{
	$create_new_user = Read-Host -Prompt 'Create new AD user? Y or N'
}
$create_user = switch($create_new_user.ToLower())
{
	"y" { $true; }
        "n" { $false; }
}

$usercheck_success = $false
if($create_user)
{
	Write-Output 'Generating new AD user:'
	while (!$usercheck_success)
	{
		$ExistingEAP = $ErrorActionPreference
		try{
			$ad_username = Read-Host -Prompt 'AD username / sAMAccountName (e.g., aduser)'
			$ad_user_psw = Read-Host -AsSecureString 'AD user password'
			$credential = New-Object System.Net.NetworkCredential($ad_username, $ad_user_psw)
			
			$ErrorActionPreference = "Stop"
			New-ADUser -Name $ad_username -PasswordNeverExpires $true -AccountPassword $ad_user_psw -KerberosEncryptionType 16 -Enabled $true -ErrorAction Stop
			$ErrorActionPreference = $ExistingEAP
			$usercheck_success = $true
			Write-Output 'Successfully generated new AD user '$ad_username
		}
		catch 
		{
			$ErrorActionPreference = $ExistingEAP
    			Write-Warning "Failed to create user: $($error[0])"
		}
	}	
}
else
{
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
}


$default_output_folder_path = 'C:\temp\KeytabOutputs'
$output_folder_path = Read-Host -Prompt 'Output folder path (the default path is "C:\temp\KeytabOutputs" - press "Enter" to continue with the default path)'
$output_folder_path = ($default_output_folder_path,$output_folder_path)[[bool]$output_folder_path]

If(!(Test-Path $output_folder_path))
{
      New-Item -ItemType Directory -Force -Path $output_folder_path
}

$keytab_file_path = $output_folder_path + '\krb5.keytab'

#Generate keytab
$upper_ad_fqdn = $ad_fqdn.ToUpper()

ktpass -princ HTTP/$sf_fqdn@$upper_ad_fqdn -pass $credential.Password -mapuser $nbname\$ad_username -pType KRB5_NT_PRINCIPAL -out $keytab_file_path -crypto AES256-SHA1

#Encode keytab
$keytab = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($keytab_file_path))

$output_file_path = $output_folder_path + '\output.txt'

New-Item $output_file_path -ItemType File -Value ("Here are the parameters for kerberos setup:"+ [Environment]::NewLine)
Add-Content $output_file_path 'AdDomain:'
Add-Content $output_file_path $ad_fqdn
Add-Content $output_file_path 'AdUserName:'
Add-Content $output_file_path HTTP/$sf_fqdn
Add-Content $output_file_path 'UserKeytab:'
Add-Content $output_file_path $keytab
Write-Output 'Please use parameters in the output file to configure Kerberos: '$output_file_path
