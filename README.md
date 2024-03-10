My stuff for managing Microsoft Sentinel.

SentinelAnalyticRulesManagementScript.ps1 is a script containing cmdlets that automates the massive creation, backup, deletion and update of Analytic Rules in Microsoft Sentinel.
Ideas for its improvement / evolution:
1. Change the authentication flow (do not use Device Code flow)
2. Export as json ARM template files any kind of rule - Not only the rules related to the templates installed from Content Hub solutions
3. Restore rules from their json ARM template files
4. Update installed solutions in Content Hub
5. Install specified solutions in Content Hub

...

VerifyConditionalAccessImpact is a 𝐊𝐐𝐋 query to list which Conditional Access Policies in "Report-only" mode  would have forced MFA or blocked the sign-ins if they were set to "On".
It requires the SigninLogs from Microsoft Entra to be collected in Sentinel
