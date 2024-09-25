# Define a readable name for this script.
$script:NAME = "Template Script"
function Run-Action ($account, $startTime) {
    try {
        Write-Log "$script:NAME has started."

        # DO SCRIPT LOGIC

        Write-Log "$script:NAME has finished."

        # Return a success status.
        return [RunResponse]::new("COMPLETED")
    } catch {
        # Return an error status (NO_RETRY or ERROR)
        return [RunResponse]::new("ERROR", "($startTime) $_")
    }
}