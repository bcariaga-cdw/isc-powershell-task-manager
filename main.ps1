$script:SCRIPT_PATH = "C:\SailPoint\SailPoint Scripts"

$runtime = Measure-Command -Expression { 
    try {
        # Declare Global Script Variables
        $script:GLOBAL_CONFIG = (Get-Content -path "$($script:SCRIPT_PATH)\config.json" | ConvertFrom-Json)

        $script:LOG_FILE_NAME = "$($script:SCRIPT_PATH)\log\$((Get-Date).toString("MM-dd-yyyy_HHmmss"))_$($script:GLOBAL_CONFIG.General.logFileName).log"

        # Import Log Method
        . "$($script:SCRIPT_PATH)\dist\util\Write-Log.ps1"
        Write-Log "Loading script dependencies..."

        # Import necessary helper functions
        foreach ($file in Get-ChildItem "$script:SCRIPT_PATH\dist" -Recurse) {
            if ($file.PSIsContainer -or $file.Name -eq "Write-Log.ps1") { continue }
            Write-Log "Importing file $($file.Name)."
            . "$($file.FullName)"
        }

        Load-Module "PSSailPoint" $script:GLOBAL_CONFIG.General.sdkVersion

        # Set PAT environment variables.
        Load-Token
    }
    catch {
        Write-Log "Unable to load script: $_" 1
        exit
    }

    try {
        Write-Log "Starting script processing..."

        $script:STATS = @{
            tasks = [System.Collections.ArrayList] @()
            actions = [System.Collections.ArrayList] @()
        }

        $allTasks = [System.Collections.ArrayList](@(Get-PaginatedAndCache "work-items" Get-WorkItems @{} $false))

        $tasksRun = [System.Collections.ArrayList]@()

        if ($allTasks.Count -gt 0) {
            foreach ($task in $allTasks.ToArray()) {
                Write-Log "Processing task $($task.id)"
                $myTask = @{
                    id = $null
                    actions = [System.Collections.ArrayList] @()
                    statuses = [System.Collections.ArrayList] @()
                    transactions = [System.Collections.ArrayList] @()
                    errors = [System.Collections.ArrayList] @()
                }

                $operation = $null
                $canClose = $true
                $actionToRemove = [System.Collections.ArrayList]@()
                foreach ($approvalItem in $task.approvalItems) {
                    # Check if correct source
                    if ($approvalItem.application -ne $script:GLOBAL_CONFIG.Script.applicationName + " [source]") { continue }       
                    # ensure is pending, add/create operation, and action
                    if ($approvalItem.name -eq "action" -and $approvalItem.operation -ne "Create" -and $approvalItem.operation -ne "Add" -and $approvalItem.state -eq "PENDING" -and $approvalItem.operation -ne "Remove") { continue }
                    
                    # ensure we haven't run this before (duplicate prevention)
                    if ($tasksRun.Contains($approvalItem.value + ":" + $approvalItem.account)) { continue }

                    # Add statistics measurements.
                    if (-not $script:STATS.tasks.Contains($task.id)) { [void] $script:STATS.tasks.Add($task.id) }
                    [void] $script:STATS.actions.Add("$($task.id)-$($approvalItem.value)")

                    $myTask.id = $approvalItem.account

                    Write-Log "$($task.description)" 3

                    $operation = $approvalItem.operation

                    # Find Current Account, if exists
                    $currentAccount = Get-Accounts -Filters "sourceId eq `"$($script:GLOBAL_CONFIG.Script.sourceId)`" and nativeIdentity eq `"$($myTask.id)`""

                    $currentStatus = $null
                    if ($null -eq $currentAccount) {
                        Write-Log "Current account could not be found" 1
                    } else {
                        # Check status of value
                        foreach ($status in $currentAccount.attributes.statuses) {
                            $action = $status.split(":")[0]
                            $currStatus = ($status.split(":")[1]).Replace(" ", "")
                            if ($action -eq $approvalItem.value) {
                                $currentStatus = $currStatus
                                break
                            }
                        }
                    }

                    if ($operation -eq "Remove" -and $null -ne $currentAccount) {
                        [void] $mytask.statuses.Add("$($approvalItem.value): RESET")
                        [void] $myTask.transactions.Add("$($approvalItem.value) (reset): $((Get-Date).toString("MM-dd-yyyy HH:mm:ss")) - $($(Get-Date).toString("MM-dd-yyyy HH:mm:ss"))")
                        [void] $actionToRemove.Add($approvalItem.value)
                        Write-Log "Removing $($approvalItem.value) from the record."
                        continue
                    }
                    
                    # Don't run if this item is already completed.
                    if ($currentStatus -eq "NO_RETRY" -or $currentStatus -eq "COMPLETED") {
                        continue
                    }

                    try {
                        $start = (Get-Date).toString("MM-dd-yyyy HH:mm:ss")
                        [void] (. "$($SCRIPT_PATH)\scripts\$($script:GLOBAL_CONFIG.Script.actions."$($approvalItem.value)")")
                        $run = Run-Action $myTask.id
                        $end = (Get-Date).toString("MM-dd-yyyy HH:mm:ss")

                        Write-Log ($run | Out-String) 3

                        if ($run.status -eq "NO_RETRY" -or $run.status -eq "COMPLETED") { 
                            [void] $myTask.actions.Add($approvalItem.value)
                        } else {
                            $canClose = $false
                        }
                        [void] $mytask.statuses.Add("$($approvalItem.value): $($run.status)")
                        [void] $myTask.transactions.Add("$($approvalItem.value) ($(if ($run.status -ne "ERROR" -and $run.status -ne "NO_RETRY") {"pass"} else {"fail"})): $($start) - $($end)")
                        if ($run.error) { [void] $myTask.errors.Add("$($approvalItem.value): $($run.error)") }
                    } catch {
                        Write-Log "Script failed:" 1
                        Write-Log $_ 1

                        [void] $mytask.statuses.Add("$($approvalItem.value): NO_RETRY")
                        [void] $myTask.transactions.Add("$($approvalItem.value) (fail): $($_.Exception.transaction.start) - $($_.Exception.transaction.end)")
                        [void] $myTask.errors.Add("$($approvalItem.value): $($_.Exception.msg)")
                    }
                }
                
                if ($myTask.id -eq $null) { continue }

                $currentAccount = Get-Accounts -Filters "sourceId eq `"$($script:GLOBAL_CONFIG.Script.sourceId)`" and nativeIdentity eq `"$($myTask.id)`""

                if ($operation -eq "Create" -and $null -eq $currentAccount) {
                    Write-Log "Creating IDN record for $($myTask.id): $($myTask.actions -join ",")"
                    Write-Log ($myTask | Out-String) 3

                    $myTask.sourceId = $script:GLOBAL_CONFIG.Script.sourceId

                    if ($myTask.errors.Count -eq 0) {
                        $myTask.Remove("errors")
                    }

                    $accountAttributesCreate = Initialize-AccountAttributesCreate -Attributes $myTask
                    $res = New-Account -AccountAttributesCreate $accountAttributesCreate

                    Write-Log "Created account with id $($res.id)"
                } else {
                    Write-Log "Updating IDN record for $($myTask.id): $($myTask.actions -join ",")"

                    if ($null -eq $currentAccount) {
                        Write-Log "Current account could not be found" 1
                        continue
                    }

                    $myTask.actions = @($($myTask.actions; ($currentAccount.attributes.actions | Where-Object { $null -ne $_ -and -not $actionToRemove.Contains($_) })))
                    $myTask.transactions = @($($myTask.transactions; ($currentAccount.attributes.transactions | Where-Object { $null -ne $_ })))
                    $mytask.statuses = @($($mytask.statuses; ($currentAccount.attributes.statuses | Where-Object { $null -ne $_ -and -not ($mytask.statuses -join ",").Contains(($_ -split ":")[0]) })))
                    $myTask.errors = @($($myTask.errors; ($currentAccount.attributes.errors | Where-Object { $null -ne $_ })))

                    Write-Log ($myTask | Out-String) 3

                    $attributes = Initialize-AccountAttributes -Attributes $myTask
                    $res = Send-Account -Id $currentAccount.id -AccountAttributes $attributes

                    Write-Log "Updated account id $($myTask.id)"
                }

                if ($canClose -eq $true) {
                    $res = Close-WorkItem -Id $task.id 
                    Write-Log "Work item $($res.id) has been closed."
                } else {
                    Write-Log "One or more actions failed and will be retried. The work item $($res.id) will not be closed."
                }

                [void] $tasksRun.Add($approvalItem.value + ":" + $approvalItem.account)
            }

            Write-Log "Finished processing $($script:STATS.tasks.Count) tasks with $($script:STATS.actions.Count) actions"
            if ($script:STATS.tasks.Count -gt 0) { Write-Log "Tasks Processed:`n$($script:STATS.tasks -join ",")" 3 }
            if ($script:STATS.actions.Count -gt 0) { Write-Log "Actions Processed:`n$($script:STATS.actions -join ",")" 3 }
        }
        else {
            Write-Log "No tasks found."
        }

        Write-Log "Finished script processing."
    }
    catch {
        Write-Log ($_ | Out-String) 1
    }

}

Write-Log "The script took $($runtime.ToString("c")) to finish."