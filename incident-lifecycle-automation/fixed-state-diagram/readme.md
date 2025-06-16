# Incident Lifecycle Automation with Azure Logic Apps

Questo repository contiene i template dei workflow (Azure Logic App) per realizzare l'automazione descritta nell'articolo [Incident Lifecycle Automation in the Microsoft Unified Security Operations Platform](https://www.linkedin.com/pulse/incident-lifecycle-automation-microsoft-unified-stefano-pescosolido-yro9f/).

L'automazione segue un diagramma di stato fisso, come descritto nell'articolo.

## Installazione

### 1. Creazione dei Gruppi Entra

Creare 3 gruppi Entra rappresentativi dei Tier 3, 2 e 1 del SOC.

> **Nota:** In questa implementazione, il Tier 3 è considerato l'entry level del SOC, ovvero il più basso nella gerarchia. Si scala al Tier 2 e quindi al Tier 1. Se si desidera cambiare l'ordine numerico dell'escalation per i 3 tier, è necessario modificare la logic app `UpdatedInvestigationFlow`, in particolare la condizione di switch sul Tier attuale presente nel ramo logico relativo all'action di escalate.

### 2. Lista SharePoint per le Investigations

Creare una lista SharePoint con le seguenti colonne:

- `Title` (Single line of text)
- `Main Incident` (Hyperlink or Picture)
- `Status` (Choice - Valori: New, Assigned, Closed)
- `Tier` (Choice - Valori: T3, T2, T1)
- `Assigned to` (Person or Group)
- `Tasks` (Lookup - Allow Multiple Choice)
- `Action` (Choice - Valori: None, Assign, Escalate, Close, Reopen)
- `Notes` (Multiple lines of text)
- `Incident ARM ID` (Single line of text)
- `Classification` (Choice - Valori: 
  - BenignPositive - SuspiciousButExpected
  - FalsePositive - InaccurateData
  - FalsePositive - IncorrectAlertLogic
  - TruePositive - SuspiciousActivity
  - Undetermined)

> **Note:**
> - La colonna `Tasks` deve puntare alla lista `Tasks`, quindi può essere creata solo dopo la creazione di quest'ultima.
> - Creare 3 viste personalizzate filtrando per `Status` diverso da `Closed` e `Tier` uguale a T3, T2 e T1. Chiamare queste viste `T3`, `T2` e `T1`.
> - È possibile modificare l'ordine dei campi nelle viste e nei form.
> - È consigliato rendere `Status`, `Title`, `Main Incident` e `Incident ARM ID` di sola lettura nella visualizzazione dati.

### 3. Lista SharePoint per i Tasks

Creare una lista SharePoint con le seguenti colonne:

- `Title` (Single line of text)
- `Assigned to` (Person or Group)
- `Due date` (Date and Time)
- `Instructions` (Multiple lines of text)
- `Notes` (Multiple lines of text)
- `Completed` (Yes/No)
- `Investigation` (Lookup)

> **Note:**
> - La colonna `Investigation` deve puntare alla lista `Investigations`, quindi può essere creata solo dopo la creazione di quest'ultima.
> - È possibile modificare l'ordine dei campi nelle viste e nei form.

### 4. Installazione delle Logic App

Utilizzare i seguenti link per installare le due logic app:

1. [![Deploy NewIncidentFlow to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fstefanpems%2Fsentinel-utilities%2Frefs%2Fheads%2Fmain%2Fincident-lifecycle-automation%2Ffixed-state-diagram%2Fincident-lifecycle-NewIncidentFlow-azuredeploy.json)

2. [![Deploy UpdatedInvestigationFlow to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fstefanpems%2Fsentinel-utilities%2Frefs%2Fheads%2Fmain%2Fincident-lifecycle-automation%2Ffixed-state-diagram%2Fincident-lifecycle-UpdatedInvestigationFlow-azuredeploy.json)

> **Nota:** Nei parametri di deployment delle logic app, utilizzare i riferimenti ai gruppi e alle liste creati nei passaggi precedenti.

### 5. Configurazione delle Logic App

Per ciascuna logic app:

- Assegnare alla Managed Identity il ruolo di **Microsoft Sentinel Responder** sul resource group o sul workspace di Sentinel.
- Autorizzare la connessione API a **Office 365 / SharePoint Online**.
- Verificare la correttezza dei parametri e modificarli se necessario.
