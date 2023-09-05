# clone helper - functions to aid in cloning and copying ADO repos

# Get a Project Id
function Get-ProjectId {
    Param (
        [Parameter(Mandatory = $true)]
        [string]$projectNameSupplied, 
        
        [Parameter(Mandatory = $true)]
        [string]$organizationToGet
    )

    $projectId = ""

    # Azure DevOps REST API endpoint for listing repositories
    $uri = "https://dev.azure.com/$organizationToGet/_apis/projects?api-version=7.0"
    
    $escapedUrl = [uri]::EscapeUriString($uri)

    if (Test-Endpoint $escapedUrl) {

        # Make the REST API call to list repositories
        $response = Invoke-RestMethod -Uri $escapedUrl -Headers @{
            Authorization = ("Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pat)")))
        }

        $projectList = $response

        # Output the list of Ids
        if ($response.value.Count -gt 0) {
            Write-Host "$($response.value.Count) Projects found in $($organizationToGet):" -ForegroundColor Yellow
            $projectList.value | ForEach-Object {
                if ($_.name -eq $projectNameSupplied) {
                    $projectId = $_.id
                }
            }

            if ([string]::IsNullOrEmpty($projectId)) {
                Write-Host "No Id found for $($projectNameSupplied)" -ForegroundColor Red
                Write-Host
                return -1
            }
            else {
                Write-Host "Project Id found!" -ForegroundColor Green
                return $projectId
            }
        }
        else {
            else {
                Write-Host "No Projects found in $($organizationToGet)." -ForegroundColor Red
                return -1
            }
        }
    }
    else {
        Write-Host "Cannot reach endpoint $($escapedUrl)" - -ForegroundColor Red
        return -1
    }
}

# Get Repo Id
function Get-RepoId {
    Param (
        [Parameter(Mandatory = $true)]
        [string]$projectNameSupplied, 
        
        [Parameter(Mandatory = $true)]
        [string]$organizationToGet,

        [Parameter(Mandatory = $true)]
        [string]$repoToGet
    )

    $repoId = ""
    
    # Azure DevOps REST API endpoint for listing repositories
    $uri = "https://dev.azure.com/$organizationToGet/_apis/git/repositories?api-version=7.0"


    if (-not [string]::IsNullOrEmpty($projectNameSupplied)) {
        $uri = "https://dev.azure.com/$organizationToGet/$projectNameSupplied/_apis/git/repositories?api-version=7.0"
    }

    $escapedUrl = [uri]::EscapeUriString($uri)
    
    # Write-Host "Endpoint to get repo Ids is $($escapedUrl)" -ForegroundColor Yellow
    if (Test-Endpoint -suppliedUrl $escapedUrl) {
        # Make the REST API call to list repositories
        $response = Invoke-RestMethod -Uri $escapedUrl -Headers @{
            Authorization = ("Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pat)")))
        }

        # Output the list of repositories
        if ($response.value.Count -gt 0) {
            # Write-Host "$($response.value.Count) Repositories found in $($organizationToGet) - $($projectNameSupplied):"
            $response.value | ForEach-Object {
                # Write-Host $_.name
                if ($_.name -eq $repoToGet) {
                    $repoId = $_.id
                }
            }

            Write-Host
            if ([string]::IsNullOrEmpty($repoId)) {
                Write-Host "No Repository Id found for $($repoToGet) in $($projectNameSupplied)" -ForegroundColor Red
                return -1
            }
            else {
                Write-Host "Repository Id found!" -ForegroundColor Green
                return $repoId
            }
        }
        else {
            Write-Host "No repositories found in $organization $($project)." -ForegroundColor Red
            return -1
        }
    }
    else {
        Write-Host "Failed to get Repository Id Endpoint."
        return -1
    }

}

# Test Created Endpoints
function Test-Endpoint {
    param(
        # Parameter help description
        [Parameter(Mandatory)]
        [string]$suppliedUrl
    )

    $valid = $false
    $times = 0

    # $escapedUrl = [uri]::EscapeUriString($suppliedUrl)

    # Write-Host "Endpoint to test: $($suppliedUrl)"

    while (($false -eq $valid) -and ($times -lt 5)) {

        try {
            $checkedUrl = Invoke-WebRequest -Uri $suppliedUrl -Method Get -UseBasicParsing
        }
        catch {
            Write-Host "Endpoint not available"
        }
        # Write-Host $checkedUrl.StatusCode
    
        if (($checkedUrl.StatusCode -gt 199) -and ($checkedUrl.StatusCode -lt 300)) {
            # Write-Host "We got a good response $($checked.StatusDescription)"
            $valid = $true
        }
        else {
            
            Write-Host "Failed to get Endpoint. Trying again." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
        $times ++
    }
    if ($times -gt 1) {
        Write-Host "No response after $($times) tries. Connection or site may be down. Check supplied values" -ForegroundColor Red
    }
    return $valid
}

# Get Values for Repo from Json Object
function Test-RepoValues([object]$repoToCheck) {

    if ([string]::IsNullOrEmpty($repoToCheck.sourceOrganization)) {
        Write-Host "Values for Source Organization MUST be supplied" -ForegroundColor Red
        return -1
    }
    if ([string]::IsNullOrEmpty($repoToCheck.sourceProject)) {
        Write-Host "Values for Source Project MUST be supplied" -ForegroundColor Red
        return -1
    }
    if ([string]::IsNullOrEmpty($repoToCheck.sourceRepo)) {
        Write-Host "Values for Source Repository MUST be supplied" -ForegroundColor Red
        return -1
    }
    if ([string]::IsNullOrEmpty($repoToCheck.destinationOrganization)) {
        $repoToCheck.destinationOrganization = $repoToCheck.sourceOrganization
        Write-Host "Values for Destination Organization not supplied"
        Write-Host "Source Organization value, $($repoToCheck.sourceOrganization), will be used." -ForegroundColor Yellow    
    }
    if ([string]::IsNullOrEmpty($repoToCheck.destinationProject)) {
        if ($repoToCheck.sourceOrganization -eq $repoToCheck.destinationOrganization) {
            $repoToCheck.destinationProject = $repoToCheck.sourceProject
            Write-Host "Values for Destination Project not supplied"
            Write-Host "Source Organization value, $($repoToCheck.sourceProject), will be used." -ForegroundColor Yellow
        }
        else {
            Write-Host "No value for the destination project has been supplied"
            Write-Host "Source and Destination Organizations do not match..."
            Write-Host "I do not know where to put the repo."
            return -1
        }
    }
    if ([string]::IsNullOrEmpty($repoToCheck.destinationRepo)) {
        Write-Host "Values for intended destination (aka new repository name) MUST be supplied"
        return -1
    }
    if (($repoToCheck.sourceOrganization -eq $repoToCheck.destinationOrganization) -and ($repoToCheck.sourceProject -eq $repoToCheck.destinationProject) -and ($repoToCheck.sourceRepo -eq $repoToCheck.destinationRepo)) {
        Write-Host "Source and Destination values are the same. You are trying to clone a repository into the same repository." -ForegroundColor Red
        return -1
    }
    return $repoToCheck
}

# Package Json Payload
function Convert-ToJsonPayload {
    Param (
        [Parameter(Mandatory = $true)]
        [string]$destinationRepo, 
        
        [Parameter(Mandatory = $true)]
        [string]$destinationProjectId,

        [Parameter(Mandatory = $true)]
        [string]$sourceRepo,

        [Parameter(Mandatory = $true)]
        [string]$sourceRepoId,

        [Parameter(Mandatory = $true)]
        [string]$sourceProjectId
    )

    $destinationId = [PSCustomObject]@{
        id = $destinationProjectId
    }

    $sourceProject = [PSCustomObject]@{
        id = $sourceProjectId
    }
    
    $parentRepository = [PSCustomObject]@{
        name    = $sourceRepo
        id      = $sourceRepoId
        project = $sourceProject
    }
    
    $complete = [PSCustomObject]@{
        name             = $destinationRepo
        project          = $destinationId
        parentRepository = $parentRepository
    }

    $converted = $complete | ConvertTo-Json
    
    return $converted
}
