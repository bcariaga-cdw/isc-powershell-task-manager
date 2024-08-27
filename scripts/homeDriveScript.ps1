$script:NAME = "Home Drive Script"
function Run-Action ($account, $start) {
    try {
        $start = (Get-Date).toString("MM-dd-yyyy HH:mm:ss")
        Write-Log "$script:NAME has started."

        # Place Logic Here
        #Start-Sleep 30
        throw "Error Occured"

        Write-Log "$script:NAME has finished."
        return [RunResponse]::new("COMPLETED")
    } catch {
        return [RunResponse]::new("ERROR", "($start) $_")
    }
}