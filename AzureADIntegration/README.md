# Azure AD Integration
These scripts will help you automate and test the Azure AD application registration used to configure the directory integration between your Automation Cloud Organization and your Azure AD or Office 365 tenant.

[configAzureADconnection.ps1](configAzureADconnection.ps1)

This script will automatically create and configure an app named Automation Cloud Azure AD Integration, and return the parameters needed to configure the connection (Azure AD Tenant ID, AppID, Client Secret).
```Powershell
.\configAzureADconnection.ps1 -TenantID "Your Azure AD TenantID"
```

[testAzureADappRegistration.ps1](testAzureADappRegistration.ps1)

This script will test your Azure AD app registration that you configured to ensure all the properties are configured properly.
```Powershell
.\testAzureADappRegistration.ps1 -TenantID "Your Azure AD tenant ID" -AppId "Your Automation Cloud Azure AD Integration application ID"
```
