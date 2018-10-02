# snowlink

Used in conjunction with PagerDuty's ServiceNow integration, this script will read a CSV file and for each line create a ServiceNow extension in PagerDuty (if necessary) and then set the corresponding IDs in ServiceNow's Assignment Group.

## Getting Started

Download the example CSV and edit it with your values

Columns:
* ServiceNow instance (e.g. dev12345)
* ServiceNow REST API User id
* ServiceNow REST API Password
* ServiceNow Admin User id - it MUST HAVE UPDATE PRIVILEGES on the sys_user_group table
* ServiceNow Admin Password
* PagerDuty Service Name - the Service Name in PagerDuty that should have the extension
* PagerDuty Escalation Policy Name - OPTIONAL since the Service has an Escalation Policy
* ServiceNow Configuration Item Name - CONDITIONALLY OPTIONAL - If blank, ServiceNow Assignment Group Name must be specified - The Configuration Item to map to the PagerDuty Service
* ServiceNow Assignment Group Name - CONDITIONALLY OPTIONAL - If blank, ServiceNow Configuration Item Name must be specified - The Assignment Group to map to the PagerDuty  Escalation Policy
* Sync Option (either "auto" or "manual")
* ServiceNow Integration (either "v4" or "v5")

The REST API User and Password are for the Extension to be created in PagerDuty.
The Admin User and Password are used to update the Assignment Group in ServiceNow.

## Running

Parameters:
* p = API Key (required)
* f = input file name (required)
* d (optional) - to debug

Example:
```
./snowlink -p 0123456789001234567890 -f /tmp/myfile.csv
```
OR
```
./snowlink -p 0123456789001234567890 -f /tmp/myfile.csv -d
```
