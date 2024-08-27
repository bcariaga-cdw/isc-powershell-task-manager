# Introduction
In this blog post, we will delve into an innovative solution for executing PowerShell scripts by leveraging built-in Identity Security Cloud (ISC) events, all while enabling user interface-based auditing of these executions. This guide will outline the proposed solution architecture and provide a step-by-step approach to implementing and utilizing this solution effectively.

# Background
In the current state of Identity Security Cloud, PowerShell scripts can only be triggered via Active Directory connector provisioning events, specifically Before/After Create or Modify Rules. I've encountered solutions that utilize dummy security groups or synchronize on attributes that are not necessarily useful within the system. However, these approaches come with limitations, such as restricted triggering of events or the creation of audit trails that reflect the addition of fake access, rendering them ineffective or misleading.

# Objectives


# Architecture
![Alt text]("C:\Users\bradcar\OneDrive - CDW\Documents\Projects\Personal\QUEUE\queue-scripts\Task Queue for Scripts - Conceptual Role Add Process Flow.png")
1. Identity and Action Trigger:
    **Identity:** Represents the user or system whose attributes might change.
    **Action:** Some event triggers an action, such as a change in an identity attribute.
    **Data Source:** The origin of the information or trigger for this action.

2. IdentityNow Processing:

    Identity Attribute Changed: The identity's attributes are updated, which might include adding a new role or modifying existing ones.
    LCM / Role Added: This change leads to a Lifecycle Manager (LCM) event or a role being added to the identity.
    Access Item Grants Entitlement & Pushes Work Item: The system then grants the necessary entitlements (permissions, roles, etc.) and generates a work item to be processed by the task manager.

3. Task Management:

    IdentityNow Task Manager: The task manager within IdentityNow handles these work items, queuing them for further processing.
    Reads Work Item Queue Every X Minutes: A PowerShell task manager script regularly reads the work item queue to check for new tasks that need to be processed.

4. PowerShell Script Processing:

    PowerShell Task Manager Script: This script manages the execution of tasks. It reads the queue and determines what action is required.
    Executes Specified Script: Depending on the task, the script executes a specific PowerShell script to handle the role addition or any other required action.
    Writes Results to IdentityNow: Once the script has processed the task, it writes the results back to IdentityNow, completing the workflow.

This diagram represents a seamless integration between IdentityNow and external processing scripts, ensuring that role additions and similar tasks are efficiently managed and executed

# Objects

# Usage
## Delimited File Source
## 