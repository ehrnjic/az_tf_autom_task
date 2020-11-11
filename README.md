# Teraforming AzureCloud Infrastructure

This code is "terraforming" infrastructure on Azure Cloud service to run simple dotnet web application with database (https://github.com/ehrnjic/dotnetcore-sqldb-web-app). Here you can find the terraform code https://github.com/ehrnjic/az_tf_autom_task. I wrote the whole terraform code in one `main.tf` file, but it can be divided into separate files (variables, resources, outputs, etc.) when we have more complex implementations.

Prerequisites:

- Azure Subscription (free account)

- Azure DevOps Organization (basic plan)

- Terraform v0.13.5

- Azure CLI v2.14.0

- .NET

## RUN Terraform Code 

To run this code clone this repo into your local. First run `terraform init` to initialize terraform. If you want to see the changes that terraform will make, run the `terraform plan` command. And finally, if you are satisfied with the terraform plan, run the `terraform apply` command that will start creating the infrastructure on your azure subscription. Confirm the execution by typing `yes` after the question "Do you want to perform these actions?"

After executing this code, the following new resources will be created on your Azure subscription:

- Resource Group = `rg-ehr-test` 
- SQL Server = `sql-ehr-test-01` and firewall rule to allow access to server
- Database = `db-ehr-test-01`
- Azure Container registry = `crehrtest`
- App Service plan = `asp-ehr-test`
- WebApp Service for containers = `appehrtest`

## Data migrations

In order to auto apply migrations on startup, I've modified Startup.cs class to initiate process of auto migrations. One thing to note is that migrations on repo seem to target some other sql engine and produce error when ran against MS SQL server. To fix the issue I deleted existing Migrations folder and generated new one. After this, migrations started passing against MS SQL server.

## CI/CD Pipeline

In my organization on Azure DevOps, I created public pipeline https://dev.azure.com/ehrnjic-org/devops-task to automate the build and deployment process. Build pipeline is configured to use my github repo https://github.com/ehrnjic/dotnetcore-sqldb-web-app as SCM, Build Docker container with app, tag container with release number and tag "latest", and push that container to Azure Container Registry `crehrtest`. Build pipeline will be triggered when commit a new release in the master branch or manually through the Azure DevOps portal. Application deployment is triggered by webhook.

Pipeline YAML configuration file (azure-pipelines.yml):

    # Docker
    # Build and push an image to Azure Container Registry
    # https://docs.microsoft.com/azure/devops/pipelines/languages/docker
    
    trigger:
    - master
    
    resources:
    - repo: self
    
    variables:
      # Container registry service connection established during pipeline creation
      dockerRegistryServiceConnection: 'dd01c30b-08f3-469b-af18-39f72fdd8e72'
      imageRepository: 'ehrnjicdotnetcoresqldbwebapp'
      containerRegistry: 'crehrtest.azurecr.io'
      dockerfilePath: '$(Build.SourcesDirectory)/Dockerfile'
      tag: '$(Build.BuildId)'
      
      # Agent VM image name
      vmImageName: 'ubuntu-latest'
    
    stages:
    - stage: Build
      displayName: Build and push stage
      jobs:  
      - job: Build
        displayName: Build
        pool:
          vmImage: $(vmImageName)
        steps:
        - task: Docker@2
          displayName: Build and push an image to container registry
          inputs:
            command: buildAndPush
            repository: $(imageRepository)
            dockerfile: $(dockerfilePath)
            containerRegistry: $(dockerRegistryServiceConnection)
            tags: |
              $(tag)
              latest


## Access to application
Few minutes after triggering pipeline you can check if the application is up&running on this URL https://appehrtest.azurewebsites.net/. Be patient, this is free tier :-)