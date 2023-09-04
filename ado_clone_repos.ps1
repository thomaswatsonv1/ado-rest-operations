# Clone an Azure DevOps Git repo
#Region Load file with details of repos 
Param (
    [string]$ParameterFile
)
# Load our functions
. .\helper_functions.ps1
# We will have a default file in the local folder
if ([string]::IsNullOrEmpty($ParameterFile)) { 
    $ParameterFile = ".\repos_to_clone.json"
}

# Check there is a file at the specified location and it is a json file
If (Test-Path $ParameterFile -PathType Leaf -Filter "*.json") {
    try {
        $reposToClone = (Get-Content -Path $ParameterFile)
    }
    catch {
        Write-Host "System error - Cannot get specified file. $($_.ErrorDetails)" -ForegroundColor Red
        Exit 1
    }
    Write-Host "File $($ParameterFile) loaded!" -ForegroundColor Green
}
else {
    Write-Host "The specified file does not exists or does not have a .json file type" -ForegroundColor Red
    Write-Host "Critical error. Exiting"
    Exit 1
}
#Endregion

# Make sure our try catch works as intended
$ErrorActionPreference = 'Stop'

# Azure DevOps Personal Access Token with appropriate permissions
$pat = ""

# ------------------ Main Body ------------------

$convertedObject = ($reposToClone | ConvertFrom-Json)
foreach ($repo in $convertedObject.repos) {

    $success = $true

    #Region Test the Supplied Azure DevOps organization and project details
    try {
        $suppliedInfo = Test-RepoValues($repo)
    }
    Catch {
        Write-Host "An error occurred when checking the supplied values." -ForegroundColor Red
        $success = $false
    }
    if ($suppliedInfo -eq -1) {
        $success = $false
    }
    else {
        $sourceOrganization = $suppliedInfo.sourceOrganization
        $sourceProject = $suppliedInfo.sourceProject
        $sourceRepo = $suppliedInfo.sourceRepo
        $destinationOrganization = $suppliedInfo.destinationOrganization
        $destinationProject = $suppliedInfo.destinationProject
        $destinationRepo = $suppliedInfo.destinationRepo
    }
    #Endregion

    #Region Check the Organizations exist
    $sourceOrgUri = [uri]::EscapeUriString("https://dev.azure.com/$sourceOrganization/_apis/projects?api-version=7.0")
    if (Test-Endpoint -suppliedUrl $sourceOrgUri) {
        Write-Host "Source Organization is valid"
        if ($sourceOrganization -ne $destinationOrganization) {
            $destOrgUri = [uri]::EscapeUriString("https://dev.azure.com/$destinationOrganization/_apis/projects?api-version=7.0")
            if (Test-Endpoint -suppliedUrl $destOrgUri) {
                Write-Host "Desitination Organization is valid"
            }
            else {
                Write-Host "Destination Organization is not valid"
                $success = $false
            }
        }
        else {
            Write-Host "Source and Destination organizations are the same. Both are valid."
        }
    }
    else {
        Write-Host "Source Organization is not valid skipping other checks."
        $Success = $False
    }
    #Endregion

    #Region Get Project Ids
    if ($success) {
        try {
            $sourceProjectId = Get-ProjectId -projectNameSupplied $sourceProject -organizationToGet $sourceOrganization
        }
        catch {
            Write-Host "Something went wrong trying to get a Project Id for the source project." -ForegroundColor Red
            Write-Host
            $success = $false
        }
        if ($sourceProjectId -eq -1) {
            $success = $false
            Write-Host "Couldn't get a valid Project Id from supplied values" -ForegroundColor Red
        }
        else {
            Write-Host "Project Id for $($sourceProject) is $($sourceProjectId)"
            Write-Host

            if ($sourceOrganization -ne $destinationOrganization) {
                try {
                    $destinationProjectId = Get-ProjectId -projectNameSupplied $destinationProject -organizationToGet $destinationOrganization
                }
                catch {
                    Write-Host "Cannot get the Project Id for the destination Project." -ForegroundColor Red
                    Write-Host
                    $success = $false
                }
                if ($destinationProjectId -eq -1) {
                    $success = $false
                    Write-Host "Couldn't get a valid Project Id from supplied values" -ForegroundColor Red
                }
                else {
                    Write-Host "Project id for $($destinationProject) is $($destinationProjectId)"
                }
            }
            else {
                Write-Host "Source and Destination Organizations are the same." -ForegroundColor Yellow
                if ($sourceProject -ne $destinationProject) {
                    try {
                        $destinationProjectId = Get-ProjectId -projectNameSupplied $destinationProject -organizationToGet $destinationOrganization
                        Write-Host "Project id for $($destinationProject) is $($destinationProjectId)"
                    }
                    catch {
                        Write-Host "Cannot get the Project Id for destination project. Are the values $($destinationOrganization) and $($destinationProject) correct?" -ForegroundColor Red
                        $success = $false
                    }
                }
                else {
                    Write-Host "Source and Destination Projects are the same." -ForegroundColor Yellow
                    $destinationProjectId = $sourceProjectId
                }
            }
        }
    }
    else {
        Write-Host "Organisation not valid so skipping other steps"
    }
    #Endregion

    #Region Get Repository Ids
    if ($success) {
        try {
            $sourceRepoId = Get-RepoId -projectNameSupplied $sourceProject -organizationToGet $sourceOrganization -repoToGet $sourceRepo
        }
        catch {
            Write-Host "Something went wrong trying get the source Repo Id. Does $($sourceRepo) exist?" -ForegroundColor Red
            # Write-Host "$($_.ErrorDetails) $($_.Exception)"
            $success = $false
        }
        if ($sourceRepoId -eq -1) {
            Write-Host "Cannot get Id for the source repository." -ForegroundColor Red
            $success = $false
        }
        else {
            Write-Host "Repository Id for $($sourceRepo) is $($sourceRepoId)"
        }
    }
    else {
        Write-Host "Previous checks failed, skipping the repo Id check"
    }

    # Look for a destinationRepo ID as if it exists we should skip creating it?
    if ($success) {

        try {
            $destinationRepoId = Get-RepoId -projectNameSupplied $destinationProject -organizationToGet $destinationOrganization -repoToGet $destinationRepo
        }
        catch {
            Write-Host "Something went wrong trying get the Destination Repo Id." -ForegroundColor Red
            # Write-Host "$($_.ErrorDetails) $($_.Exception)"
            $success = $false
        }
        if ($destinationRepoId -eq -1) {
            Write-Host "Destination repository can be created." -ForegroundColor Cyan
            $success = $true
        }
        else {
            Write-Host "Error: $($destinationRepo) already exists in the $($destinationProject) in the $($destinationOrganization) Organization." -ForegroundColor Red
            $success = $false
        }
    }
    #Endregion

    #Region Try and Clone
    if ($success) {

        # Time to create the json for the clone
        try {
            $jsonPayload = Convert-ToJsonPayload -destinationRepo $destinationRepo -destinationProjectId $destinationProjectId -sourceRepo $sourceRepo -sourceRepoId $sourceRepoId -sourceProjectId $sourceProjectId
        }
        catch {
            Write-Host "Could not create json payload." -ForegroundColor Red
            Exit 1
        }

        # Create a new Git repository in the target project
        $url = "https://dev.azure.com/$destinationOrganization/_apis/git/repositories/?api-version=7.0"
        
        $createRepoUrl = [uri]::EscapeUriString($url)

        # Write-Host $createRepoUrl
        if (Test-Endpoint -suppliedUrl $createRepoUrl) {
            # in the 'Authorization line, make sure its {0} RATHER THAN { 0 } - the latter doesn't work
            try {
                $result = Invoke-RestMethod -Uri $createRepoUrl -Method Post -Headers @{
                    Authorization  = ("Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pat)")))
                    "Content-Type" = "application/json"
                } -Body $jsonPayload

                if (($null -ne $result.id) -and ($result.name -eq $destinationRepo)) {
                    Write-Host "Repository cloned successfully!" -ForegroundColor Green
                }
            }
            catch {
                Write-Host "Failed to Clone repo" -ForegroundColor Red
                if ($null -ne $result) {
                    # Write-Host "See returned values below:"
                    #Write-Host $result
                }
                else {
                    Write-Host "No result from API call"
                    #Write-Host $_.ErrorDetails
                }
            }
        }
        else {
            Write-Output "Could not reach endpoint: $($createRepoUrl)"
            Write-Output "Did not try and create repo"
        }
    }
    else {
        Write-Host "Configuration not valid. Skipping repo creation." -ForegroundColor Yellow
    }
    Write-Host "-------------------------------------"
    #Endregion
}
# -------------------------- End of body