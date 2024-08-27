$script:NAME = "Termination Script"
function Run-Action ($account) {
    try {
        $start = (Get-Date).toString("MM-dd-yyyy HH:mm:ss")
        Write-Log "$script:NAME has started."

        # Place Logic Here
        throw "Couldn't find user."

        Write-Log "$script:NAME has finished."
        return [RunResponse]::new("COMPLETED")
    } catch {
        return [RunResponse]::new("NO_RETRY", "($start) $_")
    }
}