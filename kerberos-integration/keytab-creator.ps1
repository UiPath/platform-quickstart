# This script is used to generate 'KERB_DEFAULT_KEYTAB' used to setting up Kerberos authentication.
# It needs to be run in windows domain joined machines, and run as administrator.

$sf_fqdn = Read-Host -Prompt 'Automation Suite URL (e.g., automationsuite.mydomain.local)'

$ad_fqdn = Read-Host -Prompt 'AD domain FQDN (e.g., mydomain.local)'
$domain_info =  Get-ADDomain -Identity $ad_fqdn | select-object NetBIOSName
$nbname = $domain_info.NetBIOSName
Write-Output "AD Domain NetBIOSName is: $nbname"

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
            $ad_user_psw = Read-Host -Prompt 'AD user password' -AsSecureString
            $credential = New-Object System.Net.NetworkCredential($ad_username, $ad_user_psw)
            
            $ErrorActionPreference = "Stop"
            New-ADUser -Name $ad_username -PasswordNeverExpires $true -AccountPassword $ad_user_psw -KerberosEncryptionType 16 -Enabled $true -ErrorAction Stop
            $ErrorActionPreference = $ExistingEAP
            $usercheck_success = $true
            Write-Output "Successfully generated new AD user $ad_username"
        }
        catch 
        {
            $ErrorActionPreference = $ExistingEAP
            Write-Warning "Failed to create user: $($_.Exception.Message)"
        }
    }    
}
else
{
    while (!$usercheck_success)
    {
        try
        {
            $ad_username = Read-Host -Prompt 'AD username / sAMAccountName (e.g., aduser)'
            $ad_user_psw = Read-Host -Prompt 'AD user password' -AsSecureString
            $credential = New-Object System.Net.NetworkCredential($ad_username, $ad_user_psw)
            Write-Output 'Validating AD user:'
            $user = Get-ADUser -Identity $ad_username -Properties KerberosEncryptionType,ServicePrincipalName
            # Check if the user has AES256-SHA1 encryption enabled
            $hasAES256 = $user.KerberosEncryptionType -contains "AES256"
            # Display the appropriate message
            if ($hasAES256) {
                Write-Host "User $ad_username has AES256 encryption enabled." -ForegroundColor Green
            } 
            else {
                Write-Warning "Enabled AES256 encryption support for user account $ad_username "
                Set-ADUser -Identity $ad_username -KerberosEncryptionType AES256
            }

			# Check if the servicePrincipalName contains the required SPN
			$requiredSPN = "HTTP/$sf_fqdn"
			if ($user.ServicePrincipalName -eq $null -or $user.ServicePrincipalName -notcontains $requiredSPN) {
				Write-Warning "Adding SPN $requiredSPN to user account $ad_username"
				Set-ADUser -Identity $ad_username -Add @{ServicePrincipalName=$requiredSPN}
			} else {
				Write-Host "User $ad_username already has the required SPN $requiredSPN." -ForegroundColor Green
			}

            $usercheck_success = $true
            Write-Output "Successfully validated AD user $ad_username"
        }
        catch 
        {
            Write-Warning "Failed to validate user: $($_.Exception.Message)"
        }
    }    
}

function Check-CNAMERecord {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Address
    )

    try {
        # Perform a DNS lookup for the CNAME record
        $dnsResult = Resolve-DnsName -Name $Address -Type CNAME -ErrorAction Stop
        $cnameRecords = $dnsResult | Where-Object { $_.QueryType -eq "CNAME" }

        if ($cnameRecords) {
            Write-Host "CNAME record exists for address '$Address'. User has to turn off CNAME lookup for login. See instructions for Google Chrome: https://admx.help/?Category=Chrome`&Policy=Google.Policies.Chrome::DisableAuthNegotiateCnameLookup or for Microsoft Edge: https://admx.help/?Category=EdgeChromium`&Policy=Microsoft.Policies.Edge::DisableAuthNegotiateCnameLookup." -ForegroundColor Green
            $dnsResult | ForEach-Object {
                Write-Host $_.NameHost -ForegroundColor Green
            }
        } else {
            Write-Host "CNAME record does not exist for address '$Address'."
        }
    } catch {
        Write-Warning "Failed to check cname: $($_.Exception.Message)"
    }
}

Check-CNAMERecord -Address $sf_fqdn

$default_output_folder_path = 'C:\temp\KeytabOutputs'
$output_folder_path = Read-Host -Prompt 'Output folder path (the default path is "C:\temp\KeytabOutputs" - press "Enter" to continue with the default path)'
$output_folder_path = ($default_output_folder_path, $output_folder_path)[[bool]$output_folder_path]

If(!(Test-Path $output_folder_path))
{
    New-Item -ItemType Directory -Force -Path $output_folder_path
}

$keytab_file_path = $output_folder_path + '\krb5.keytab'

# Generate keytab
$upper_ad_fqdn = $ad_fqdn.ToUpper()

ktpass -princ HTTP/$sf_fqdn@$upper_ad_fqdn -pass $credential.Password -mapuser $nbname\$ad_username -pType KRB5_NT_PRINCIPAL -out $keytab_file_path -crypto AES256-SHA1

# Encode keytab
$keytab = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($keytab_file_path))

$output_file_path = $output_folder_path + '\output.txt'

# Check if the output file already exists
if (Test-Path $output_file_path) {
    Remove-Item $output_file_path -Force
}

New-Item $output_file_path -ItemType File -Value ("Here are the parameters for kerberos setup:" + [Environment]::NewLine)
Add-Content $output_file_path 'AdDomain:'
Add-Content $output_file_path $ad_fqdn
Add-Content $output_file_path 'AdUserName:'
Add-Content $output_file_path HTTP/$sf_fqdn
Add-Content $output_file_path 'UserKeytab:'
Add-Content $output_file_path $keytab
Write-Output "Please use parameters in the output file to configure Kerberos: $output_file_path"
