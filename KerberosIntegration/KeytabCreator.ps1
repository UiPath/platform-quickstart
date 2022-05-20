$sf_fqdn = Read-Host -Prompt 'Automation Suite URL (e.g., automationsuite.mydomain.local)'
$ad_fqdn = Read-Host -Prompt 'AD domain FQDN (e.g., mydomain.local)'
$ad_domain_host = Read-Host -Prompt 'AD domain NETBIOS name (e.g., mydomain)'
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

$ad_username = Read-Host -Prompt 'AD username / sAMAccountName (e.g., aduser)'
$ad_user_psw = Read-Host -AsSecureString 'AD user password'
$default_keytab_file_path = 'C:\temp\krb5.keytab'
$keytab_file_path = Read-Host -Prompt 'Keytab file path (the default path is "C:\temp\krb5.keytab" - press "Enter" to continue with the default path)'
$keytab_file_path = ($default_keytab_file_path,$keytab_file_path)[[bool]$keytab_file_path]

if($create_user)
{
#Generate AD user
New-ADUser -Name $ad_username -PasswordNeverExpires $true -AccountPassword $ad_user_psw -KerberosEncryptionType 16 -Enabled $true
}

#Generate keytab
$upper_ad_fqdn = $ad_fqdn.ToUpper()
$upper_ad_host = $ad_domain_host.ToUpper()
ktpass -princ HTTP/$sf_fqdn@$upper_ad_fqdn -pass $ad_user_psw -mapuser $upper_ad_host\$ad_username -pType KRB5_NT_PRINCIPAL -out $keytab_file_path -crypto AES256-SHA1

#Encode keytab
$keytab = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($keytab_file_path))

Write-Output 'Here are the parameters for kerberos setup:'

Write-Output 'AdDomain:'
Write-Output $ad_fqdn
Write-Output 'AdUserName:'
Write-Output HTTP/$sf_fqdn
Write-Output 'UserKeytab:'
Write-Output $keytab

