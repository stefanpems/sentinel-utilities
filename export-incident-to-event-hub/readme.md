This Logic App exports the triggering Sentinel incident to Event Hub. Before the export, the Logic App adds into the JSON the URL of the incident in the new Unified portal. The JSON of the incident includes the information related to the alerts and the entities of the incident.

All the details on how to deploy, configure and test this Logic App can be found here: https://www.linkedin.com/pulse/simple-logic-app-export-sentinel-incidents-event-hub-pescosolido-qs7wf/

## Deployment button
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fstefanpems%2Fsentinel-utilities%2Frefs%2Fheads%2Fmain%2Fexport-incident-to-event-hub%2Ftemplate.json)
