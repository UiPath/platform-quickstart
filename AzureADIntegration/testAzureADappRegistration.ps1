Param( 
    [parameter(Mandatory=$true, HelpMessage="Enter your Azure AD's Tenant ID")]
    [ValidateNotNullOrEmpty()]
    [string]$tenantId,
    [parameter(Mandatory=$true, HelpMessage="Enter your Application ID")]
    [ValidateNotNullOrEmpty()]
    [string]$appId,
    [parameter(Mandatory=$true, HelpMessage="Enter 'AutomationCloud' or 'AutomationSuite'")]
    [ValidateSet("AutomationCloud", "AutomationSuite")]
    [string]$platform,
    [parameter(Mandatory=$false, HelpMessage="Enter your AutomationSuite's fqdn")]
    [string]$automationSuiteFqdn
)


# Exit the script if '-automationSuiteFqdn' is not provided when AutomationSuite is chosen for $platform
if ($platform -eq "AutomationSuite" -and !$automationSuiteFqdn){
    Write-Host "Missing Automation Suite FQDN parameter."
    Write-Host "Please execute:"
    Write-HOst ".\configureAzureADconnection.ps1 -tennantId 'your aad tenant id' -platform 'AutomationSuite' -automationSuiteFqdn 'your automation suite fqdn'"
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
Write-Host "Asking to grant consent to the Microsoft Graph PowerShell app"
Write-Host "Review permissons and grant consent to the Microsoft Graph PowerShell app"
Write-Host "Application.ReadWrite.All - To create Azure AD application and service principal objects"
Write-Host "DelegatedPermissionGrant.ReadWrite.All - To create oauth2PermissionGrants"
$graphConnection = Connect-MgGraph -TenantId "$tenantId" -Scopes "Application.ReadWrite.All", "DelegatedPermissionGrant.ReadWrite.All" -ErrorAction SilentlyContinue
if (!($graphConnection)) {
    Write-Host "The tenant ID ( $tenantId ) wasn't found. Learn how to configure the Automation Cloud Azure AD Integration by navigating to https://docs.uipath.com/automation-cloud/docs/azure-ad-integration"
    exit 1
}

# Microsoft Graph application Id aka resource Id 
$msGraphResourceId = "00000003-0000-0000-c000-000000000000"

# Microsoft Graph Service Prinicpal Object ID
$msGraphSp = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
$msGraphSpId = $msGraphSp.Id

$testConfigPasses = $True

# Get up app metadata for Automation Cloud Azure AD Integration app
$app =  Get-MgApplication -Filter "appId eq '$($appId)'" -ErrorAction SilentlyContinue
if(!$app) {
    Write-Host "The application id ( $appId ) was not found. Learn how to configure the Automation Cloud Azure AD Integration by navigating to https://docs.uipath.com/automation-cloud/docs/azure-ad-integration"
    exit 1
}
$appName = $app.DisplayName
$applicationId = $app.Id

#Check SignInAudience
$signInAudience = $app.SignInAudience
Write-Host "`n*************************************************************"
if($signInAudience -eq 'AzureADMyOrg') {
    Write-Host "Sign in audience is properly configured: $signInAudience"
} else {
    Write-Host "Sign in audience is not properly configured. Please configure the application to be 'AzureADMyOrg'"
    $testConfigPasses = $False
}

#Check RedirectURIs
Write-Host "`n*************************************************************"
$web = $app.Web
$redirectUris = $web.redirectUris
if ($redirectUris -match 'https://cloud.uipath.com/portal_/testconnection' -And $redirectUris -match 'https://cloud.uipath.com/identity_/signin-oidc'){
    Write-Host "RedirectURIs are properly configured: $redirectUris"
} elseif ($redirectUris -match "https://$($automationSuiteFqdn)/portal_/testconnection" -and "https://$($automationSuiteFqdn)/identity_/signin-oidc)") {
    Write-Host "RedirectURIs are properly configured: $redirectUris"
} else {
    Write-Host "RedirectURIs are not properly configured. Please configure the following redirect URIs: 'https://cloud.uipath.com/portal_/testconnection' and 'https://cloud.uipath.com/identity_/signin-oidc'"
    $testConfigPasses = $False
}

#Check ImplicitGrant
Write-Host "`n*************************************************************"
$enableAccessTokenIssuance = $web.implicitGrantSettings.enableAccessTokenIssuance
$enableIdTokenIssuance = $web.implicitGrantSettings.enableIdTokenIssuance
if( $enableAccessTokenIssuance -eq $False -And $enableIdTokenIssuance) {
    Write-Host "Implicit grant settings are properly configured"
} else {
    Write-Host "Implicit grant settings are not properly configured. Please configure the issuance of id tokens from the implicit grant settings."
    $testConfigPasses = $False
}

#Check OptionalClaims
Write-Host "`n*************************************************************"
$optionalClaims = $app.OptionalClaims
$idTokenClaims = $optionalClaims.idToken.name
if ($idTokenClaims -match 'upn' -And $idTokenClaims -match 'family_name' -And $idTokenClaims -match 'given_name'){
    Write-Host "Optional claims are properly configured: $idTokenClaims"
} else {
    Write-Host "Optional claims are not properly configured. Please configure the following optional claims upn, family_name, given_name for the id token"
    $testConfigPasses = $False
}

#Check if service principal object
Write-Host "`n*************************************************************"
$servicePrincipal = Get-MgServicePrincipal -Filter "appId eq '$($appId)'"  -ErrorAction SilentlyContinue
if($servicePrincipal){
    $servicePrincipalId = $servicePrincipal.Id
    Write-Host "Service principal object is  properly configured with the id: $servicePrincipalId"
} else {
    Write-Host "Service principal object was not properly configured. Please configure the following optional claims upn, family_name, given_name for the id token"
    $testConfigPasses = $False
}

#Check Oauth2PermissionGrant
Write-Host "`n*************************************************************"
$oauth2PermissionGrant = Get-MgOauth2PermissionGrant -Filter "clientId eq '$($servicePrincipalId)'" -ErrorAction SilentlyContinue
if ($platform -eq "AutomationSuite"){
    $scopeList = @("Group.Read.All","profile","email","User.Read","openid","User.Read.All")
} elseif ($platform -eq "AutomationCloud") {
    $scopeList = @("GroupMember.Read.All","profile","email","User.Read","openid","User.ReadBasic.All")
}
if($oauth2PermissionGrant){
    $scopes = $oauth2PermissionGrant.Scope
    $consentType = $oauth2PermissionGrant.ConsentType
    $scopeErrorCount = 0
    foreach ($scope in $scopeList) {
        if ($scopes -notmatch $scope) {
            Write-Host "$($scope) is misisng from the Oauth2PermissionGrants permmision"
            $scopeErrorCount++
        }
    }
    if ($scopeErrorCount -eq 0 -and $consentType -eq 'AllPrincipals') {
        Write-Host "Oauth2PermissionGrants are properly configured for the following scopes: $scopes"
    } else {
        Write-Host "Oauth2PermissionGrants are not properly configured. Please grant admin consnet to the following delegated permissions from Microsoft Graph: profile, email, openid, User.Read.All, User.Read, Group.Read.All"
        $testConfigPasses = $False
    }
    # if ($scopes -match 'profile' -And $scopes -match 'email' -And $scopes -match 'openid' -And $scopes -match 'User.Read.All' -And $scopes -match 'Group.Read.All' -And $consentType -eq 'AllPrincipals' ) {
    #     Write-Host "Oauth2PermissionGrants are properly configured for the following scopes: $scopes"
    # }
} else {
    Write-Host "Oauth2PermissionGrants are not properly configured. Please grant admin consnet to the following delegated permissions from Microsoft Graph: profile, email, openid, User.Read.All, User.Read, Group.Read.All"
    $testConfigPasses = $False
}

# If the test fails, ask if admin would like to update the app
Write-Host "`n*************************************************************"
if($testConfigPasses) {
    Write-Host "Alright everything looks good and the app is good to go!"
    exit 1
} else {
    $consent = Read-Host -Prompt 'Would you like this script to programatically fix your app configuration? Please reply Y for yes and N for no'
}

# Update the app configurations
if($consent -eq 'Y'){
    if(!$servicePrincipalId) {
        $servicePrincipal = New-MgServicePrincipal -DisplayName $appName -AppId $appId  
        $servicePrincipalId = $servicePrincipal.Id
    }

    # Optional claims
    $upn = @{ Name="upn"; Essential=$false}
    $familyName = @{ Name="family_name"; Essential=$false}
    $givenName = @{ Name="given_name"; Essential=$false}

    # Graph permissions constants
    $graphPerms = @{}
    $graphPerms.Add("profile", @{ Id = "14dad69e-099b-42c9-810b-d002981feec1"; Type = "Scope"})
    $graphPerms.Add("email", @{ Id = "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0"; Type = "Scope"})
    $graphPerms.Add("openid", @{ Id = "37f7f235-527c-4136-accd-4a02d197296e"; Type = "Scope"})
    $graphPerms.Add("User.Read", @{ Id = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"; Type = "Scope"})
    if ($platform -eq "AutomationCloud"){
        $graphPerms.Add("GroupMember.Read.All", @{ Id = "bc024368-1153-4739-b217-4326f2e966d0"; Type = "Scope"})
        $graphPerms.Add("User.ReadBasic.All",  @{ Id = "b340eb25-3456-403f-be2f-af7a0d370277"; Type = "Scope"})
    } elseif($platform -eq "AutomationSuite"){
        $graphPerms.Add("Group.Read.All", @{ Id = "5f8c59db-677d-491f-a6b8-5f174b11ec1d"; Type = "Scope"})
        $graphPerms.Add("User.Read.All",  @{ Id = "a154be20-db9c-4678-8ab7-66f6cc099a59"; Type = "Scope"})
    }
    # $profile = @{ Id = "14dad69e-099b-42c9-810b-d002981feec1"; Type = "Scope"}
    # $email = @{ Id = "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0"; Type = "Scope"}
    # $openid = @{ Id = "37f7f235-527c-4136-accd-4a02d197296e"; Type = "Scope"}
    # $groupMemberReadAll = @{ Id = "bc024368-1153-4739-b217-4326f2e966d0"; Type = "Scope"}
    # $userReadBasicAll = @{ Id = "b340eb25-3456-403f-be2f-af7a0d370277"; Type = "Scope"}
    # $userRead = @{ Id = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"; Type = "Scope"}

    if ($platform -eq "AutomationCloud") {
        $Web = @{
            RedirectUris = @("https://cloud.uipath.com/identity_/signin-oidc","https://cloud.uipath.com/portal_/testconnection")
            ImplicitGrantSettings = @{ `
                EnableAccessTokenIssuance = $false; `
                EnableIdTokenIssuance = $true; `
            } `
        }
    } elseif ($platform -eq "AutomationSuite") {
        $Web = @{
            RedirectUris = @("https://$($automationSuiteFqdn)/identity_/signin-oidc","https://$($automationSuiteFqdn)/portal_/testconnection")
            ImplicitGrantSettings = @{ `
                EnableAccessTokenIssuance = $false; `
                EnableIdTokenIssuance = $true; `
            } `
        }
    }
    # Configure app registration parameters
    $resouceAccess = @()
    $scope = ""
    foreach ($graphPermKey in $graphPerms.Keys){
        $resouceAccess += $graphPerms[$graphPermKey]
        $scope += "$($graphPermKey) "
    }
    $appRegParams = @{
        SignInAudience = "AzureADMyOrg" 
        Web = $Web
        OptionalClaims = @{ IdToken = $upn, $familyName, $givenName}
        RequiredResourceAccess = @{ ResourceAppId = $msGraphResourceId; ResourceAccess = $resouceAccess} 
    }

    $oauth2PermissionGrantParams = @{
        ClientId    = $servicePrincipalId
        ConsentType = "AllPrincipals"
        ResourceId  = $msGraphSpId 
        Scope       = $scope
    }

    # Update the application
    Update-MgApplication -ApplicationId $applicationId @appRegParams -ErrorAction SilentlyContinue
    if($oauth2PermissionGrant) {
        Update-MgOauth2PermissionGrant -OAuth2PermissionGrantId $oauth2PermissionGrant.Id @oauth2PermissionGrantParams -ErrorAction SilentlyContinue | Out-Null
    }
    New-MgOauth2PermissionGrant @oauth2PermissionGrantParams -ErrorAction SilentlyContinue | Out-Null
  
    Write-Host "Alright you should be good to go! Feel free to run the script again to double check :)"
} else {
    Write-Host "Thank you for running this script! Please update the app registration properties as advised above, and you can learn more at https://docs.uipath.com/automation-cloud/docs/azure-ad-integration"
}
