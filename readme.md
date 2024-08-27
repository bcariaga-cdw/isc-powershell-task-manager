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
![Process Flow](https://github.com/bcariaga-cdw/queue-scripts/blob/main/images/Task%20Queue%20for%20Scripts%20-%20Conceptual%20Role%20Add%20Process%20Flow.png)
#### Delimited File Source
The delimited file source serves as the foundation for event triggering and auditing within ISC for this solution. It will store accounts for any user who has been processed and will be automatically updated and maintained by the PowerShell script to ensure auditability.

Additionally, the delimited file source will include an entitlement for each script required to run. For instance, if a script for mailbox creation is needed, an entitlement such as "Enable Mailbox" will be included. 
#### Work Items
When an entitlement is added to a user in a delimited file source, ISC will automatically create a work item for the manual addition of this entitlement, effectively establishing a queue for the required script executions. This work item queue will serve as the dataset for the script, indicating what needs to be processed.
#### PowerShell Script
The PowerShell script will be scheduled to run periodically to query open work items in the ISC Queue. Based on the details of these work items, the script will execute and log auditing information to an account entry in the delimited file source.

You can schedule the PowerShell script using a Cron Job or the built-in Windows Task Scheduler. Set the script to run as frequently as allowed by the scheduler to minimize processing time.

# Step-by-Step Usage
## 1. Setup a Delimited File Source
## 2. Setup PowerShell Script
## 3. Setup Custom PowerShell Scripts

# Use Cases
## Role Assignment: Active Directory After Creation Enables Mailbox
## Name Change (Workflow)

# Drawbacks
- Potentially misleading audit logs for entitlements associated with the delimited file source.
- Script execution audit events appear as an account on an identity, potentially leading to confusion.
- Unconventional use of work items, sources, and accounts.