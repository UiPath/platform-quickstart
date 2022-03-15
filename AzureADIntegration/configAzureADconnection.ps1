Param( [string]$tenantId = "" )

if (!$tenantId) 
{ 
    Write-Host "Missing Tenant ID parameter. Please execute .\configAzureADconnection.ps1 'Your Azure AD TenantID'"
    exit 1
}

# Install or update the Microsoft Graph Powershell SDK
Write-Host "*************************************************************"
if (Get-Module -ListAvailable -Name Microsoft.Graph) {
    Write-Host "Updating the Microsoft Graph Powershell SDK"
    Update-Module Microsoft.Graph
} else {
    Write-Host "Insalling the Microsoft Graph Powershell SDK"
    Install-Module Microsoft.Graph
}

# Grant consent to the Microsoft Graph PowerShell app
# To read Azure AD organization info, create Azure AD app and service principal, and grant admin consent 
Write-Host "`n*************************************************************"
Write-Host "You will be asked to sign in using Microsoft's device login flow and grant consent to the Microsoft Graph Powershell app"
Write-Host "Please review permissons and grant consent to the Microsoft Graph PowerShell app"
Write-Host "Application.ReadWrite.All - To create Azure AD application and service principal objects"
Write-Host "DelegatedPermissionGrant.ReadWrite.All - To create oauth2PermissionGrants"
$graphConnection = Connect-MgGraph -TenantId "$tenantId" -Scopes "Application.ReadWrite.All", "DelegatedPermissionGrant.ReadWrite.All" -ErrorAction SilentlyContinue
if (!($graphConnection)) {
    Write-Host "Tenant ID wasn't found. Learn how to configure the Automation Cloud Azure AD Integration by navigating to https://docs.uipath.com/automation-cloud/docs/azure-ad-integration"
    exit 1
}

# Set up app registration metadata for Automation Cloud Azure AD Integration app
$appName = "Automation Cloud Azure AD Integration"

# Configure optional claims
$upn = @{ Name="upn"; Essential=$false}
$familyName = @{ Name="family_name"; Essential=$false}
$givenName = @{ Name="given_name"; Essential=$false}

# Microsoft Graph application Id aka resource Id 
$msGraphResourceId = "00000003-0000-0000-c000-000000000000"

# Microsoft Graph Service Prinicpal Object ID
$msGraphSp = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
$msGraphSpId = $msGraphSp.Id

# Configure graph permissions constants
$profile = @{ Id = "14dad69e-099b-42c9-810b-d002981feec1"; Type = "Scope"}
$email = @{ Id = "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0"; Type = "Scope"}
$openid = @{ Id = "37f7f235-527c-4136-accd-4a02d197296e"; Type = "Scope"}
$groupMemberReadAll = @{ Id = "bc024368-1153-4739-b217-4326f2e966d0"; Type = "Scope"}
$userReadBasicAll = @{ Id = "b340eb25-3456-403f-be2f-af7a0d370277"; Type = "Scope"}
$userRead = @{ Id = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"; Type = "Scope"}

# Configure web properties
$Web = @{
    RedirectUris = @("https://cloud.uipath.com/identity_/signin-oidc","https://cloud.uipath.com/portal_/testconnection")
    ImplicitGrantSettings = @{ `
        EnableAccessTokenIssuance = $false; `
        EnableIdTokenIssuance = $true; `
    } `
}

# Configure app registration parameters
$appRegParams = @{
    DisplayName = $appName
    SignInAudience = "AzureADMyOrg" 
    Web = $Web
    OptionalClaims = @{ IdToken = $upn, $familyName, $givenName}
    RequiredResourceAccess = @{ ResourceAppId = $msGraphResourceId; ResourceAccess = $profile, $email, $openid, $groupMemberReadAll, $userReadBasicAll, $userRead} 
}

# Create the application object
Write-Host "`n*************************************************************"
if(!($app = Get-MgApplication -Filter "DisplayName eq '$($appName)'"  -ErrorAction SilentlyContinue))
{
    $app = New-MgApplication @appRegParams  
}
$appId = $app.AppId 
Write-Host "Application object for $appName has an application ID: $appId"

# Create the service principal object
Write-Host "`n*************************************************************"
if(!($servicePrincipal = Get-MgServicePrincipal -Filter "appId eq '$($appId)'"  -ErrorAction SilentlyContinue))
{
    $servicePrincipal = New-MgServicePrincipal -DisplayName $appName -AppId $appId  
}
$servicePrincipalId = $servicePrincipal.Id
Write-Host "Service principal object for $appName has an object ID: $appId"

# Create client secret
Write-Host "`n*************************************************************"
Write-Host "Creating client secret for $appName"
$secret = Add-MgApplicationPassword -applicationId $app.Id 
$secretText = $secret.SecretText

# Create OAuth2PermissionGrant
$oauth2PermissionGrantParams = @{
    ClientId    = $servicePrincipalId
    ConsentType = "AllPrincipals"
    ResourceId  = $msGraphSpId 
    Scope       = "profile email openid User.Read.All Group.Read.All User.Read"
}

if(!(Get-MgOauth2PermissionGrant -Filter "clientId eq '$($servicePrincipalId)'"  -ErrorAction SilentlyContinue))
{
    New-MgOauth2PermissionGrant @oauth2PermissionGrantParams -ErrorAction SilentlyContinue | Out-Null
}

# Values needed to configure Azure AD connection in UiPath Automation Cloud 
Write-Host "`n*************************************************************"
Write-Host "Copy the following values into UiPath Automation Cloud to finish configuring the directory connection"
Write-Host "`nTenant Id: $tenantId `nApplication Id: $appId `nApplication Secret: $secretText"
