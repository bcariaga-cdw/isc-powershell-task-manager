# Introduction
In this blog post, we will delve into an innovative solution for executing PowerShell scripts by leveraging built-in Identity Security Cloud (ISC) features and events, all while enabling user interface-based auditing of these executions. This guide will outline the proposed solution architecture and provide a step-by-step approach to implementing and utilizing this solution effectively.

# Overview
In the current state of Identity Security Cloud, PowerShell scripts can only be triggered via Active Directory connector provisioning events, specifically Before/After Create or Modify Rules. However, these approaches are stateless, synchrounous processes. Script execution is tied to a succesful provisioning event with no retry-ability and status of execution brought into the identity level or ISC. 

# Objectives
To workaround the caveats with the current architecture, a nifty solution was developed utilizing the Out-the-Box Task Manager functionality of ISC to create a mechnism for queueing script executions to be run on demand, retry-able, and promote the status of the executions to the identity level in ISC. 

By leveraging out-of-the-box ISC features, this approach minimizes the need for additional external architecture, utilizing built-in ISC events to create a more robust and efficient method for script execution. Key events for PowerShell execution in this solution include:
- **Lifecycle Changes**: Enable the triggering of PowerShell scripts based on identity lifecycle events.
- **Role Assignment:** Utilize role assignments as a trigger for script execution.
- **Workflow Processing**: Integrate PowerShell script execution within ISC workflows.

# Solution Details
![Process Flow](https://github.com/bcariaga-cdw/isc-powershell-task-manager/blob/main/images/Task%20Queue%20for%20Scripts%20-%20Process%20Flow.png)

Beginning with an Identity, which triggers certain Actions through ISC processes such as Lifecycle Manager (LCM), Role Assignments, or Workflows. These actions grant an Entitlement to the identity, which is the key event that drives the process. Once the entitlement is granted, a work item is pushed to the ISC Task Manager. The ISC Task Manager manages the queue of work items, which represent tasks associated with the entitlement. A PowerShell Script periodically checks the work item queue (e.g., every 5 minutes) for new tasks. When a new work item related to the entitlement is found, the script retrieves it and executes the specified PowerShell script based on the entitlements granted. After executing the script, the PowerShell task manager writes the results back to IdentityNow (the ISC platform), completing the loop and ensuring auditability.

This solution demonstrates how ISC can handle PowerShell script execution based on identity events, improving automation and visibility by leveraging native ISC features, with additional flexibility through the PowerShell task manager.
## Sequence
![Sequence Diagram](https://github.com/bcariaga-cdw/queue-scripts/blob/main/images/Task%20Queue%20for%20Scripts%20-%20Sequence%20Diagram.png)

**Delimited File Source**

The delimited file source serves as the foundation for event triggering and auditing within ISC for this solution. It will store accounts for any user who has been processed and will be automatically updated and maintained by the PowerShell script to ensure auditability.

Additionally, the delimited file source will include an entitlement for each script required to run. For instance, if a script for mailbox creation is needed, an entitlement such as "Enable Mailbox" will be included. 

**ISC (Work Items)**

When an entitlement is added to a user in a delimited file source, ISC will automatically create a work item for the manual addition of this entitlement, effectively establishing a queue for the required script executions. This work item queue will serve as the dataset for the script, indicating what needs to be processed.

**PowerShell Script**

The PowerShell script will be scheduled to run periodically to query open work items in the ISC Queue. Based on the details of these work items, the script will execute and log auditing information to an account entry in the delimited file source.

You can schedule the PowerShell script using a Cron Job or the built-in Windows Task Scheduler. Set the script to run as frequently as allowed by the scheduler to minimize processing time.

# Step-by-Step Usage
### 1. Setup a Delimited File Source
To implement this solution, it is essential to configure a delimited file source. Start by creating a new source using the delimited file connector type. For convenience, an export of the source is available in the `imports` folder, which can be directly imported into a tenant using SP-Config. If you prefer to configure the source manually, the following settings are required:

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

### 2. Setup PowerShell 
To configure the PowerShell component, download the `powershell-script` folder and place it on a Windows machine, preferably on the IQService machine for convenience. Ensure that the machine has the SailPoint PowerShell SDK installed and meets the minimum requirements (https://developer.sailpoint.com/docs/tools/sdk/powershell).
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
The **General** section contains the tenant information and log settings. You can modify the log file name and adjust the log level. The supported log levels are:
- `0`: Disable Logging
- `1`: Error Only
- `2`: Error & Info
- `3`: Error, Info, & Debug

The **Authentication** section is where you define the Personal Access Token for your tenant. The key must match the tenant name specified in the General section. The script uses the Windows Data Protection API to encrypt the secret, preventing it from being displayed in plain text. To configure this, follow these steps:
1. Run PowerShell as User Exectuing the Script. 
2. Run the following command: `ConvertFrom-SecureString -SecureString $(Read-Host -AsSecureString)`
3. Paste the secret and copy the encrypted value. 
4. Enter the encrypted value in the `config.json`. 

This encryption process can be easily customized by editing the `dist/util/Load-Token.ps1` file to suit your preferred method.

The **Script** section is where you define the `source id` and `application name` of the source configured for this process. Both fields are required for the script to identify relevant work items. The actions allow direct mapping of source entitlement names to scripts in the PowerShell Task Manager.
#### 2.2 Set the Path in the main.ps1 file
At the beginning of the `main.ps1` file, specify the path where the folder is located on your system.
For Example: `$script:SCRIPT_PATH = "C:\SailPoint\Scripts\powershell-task-manager"`
#### 2.3 Windows Task Scheduler
Utilize Windows Task Scheduler or an alternative scheduling service to run the `main.ps1` script at regular intervals. It is recommended to schedule it to run every 5 minutes.

Note: Ensure the script is executed with PowerShell version 6.2 or higher.
### 3. Setup Custom PowerShell Scripts
Each action defined as an entitlement requires a corresponding script file located in the `scripts` folder. These scripts must be mapped according to the configurations specified in the `config.json` file. Each script must adhere to the following requirements:
- Define the script name at the top of the file, for example: `$script:NAME = "Home Drive Script"`
- Implement a method named `Invoke-Action` that accepts two arguments: the Account ID (uid) of the identity and the run's start time.
- The `Invoke-Action` method must return an object of type `RunResponse`. For example: `[RunResponse]::new("COMPLETED", $null)`. This method takes in two parameters: the status and error message. The available response statuses are `COMPLETED`, `ERROR`, or `NO_RETRY`. An `ERROR` response will be retried on next run until a `NO_RETRY` response is returned. 

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
Below are several potential use cases that can be addressed with this implementation. It is highly flexible and not limited to these scenarios. The only requirement to trigger this solution is the assignment of an entitlement action to an identity, with flexibility in how it is granted.
### Lifecycle: Remove Mailbox on Termination
To implement this use case, create an access profile containing the entitlement action and assign it during the termination lifecycle state.
### Role Assignment: Active Directory After Creation Enables Mailbox
For this use case, create a role with membership criteria based on an identity attribute, such as the creation of an AD account. Once this condition is met, the role can grant the associated entitlement.
### Workflow: Name Change
To configure this use case, design a new workflow triggered by a change in an identity attribute, such as a name change. Use the manage access node to grant the entitlement action to the identity upon detecting the change.

# Limitations
This solution is unconventional within the ISC architecture and presents a few limitations:
- Audit logs for entitlements associated with the delimited file source may be misleading.
- Script execution audit events are logged as accounts tied to an identity, which could cause confusion.
- The approach involves an atypical use of work items, sources, and accounts.