$ad_fqdn = Read-Host -Prompt 'AD domain FQDN (e.g., mydomain.local)'
$ad_username = Read-Host -Prompt 'AD username / sAMAccountName (e.g., aduser)'
$ad_user_psw = Read-Host -AsSecureString 'AD user password'
$default_keytab_file_path = 'C:\temp\krb5.keytab'
$keytab_file_path = Read-Host -Prompt 'Keytab file path (the default path is "C:\temp\krb5.keytab" - press "Enter" to continue with the default path)'
$keytab_file_path = ($default_keytab_file_path,$keytab_file_path)[[bool]$keytab_file_path]

#Generate keytab
$upper_ad_fqdn = $ad_fqdn.ToUpper()
ktpass -princ $ad_username@$upper_ad_fqdn -pass $ad_user_psw  -pType KRB5_NT_PRINCIPAL -out $keytab_file_path -crypto AES256-SHA1 -setpass

#Encode keytab
$keytab = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($keytab_file_path))

Write-Output 'Here are the parameters for kerberos setup per service group:'

Write-Output 'AdUserName:'
Write-Output ad_username
Write-Output 'UserKeytab:'
Write-Output $keytab

