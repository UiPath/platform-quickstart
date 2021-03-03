# Azure AD Integration
These scripts will help you automate and test the Azure AD application registration used to configure the directory integration between your Automation Cloud Organization and your Azure AD or Office 365 tenant.

## Scripts
- [configAzureADconnection.ps1](##configAzureADconnection.ps1)
- [testAzureADappRegistration.ps1](##testAzureADappRegistration.ps1)

## [configAzureADconnection.ps1](configAzureADconnection.ps1)
This script will automatically create and configre an app named Automation Cloud Azure AD Integration, and return the parameters needed to configure the connection (Azure AD Tenant ID, AppID, Client Secret).

### Prerequisites: 
- Azure AD tenant 
- Access to an Azure AD Global Administrator, Cloud Application Administrator, or Application Administrator. 
- The script expects you don’t have an existing Azure AD app registration named Automation Cloud Azure AD Integration

### Configuration steps: 
1. Run the PowerShell Script as an Administrator:
```Powershell
.\configAzureADconnection.ps1 -TenantID "Your Azure AD TenantID"
```
2. You will be asked to sign in using Microsoft's device login flow and grant consent to the Microsoft Graph Powershell App
![Example of starting the configAzureADconnection script](./media/configPSexample1.png)


3. Copy the authentication code and enter it in [https://microsoft.com/devicelogin](https://microsoft.com/devicelogin)
![Microsoft device code flow](./media/msDeviceCode.png)

4. Sign in to your Azure AD Administrator account and grant consent to the Microsoft Graph PowerShell app
![Microsoft Graph PowerShell consent prompt](./media/msGraphPSConsent.png)

5. Let the script run and generate the required Tenant ID, Application ID, and Application Secret
![Example of completing the configAzureADconnection script](./media/configPSexample1.png)

6. Finally copy and paste the Azure AD Configuration values into Automation Cloud Portal
![Automation Cloud Portal](./media/automationCloudPortal.png)


## [testAzureADappRegistration.ps1](testAzureADappRegistration.ps1)
This script will test your Azure AD app registration that you configred to ensure all the properties are configured properly.

### Prerequisites: 
- Azure AD tenant 
- Access to an Azure AD Global Administrator, Cloud Application Administrator, or Application Administrator
- The script expects you have an existing Azure AD App Registration

### Configuration steps: 
1. Run the PowerShell Script as an Administrator:
```Powershell
.\testAzureADappRegistration.ps1 -TenantID "Your Azure AD tenant ID" -AppId "Your Automation Cloud Azure AD Integration application ID"
```

2. You will be asked to sign in using Microsoft's device login flow and grant consent to the Microsoft Graph Powershell App

3. Copy the authentication code and enter it in [https://microsoft.com/devicelogin](https://microsoft.com/devicelogin)

4. Sign in to your Azure AD Administrator account and grant consent to the Microsoft Graph PowerShell app

5. Let the script run and document discrepancies in the app registration

6. If there are discrepancies, the script will offer to fix them for you! You can answer reply Y for yes or N for no.
![Example of completing the testAzureADappRegistration script](./media/configPSexample1.png)
