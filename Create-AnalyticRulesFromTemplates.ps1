<#
.SYNOPSIS
The cmdlet Create-AnalyticRulesFromTemplates cmdlet automates the creation of Analytic Rules in Microsoft Sentinel.

.DESCRIPTION
   Version: 0.0.1
   Release Date: 2024-02-03
The cmdlet Create-AnalyticRulesFromTemplates creates the Analytic Rules based on the Analytic Rules Templates available 
in the Content Hub Solutions already installed in the Sentinel workspace. 
It's possible to filter out the Analytic Rules Templates to be considered by specifying the desired severities.
In an upcoming release, I'll add the possibility to specify in a CSV file which Analytic Rules Templates should (or should not) be considered.
The execution can be simulated, so that the script only logs what it would do but without doing any change to Sentinel.
The log file is created in the same local directory from where the script is launched. 

.EXAMPLE
#Set the parameters
$SubscriptionId = "<your-subscription-id>"
$ResourceGroup = "<your-sentinel-resource-group-name>"
$Workspace = "<your-sentinel-workspace-name>"
$Region = "<your-region>" #(e.g, westeurope)
$SeveritiesToInclude = @("High","Medium") #Can be empty
$SimulateOnly = $false #If $true, no change is made to Sentinel
$LimitToMaxNumberOfRules = 10 #For testing purposes, set a limit to the execution. Do not specify or leave it less or equal than zero to not set limits
#Optionally use -verbose

#Launch the cmdlet
Create-AnalyticRulesFromTemplates -SubscriptionId $SubscriptionId -ResourceGroup $ResourceGroup -Workspace $Workspace -Region $Region  `
    -SeveritiesToInclude $SeveritiesToInclude -Simulate $SimulateOnly  -LimitToMaxNumberOfRules $LimitToMaxNumberOfRules #-verbose

.NOTES
The script requires PowerShell 7. 
* Check the version of your powershell by using: $PSVersionTable.PSVersion
* Install it by launching: winget search Microsoft.PowerShell
(https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.4)

.AUTHOR
Stefano Pescosolido (https://www.linkedin.com/in/stefanopescosolido/)
Part of the code is taken from https://github.com/Azure/Azure-Sentinel/tree/master/Tools/Sentinel-All-In-One

#>

function CreateAuthenticationHeader {
    param (
        [Parameter(Mandatory = $true)][string]$TenantId,
        [Parameter(Mandatory = $false)][string]$PrefixInDisplayName
    )
    $instanceProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($instanceProfile)
    $token = $profileClient.AcquireAccessToken($TenantId)
    $authNHeader = @{
        'Content-Type'  = 'application/json' 
        'Authorization' = 'Bearer ' + $token.AccessToken 
    }

    return $authNHeader
}

function CreateAnalyticRule {
    param (
        [Parameter(Mandatory = $true)][string]$BaseUri,
        [Parameter(Mandatory = $true)][object]$Template,
        [Parameter(Mandatory = $false)][bool]$SimulateOnly = $true
    )
    
    $alertUri = "$BaseUri/providers/Microsoft.SecurityInsights/alertRules/"
    $BaseAlertUri = $BaseUri + "/providers/Microsoft.SecurityInsights/alertRules/"
    
    $kind = $Template.properties.mainTemplate.resources.kind
    $displayName = $Template.properties.mainTemplate.resources.properties[0].displayName
    $eventGroupingSettings = $Template.properties.mainTemplate.resources.properties[0].eventGroupingSettings
    if ($null -eq $eventGroupingSettings) {
        $eventGroupingSettings = [ordered]@{aggregationKind = "SingleAlert" }
    }
    $body = ""
    $properties = $Template.properties.mainTemplate.resources[0].properties
    $properties.enabled = $true
    #Add the field to link this rule with the rule template so that the rule template will show up as used
    #We had to use the "Add-Member" command since this field does not exist in the rule template that we are copying from.
    $properties | Add-Member -NotePropertyName "alertRuleTemplateName" -NotePropertyValue $Template.properties.mainTemplate.resources[0].name
    $properties | Add-Member -NotePropertyName "templateVersion" -NotePropertyValue $Template.properties.mainTemplate.resources[1].properties.version


    #Depending on the type of alert we are creating, the body has different parameters
    switch ($kind) {
        "MicrosoftSecurityIncidentCreation" {  
            $body = @{
                "kind"       = "MicrosoftSecurityIncidentCreation"
                "properties" = $properties
            }
        }
        "NRT" {
            $body = @{
                "kind"       = "NRT"
                "properties" = $properties
            }
        }
        "Scheduled" {
            $body = @{
                "kind"       = "Scheduled"
                "properties" = $properties
            }
            
        }
        Default { }
    }
    #If we have created the body...
    if ("" -ne $body) {
        #Create the GUId for the alert and create it.
        $guid = (New-Guid).Guid
        #Create the URI we need to create the alert.
        $alertUri = $BaseAlertUri + $guid + "?api-version=2022-12-01-preview"
        try {
            Write-Verbose -Message "Template: $displayName - Creating the rule...."
            
            if(-not($SimulateOnly)){
                $rule = Invoke-RestMethod -Uri $alertUri -Method Put -Headers $authHeader -Body ($body | ConvertTo-Json -EnumsAsStrings -Depth 50)
                Write-Host -Message "Template: $displayName - Creating the rule - Succeeded" -ForegroundColor Green  
                #This pauses for 1 second so that we don't overload the workspace.
                Start-Sleep -Seconds 1
            }
            else {
                Write-Host -Message "Template: $displayName - Creating the rule - Succeeded (SIMULATED)" -ForegroundColor Green  
            }
            
        }
        catch {
            Write-Verbose "Template: $displayName - ERROR while creating the rule:"
            Write-Verbose $_
            #Write-Host -Message "Template: $displayName - ERROR while creating the rule: $(($_).Exception.Message)" -ForegroundColor Red
            Write-Host -Message "Template: $displayName - ERROR while creating the rule" -ForegroundColor Red
            throw   
        }
    }

    return $rule
}

function LinkAnalyticRuleToSolution {
    param (
        [Parameter(Mandatory = $true)][string]$BaseUri,
        [Parameter(Mandatory = $true)][object]$Rule,
        [Parameter(Mandatory = $true)][object]$Template,
        [Parameter(Mandatory = $true)][object]$Solution,
        [Parameter(Mandatory = $false)][bool]$SimulateOnly = $true
    )

    $baseMetaURI = $BaseUri + "/providers/Microsoft.SecurityInsights/metadata/analyticsrule-"

    $metabody = @{
        "apiVersion" = "2022-01-01-preview"
        "name"       = "analyticsrule-" + $Rule.name
        "type"       = "Microsoft.OperationalInsights/workspaces/providers/metadata"
        "id"         = $null
        "properties" = @{
            "contentId" = $Template.properties.mainTemplate.resources[0].name
            "parentId"  = $Rule.id
            "kind"      = "AnalyticsRule"
            "version"   = $Template.properties.mainTemplate.resources.properties[1].version
            "source"    = $Solution.source
            "author"    = $Solution.author
            "support"   = $Solution.support
        }
    }
    Write-Verbose -Message "Rule: $(($Rule).displayName) - Updating metadata...."
    $metaURI = $baseMetaURI + $Rule.name + "?api-version=2022-01-01-preview"
    try {
        if(-not($SimulateOnly)){
            $metaVerdict = Invoke-RestMethod -Uri $metaURI -Method Put -Headers $authHeader -Body ($metabody | ConvertTo-Json -EnumsAsStrings -Depth 5)
            Write-Host -Message "Rule: $(($Rule).displayName) - Updating metadata - Succeeded" -ForegroundColor Green 
            #This pauses for 1 second so that we don't overload the workspace.
            Start-Sleep -Seconds 1 
        } else {            
            Write-Host -Message "Rule: $(($Rule).displayName) - Updating metadata - Succeeded (SIMULATED)" -ForegroundColor Green  
        }
              
    }
    catch {
        Write-Verbose "Rule: $(($Rule).displayName) - ERROR while updating metadata:"
        Write-Verbose $_
        #Write-Host -Message "Rule: $(($Rule).displayName) - ERROR while updating metadata: $(($_).Exception.Message)" -ForegroundColor Red
        Write-Host -Message "Rule: $(($Rule).displayName) - ERROR while updating metadata" -ForegroundColor Red
        throw
    }
    return $metaVerdict

}

function CheckIfAnAnalyticRuleAssociatedToTemplateExist {
    param (
        [Parameter(Mandatory = $true)][string]$BaseUri,
        [Parameter(Mandatory = $true)][object]$Template
    )

    $uri = $BaseUri + "/providers/Microsoft.SecurityInsights/alertRules?api-version=2022-01-01-preview"
    
    $allRules = (Invoke-RestMethod -Uri $uri -Method Get -Headers $authHeader).value
    
    $found = $false
    foreach($rule in $allRules){
        #Write-Debug $rule
        if($rule.properties.alertRuleTemplateName -eq $Template.properties.mainTemplate.resources[0].name){
            $found = $true
            break
        }
    }
    
    return $found

}

function Create-AnalyticRulesFromTemplates {
    param(
        [Parameter(Mandatory = $true)][string]$SubscriptionId,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$Workspace,
        [Parameter(Mandatory = $true)][string]$Region,
        [Parameter(Mandatory = $false)][bool]$SimulateOnly = $true,
        [Parameter(Mandatory = $false)][int]$LimitToMaxNumberOfRules = 0,
        [Parameter(Mandatory = $false)][string]$InputCsvFile,
        [Parameter(Mandatory = $false)][string[]]$SeveritiesToInclude = @("Informational", "Low", "Medium", "High")
    )

    if($PSVersionTable.PSVersion.Major -lt 7){
        Write-Host "This cmdlet requires PowerShell 7" -ForegroundColor Red
        exit
    }

    Write-Verbose "---------------------- START OF EXECUTION - $(Get-Date)" 
    Write-Verbose "SubscriptionId: $SubscriptionId"
    Write-Verbose "ResourceGroup: $ResourceGroup"
    Write-Verbose "Workspace: $Workspace"
    Write-Verbose "Simulate: $SimulateOnly"
    Write-Verbose "PrefixInDisplayName: $PrefixInDisplayName"
    Write-Verbose "SeveritiesToInclude: $SeveritiesToInclude"

    if($null -eq $SeveritiesToInclude){
        $SeveritiesToInclude = @("Informational", "Low", "Medium", "High")
    } 

    $LogStartTime = Get-Date -Format "yyyy-MM-dd_hh.mm.ss"
    $oLogFile = "log_$LogStartTime.log"
    "EXECUTION STARTED - $LogStartTime" | Out-File $oLogFile 
    
    # Authenticate to Azure
    Connect-AzAccount -DeviceCode | out-null

    # Set the current subscription
    $context = Set-AzContext -SubscriptionId $subscriptionId 

    # Get the Authentication Header for calling the REST APIs
    $authHeader = CreateAuthenticationHeader($context.Subscription.TenantId)

    # List all Solutions in Content Hub
    $baseUri = "https://management.azure.com/subscriptions/${SubscriptionId}/resourceGroups/${ResourceGroup}/providers/Microsoft.OperationalInsights/workspaces/${Workspace}"
    $packagesUrl = $baseUri + "/providers/Microsoft.SecurityInsights/contentProductPackages?api-version=2023-04-01-preview"
    $allSolutions = (Invoke-RestMethod -Method "Get" -Uri $packagesUrl -Headers $authHeader ).value
    Write-Verbose -Message "#Solutions: $(($allSolutions).Count)"; "#Solutions: $(($allSolutions).Count)" | Out-File $oLogFile -Append
    Start-Sleep -Seconds 1

    # List all Analytic Rule Templates which are part of the installed solutions
    $templatesUrl = $baseUri + "/providers/Microsoft.SecurityInsights/contentTemplates?api-version=2023-05-01-preview&%24filter=(properties%2FcontentKind%20eq%20'AnalyticsRule')"
    $allTemplates = (Invoke-RestMethod -Uri $templatesUrl -Method Get -Headers $authHeader).value
    Write-Verbose -Message "#Templates: $(($allTemplates).Count)"; "#Templates: $(($allTemplates).Count)" | Out-File $oLogFile -Append
    Start-Sleep -Seconds 1


    # Iterate through all the Analytic Rule Templates
    $NumberOfConsideredTemplates = 0
    $NumberOfSkippedTemplates = 0
    $NumberOfCreatedRules = 0
    $NumberOfErrors = 0
    foreach ($template in $allTemplates ) {

        $NumberOfConsideredTemplates++ | out-null

        # Make sure that the Template's severity is one we want to include
        $severity = $template.properties.mainTemplate.resources.properties[0].severity
        if ($SeveritiesToInclude.Contains($severity)) {

            try {
                #Check if at least an Analytic Rule associated at this templates already exists
                $found = CheckIfAnAnalyticRuleAssociatedToTemplateExist -BaseUri $baseUri -Template $template

                if(-not($found)){
                    # Create the Analytic Rule from the Template - NOTE: at this point it will have "Source name" = "Gallery Content"
                    "Template '$(($template).properties.displayName)' - About to create rule"  | Out-File $oLogFile -Append
                    $analyticRule = CreateAnalyticRule -BaseUri $baseUri -Template $template -SimulateOnly $SimulateOnly
                    "Template '$(($template).properties.displayName)' - Rule created sucessfully"  | Out-File $oLogFile -Append
                    
                    # Search for the solution containing the Template
                    $solution = $allSolutions.properties | Where-Object -Property "contentId" -Contains $template.properties.packageId

                    if($SimulateOnly){
                        #Simulate the result of the above command
                        $analyticRule = New-Object -TypeName PSObject -Property @{
                            name = ""
                            id = ""
                            displayName = $template.properties.mainTemplate.resources.properties[0].displayName
                        }
                        
                    }

                    # Modify the metadata of the Analytic Rule so that it is linked as "In use" in the Solution - NOTE: at this point it will have "Source name" = <Name of the solution>
                    "Template '$(($template).properties.displayName)' - About to modify metadata"  | Out-File $oLogFile -Append
                    $metadataChangeResult = LinkAnalyticRuleToSolution -BaseUri $baseUri -Rule $analyticRule -Template $template -Solution $solution -SimulateOnly $SimulateOnly
                    "Template '$(($template).properties.displayName)' - Metadata modified successfully"  | Out-File $oLogFile -Append

                    $NumberOfCreatedRules++ | out-null
                } else {
                    "Template '$(($template).properties.displayName)' - A rule already exists based on this template"  | Out-File $oLogFile -Append
                    $NumberOfSkippedTemplates++ | out-null
                }
            }
            catch {
                "Template '$(($template).properties.displayName)' - ERROR while creating the rule"  | Out-File $oLogFile -Append
                "-------------"  | Out-File $oLogFile -Append
                $_  | Out-File $oLogFile -Append
                "-------------"  | Out-File $oLogFile -Append
                $NumberOfErrors++ | out-null
            }
            
            if(($LimitToMaxNumberOfRules -gt 0) -and ($NumberOfCreatedRules -ge $LimitToMaxNumberOfRules)){
                break
            }
        } else {
            "Template skipped (severity: '$severity'): '$(($template).properties.displayName)'" | Out-File $oLogFile -Append
            $NumberOfSkippedTemplates++ | out-null
        }
    }

    
    Write-Verbose "---------------------- END OF EXECUTION - $(Get-Date)"

    Write-Host (" ") ; " " | Out-File $oLogFile -Append
    Write-Host ("### Summary:") -ForegroundColor Blue; "### Summary:"  | Out-File $oLogFile -Append
    Write-Host ("") -ForegroundColor Blue
    Write-Host ("  # of template processed: $NumberOfConsideredTemplates")  -ForegroundColor Blue; "  # of template processed: $NumberOfConsideredTemplates" | Out-File $oLogFile -Append
    if(-not($SimulateOnly)){
        Write-Host ("  # of rules created: $NumberOfCreatedRules")  -ForegroundColor Green; "  # of rules created: $NumberOfCreatedRules" | Out-File $oLogFile -Append
    } else {        
        Write-Host ("  # of rules created (SIMULATED): $NumberOfCreatedRules")  -ForegroundColor Green; "  # of rules created (SIMULATED): $NumberOfCreatedRules" | Out-File $oLogFile -Append
    }
    Write-Host ("  # of rules not created because of errors: $NumberOfErrors")  -ForegroundColor Red; "  # of rules not created because of errors: $NumberOfErrors" | Out-File $oLogFile -Append
    Write-Host ("  # of template skipped: $NumberOfSkippedTemplates")  -ForegroundColor Gray; "  # of template skipped: $NumberOfSkippedTemplates" | Out-File $oLogFile -Append
    Write-Host ("") -ForegroundColor Blue

    "EXECUTION ENDED - $LogStartTime" | Out-File $oLogFile -Append
    Write-Host "Please check the log file for details: '$oLogFile'" -ForegroundColor Blue

}

###############################################################################
# Launching section

# Set the environment variables
$SubscriptionId = "<your-subscription-id>"
$ResourceGroup = "<your-sentinel-resource-group-name>"
$Workspace = "<your-sentinel-workspace-name>"
$Region = "<your-region>" #(e.g, westeurope)
$SeveritiesToInclude = @("High","Medium") #Can be empty
$SimulateOnly = $false #If $true, no change is made to Sentinel
$LimitToMaxNumberOfRules = 10 #For testing purposes, set a limit to the execution. Do not specify or leave it less or equal than zero to not set limits

Create-AnalyticRulesFromTemplates -SubscriptionId $SubscriptionId -ResourceGroup $ResourceGroup -Workspace $Workspace -Region $Region  `
    -SeveritiesToInclude $SeveritiesToInclude -Simulate $SimulateOnly  -LimitToMaxNumberOfRules $LimitToMaxNumberOfRules #-verbose