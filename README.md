# ado-rest-operations

Powershell script for interacting with Azure Devops. Uses REST API version 7 in most (if not all cases).

## Clone ADO repositories

This process rewuires a valid P.A.T. token to be added and uses the following files:

### ado-clone-repos.ps1

Takes a json parameter file as a commandline option. If this is not available it uses a default file located in the same directory called "repos_to_clone.json". If neither of these are not available or not valid json, the script will exit.

If any values are not supplied, the clone attempt will be skipped.

If there is a pre-existing repo with the same name as the inteded clone, the clone will be skipped.

If any of the endpoints cannot be reached, the script will try again, up to a maximum of five times before skipping the clone operation.

### repos_to_clone.json

This file has a very simple structure and if the source and destination organizations and projects are the same it is permissible to only put in the source organization and repo and the ado-clone-repos.ps1 will use these values for source and destination.

### helper_functions.ps1

This file has a few functions that are useful for checking endpoints, creating json versions of ps objects etc. More will be added as other functions to interact with the ADO rest api are created.

## Create ADO pipelines

This will allow the creation of ADO pipelines via a powershell script. It requires the use of a valid P.A.T. token that has permissions over pipelines. It uses the following files:

## ado-create-pipeline.ps1

Takes a json parameter file as a commandline option. If this is not available it uses a default file located in the same directory called "pipelines_to_create.json". If neither of these are not available or not valid json, the script will exit.

If any values are not supplied, the create attempt will be skipped.

If there is a pre-existing pipeline with the same name as the inteded clone, the creation will be skipped.

If any of the endpoints cannot be reached, the script will try again, up to a maximum of five times before skipping the create operation.

## helper_functions.ps1

As above Coming soon:

## pipelines_to_create.ps1

Coming soon: json file that has the details the pipelines to create.
