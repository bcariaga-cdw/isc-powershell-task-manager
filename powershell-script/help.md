# Introduction
In this blog post, we will delve into an innovative solution for executing PowerShell scripts by leveraging built-in Identity Security Cloud (ISC) events, all while enabling user interface-based auditing of these executions. This guide will outline the proposed solution architecture and provide a step-by-step approach to implementing and utilizing this solution effectively.

# Background
In the current state of Identity Security Cloud, PowerShell scripts can only be triggered via Active Directory connector provisioning events, specifically Before/After Create or Modify Rules. I've encountered solutions that utilize dummy security groups or synchronize on attributes that are not necessarily useful within the system. However, these approaches come with limitations, such as restricted triggering of events or the creation of audit trails that reflect the addition of fake access, rendering them ineffective or misleading.

# Objectives
This guide offers a comprehensive solution for executing PowerShell scripts within the Identity Security Cloud (ISC) environment, addressing the limitations of current methods while enhancing the auditing process. By leveraging out-of-the-box ISC features, this approach minimizes the need for additional external architecture, utilizing built-in ISC events to create a more robust and efficient method for script execution. Key events for PowerShell execution in this solution include:
- **Lifecycle Changes**: Enable the triggering of PowerShell scripts based on identity lifecycle events.
- **Role Assignment:** Utilize role assignments as a trigger for script execution.
- **Workflow Processing**: Integrate PowerShell script execution within ISC workflows.

# Process Flow
[Insert Process Flow Diagram]
1. Identity and Action Trigger:
    **Identity:** Represents the user or system whose attributes might change.
    **Action:** Some event triggers an action, such as a change in an identity attribute.
    **Data Source:** The origin of the information or trigger for this action.

2. Identity Security Cloud Processing:

    Identity Attribute Changed: The identity's attributes are updated, which might include adding a new role or modifying existing ones.
    LCM / Role Added: This change leads to a Lifecycle Manager (LCM) event or a role being added to the identity.
    Access Item Grants Entitlement & Pushes Work Item: The system then grants the necessary entitlements (permissions, roles, etc.) and generates a work item to be processed by the task manager.

3. Task Management:

    Identity Security Cloud Task Manager: The task manager within Identity Security Cloud handles these work items, queuing them for further processing.
    Reads Work Item Queue Every X Minutes: A PowerShell task manager script regularly reads the work item queue to check for new tasks that need to be processed.

4. PowerShell Script Processing:

    PowerShell Task Manager Script: This script manages the execution of tasks. It reads the queue and determines what action is required.
    Executes Specified Script: Depending on the task, the script executes a specific PowerShell script to handle the role addition or any other required action.
    Writes Results to Identity Security Cloud: Once the script has processed the task, it writes the results back to Identity Security Cloud, completing the workflow.

This diagram represents a seamless integration between Identity Security Cloud and external processing scripts, ensuring that role additions and similar tasks are efficiently managed and executed.

# Solution Artifacts
## Delimited File Source
### Accounts
### Entitlements
## PowerShell Script
### Scheduling 
The PowerShell script could be scheduled using a Cron Job or the built-in Windows Task Scheduler.

# Drawbacks
-  Potentially misleading audit logs for entitlements associated with the delimited file source.
- Audit events appear as an account on an identity, leading to confusion.
- Unconventional use of work items, sources, and accounts.

# Step-by-Step Usage