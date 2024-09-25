# Introduction
In this blog post, we will delve into an innovative solution for executing PowerShell scripts by leveraging built-in Identity Security Cloud (ISC) features and events, all while enabling user interface-based auditing of these executions. This guide will outline the proposed solution architecture and provide a step-by-step approach to implementing and utilizing this solution effectively.

# Background
In the current state of Identity Security Cloud, PowerShell scripts can only be triggered via Active Directory connector provisioning events, specifically Before/After Create or Modify Rules. I've encountered solutions that utilize dummy security groups or synchronize on attributes that are not necessarily useful within the system. However, these approaches come with limitations, such as restricted triggering of events or the creation of audit trails that reflect the addition of fake access, rendering them ineffective or misleading. Additionally, the rules mentioned are designed to be fire-and-forget, making it challenging to trace errors and retry if necessary.

# Objectives
This guide offers a comprehensive solution for executing PowerShell scripts within the Identity Security Cloud (ISC) environment, addressing the limitations of current methods while enhancing the auditing process and retry-ability. By leveraging out-of-the-box ISC features, this approach minimizes the need for additional external architecture, utilizing built-in ISC events to create a more robust and efficient method for script execution. Key events for PowerShell execution in this solution include:
- **Lifecycle Changes**: Enable the triggering of PowerShell scripts based on identity lifecycle events.
- **Role Assignment:** Utilize role assignments as a trigger for script execution.
- **Workflow Processing**: Integrate PowerShell script execution within ISC workflows.

# Solution
![Process Flow](https://github.com/bcariaga-cdw/isc-powershell-task-manager/blob/main/images/Task%20Queue%20for%20Scripts%20-%20Process%20Flow.png)
## Sequence
![Sequence Diagram](https://github.com/bcariaga-cdw/queue-scripts/blob/main/images/Task%20Queue%20for%20Scripts%20-%20Sequence%20Diagram.png)
#### Delimited File Source
The delimited file source serves as the foundation for event triggering and auditing within ISC for this solution. It will store accounts for any user who has been processed and will be automatically updated and maintained by the PowerShell script to ensure auditability.

Additionally, the delimited file source will include an entitlement for each script required to run. For instance, if a script for mailbox creation is needed, an entitlement such as "Enable Mailbox" will be included. 
#### ISC (Work Items)
When an entitlement is added to a user in a delimited file source, ISC will automatically create a work item for the manual addition of this entitlement, effectively establishing a queue for the required script executions. This work item queue will serve as the dataset for the script, indicating what needs to be processed.
#### PowerShell Script
The PowerShell script will be scheduled to run periodically to query open work items in the ISC Queue. Based on the details of these work items, the script will execute and log auditing information to an account entry in the delimited file source.

You can schedule the PowerShell script using a Cron Job or the built-in Windows Task Scheduler. Set the script to run as frequently as allowed by the scheduler to minimize processing time.

# Step-by-Step Usage
## 1. Setup a Delimited File Source
A delimited file source is necessary to setup for this solution. Begin by creating a new source with a delimited file connector type. For ease of setup, an export of the source is provided in the `imports` folder to be directly imported to a tenant using SP-Config. If setting up manually, the source will need the following configuration:

**Account Schema** 
|Attribute Name|Multivalued|Entitlement|
|--------------|-----------|-----------|
|id|No|No|
|actions|Yes|Yes|
|statuses|Yes|No|
|transactions|Yes|No|
|errors|Yes|No|

**Entitlement Schema**
Create a new entitlement type called "action" with a single attribute called "name". 

**Correlation**
|Identity Attribute|Operation|Account Attribute|
|------------------|---------|-----------------|
|Username|equals|id|

**Create Provisioning Policy**
|Account Attribute|Identity Attribute|
|-----------------|------------------|
|id|uid|

**Entitlement Upload**
Upload the actions you wish to use for the PowerShell script execution. For example "handleHomeDrive". 

## 2. Setup PowerShell 
To setup the PowerShell portion, download and place the folder `powershell-script` on a Windows machine. This can easily be placed onto the IQService machine. Ensure your machine has the SailPoint PowerShell SDK installed and meets the mimumum requirements (https://developer.sailpoint.com/docs/tools/sdk/powershell).
### 2.1 Config.json File
The `config.json` file included will need to be configured for your specific environment. Here is an example of the file: 
```json
{
    "General": {
        "tenant": "<tenant-name>",
        "domain": "identitynow",
        "sdkVersion": "1.3.0",
        "logFileName": "log",
        "logLevel": 3
    },
    "Authentication": {
        "<tenant-name>": {
            "clientID": "<client-id>",
            "clientSecret": "<client-secret-encrypted>"
        }
    },
    "Script": {
        "sourceId": "<source-id-delimited-file-source>",
        "applicationName": "<application-name-without-[source]>",
        "actions": {
            "emailScript": "emailScript.ps1",
            "homeDriveScript": "homeDriveScript.ps1",
            "terminationScript": "terminationScript.ps1",
            "template": "template.ps1"
        }
    }
}
```
The General portion includes the tenant to connect to and the log settings. You can change the name of the log file and the log level. The log levels supported are: 0 to Disable Logging, 1 for Error only, 2 for Error & Info, 3 for Error, Info, & Debug.

The Authentication portion is where to define the Personal Access Token for your tenant. The key must match the tenant name configured in the General section. The current script uses Windows Credential Manager to encrypt the secret so it is not shown in plain text. To configure this follow these steps: 
1. Run PowerShell as User Exectuing the Script. 
2. Run the following command: `ConvertFrom-SecureString -SecureString $(Read-Host -AsSecureString)`
3. Paste the secret and copy the encrypted value. 
4. Enter the encrypted value in the config.json. 

This encryption process can be easily modified to suite your preferred method by modifying the `dist/util/Load-Token.ps1` file. 

The Script portion is where you will define your source id and application name of the source that was configured for this process. These fields are both necessary for the script to identify which work items relate to this process. The actions enable you to directly map the names of the entitlements on the source to the scripts located in the PowerShell Task Manager. 
### 2.2 Set the Path in the main.ps1 file
At the top of the main.ps1 file, set the path for where this folder resides on your system.
For Example: `$script:SCRIPT_PATH = "C:\SailPoint\Scripts\powershell-task-manager"`
### 2.3 Windows Task Scheduler
Use the Windows Task Scheduler or another scheduling service to run the `main.ps1` periodically. Recommended to run every 5 minutes. 

Note: Ensure that this is set to run using a PowerShell version 6.2 or greater.
## 3. Setup Custom PowerShell Scripts
Each action defined as an entilement will need a corresponding script file defined in the `scripts` folder. Each of these should be defined in the mapping stated in the `config.json` file. Each of these scripts must have:
- The script name defined at the top of the file like such: `$script:NAME = "Home Drive Script"`
- A method called `Invoke-Action` and takes in two arguments: the account id (uid) of the identity and the start time of the run.
- The method must return an object of type `RunResponse`. For example: `[RunResponse]::new("COMPLETED", $null)`. This method takes in two parameters: the status and error message. The available response statuses are `COMPLETED`, `ERROR`, or `NO_RETRY`. An `ERROR` response will be retried until a `NO_RETRY` is received. 

Here is an example of a script:
```powershell
# Define a readable name for this script.
$script:NAME = "Template Script"
function Invoke-Action ($account, $startTime) {
    try {
        Write-Log "$script:NAME has started."

        # DO SCRIPT LOGIC

        Write-Log "$script:NAME has finished."

        # Return a success status.
        return [RunResponse]::new("COMPLETED", $null)
    } catch {
        # Return an error status (NO_RETRY or ERROR)
        return [RunResponse]::new("ERROR", "($startTime) $_")
    }
}
```

# Example Use Cases
## Lifecycle: Remove Mailbox on Termination
## Role Assignment: Active Directory After Creation Enables Mailbox
## Workflow: Name Change

# Drawbacks
This solution is unorthodox for the ISC architecture and does contain a few drawbacks: 
- Misleading audit logs for entitlements associated with the delimited file source.
- Script execution audit events appear as an account on an identity, potentially leading to confusion.
- Unconventional use of work items, sources, and accounts.