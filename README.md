# ado-rest-operations

Powershell script for interacting with Azure Devops. Uses REST API version 7 in most (if not all cases).

## ado-clone-repos.ps1

Takes a json parameter file as a commandline option. If this is not available it uses a default file located in the same directory called "repos_to_clone.json". If neither of these are not available or not valid json, the script will exit.

If any values are not supplied, the clone attempt will be skipped.

If there is a pre-existing repo with the same name as the inteded clone, the clone will be skipped.

If any of the endpoints cannot be reached, the script will try again, up to a maximum of five times before skipping the clone operation.

## repos_to_clone.json

This file has a very simple structure and if the source and destination organizations and projects are the same it is permissible to only put in the source organization and repo and the ado-clone-repos.ps1 will use these values for source and destination.
