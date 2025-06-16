# Incident Lifecycle Automation - Fixed State Diagram - Sample Prototype

This folder contains a prototype of incident lifecycle automation for Sentinel incidents. Specifically, the folder contains 2 Workflow templates (Azure Logic App) to implement the automation described in [Incident Lifecycle Automation in the Microsoft Unified Security Operations Platform](https://www.linkedin.com/pulse/incident-lifecycle-automation-microsoft-unified-stefano-pescosolido-yro9f/)

This is an automation based on a fixed state diagram, as described in the article.

## Installation Steps

* If not already available, create 3 Entra groups representing SOC Tiers 3, 2, and 1.

  NOTE: In this implementation, Tier 3 is considered the entry level of the SOC, i.e., the lowest in the hierarchy. Escalation proceeds to Tier 2 and then Tier 1. If you wish to change the numerical order of escalation for the 3 tiers, you must modify the logic app `UpdatedInvestigationFlow`, specifically the switch condition on the current Tier in the logical branch related to the escalate action.

* Prepare the SharePoint list used as storage for investigations. Columns:
  - Title (Single line of text)
  - Main Incident (Hyperlink or Picture)
  - Status (Choice - Possible values: New, Assigned, Closed)
  - Tier (Choice - Possible values: T3, T2, T1)
  - Assigned to (Person or Group)
  - Tasks (Lookup - Allow Multiple Choice)
  - Action (Choice - Possible values: None, Assign, Escalate, Close, Reopen)
  - Notes (Multiple lines of text)
  - Incident ARM ID (Single line of text)
  - Classification (Choice - Possible values: BenignPositive - SuspiciousButExpected, FalsePositive - InaccurateData, FalsePositive - IncorrectAlertLogic, TruePositive - SuspiciousActivity, Undetermined)

  NOTES:
  - The Tasks column of type Lookup must point to the Tasks list. Therefore, it can only be created after the Tasks list has been created.
  - In this list, create 3 custom views filtering by Status not equal to Closed and Tier equal to T3, T2, and T1 respectively. Name these views T3, T2, and T1. The corresponding URL must be saved as the access URL to the investigations list for Tier 3, 2, and 1 operators respectively.
  - You may, if desired, change the field order as they appear in the T3, T2, and T1 views and in the data entry forms.
  - It is possible and recommended to modify the data display form (Configure Layout / Body) so that the fields Status, Title, Main Incident, and Incident ARM ID are read-only.

* In the same SharePoint site collection, prepare the SharePoint list used as storage for tasks. Columns:
  - Title (Single line of text)
  - Assigned to (Person or Group)
  - Due date (Date and Time)
  - Instructions (Multiple lines of text)
  - Notes (Multiple lines of text)
  - Completed (Yes/No)
  - Investigation (Lookup)

  NOTES:
  - The Investigation column of type Lookup must point to the Investigations list. Therefore, it can only be created after the Investigations list has been created.
  - In this list, create 3 custom views filtering by appropriate criteria.
  - You may, if desired, change the field order as they appear in the views and in the data entry forms.

* Install the two logic apps using the templates published here - Use these two links:

  1. [![Deploy NewIncidentFlow to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fstefanpems%2Fsentinel-utilities%2Frefs%2Fheads%2Fmain%2Fincident-lifecycle-automation%2Ffixed-state-diagram%2Fincident-lifecycle-NewIncidentFlow-azuredeploy.json)

  2. [![Deploy UpdatedInvestigationFlow to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fstefanpems%2Fsentinel-utilities%2Frefs%2Fheads%2Fmain%2Fincident-lifecycle-automation%2Ffixed-state-diagram%2Fincident-lifecycle-UpdatedInvestigationFlow-azuredeploy.json)

  NOTE: In the deployment parameters of the two logic apps, use the references to the groups and lists created as described above.

* For each logic app:
  - Assign the corresponding Managed Identity the role of Microsoft Sentinel Responder on the resource group or Sentinel workspace
  - Authorize the API connection to Office 365 / SharePoint Online
  - Verify the correctness of the parameters; modify their values if necessary
 
* Authorize Sentinel / Defender XDR to run the Logic App NewIncidentFlow
