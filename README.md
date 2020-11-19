NOTE - The Perl version of snowlink worked with v4 and v5 of the PagerDuty ServiceNow Integration and is not supported in any way and has been moved to the "perl" subdirectory in this repository.

# snowlink

Used in conjunction with PagerDuty's ServiceNow integration, this Python script will read a CSV file and for each line create a ServiceNow extension in PagerDuty (if necessary) and then set the corresponding IDs in ServiceNow's Assignment Group.

## Files
* snowlink.py - main script
* snow.py - REST library for ServiceNow
* pd.py - REST library for PagerDuty
* extension_type.py - library containing the ServiceNow integration version ids supported
* py_example.csv - a brief example CSV for input
* requirements.txt - the Python required libraries.  

## Getting Started

Download the example CSV and edit it with your values

Columns:
* PagerDuty Service Name - the Service Name in PagerDuty that should have the extension
* PagerDuty Escalation Policy Name - OPTIONAL since the Service has an Escalation Policy
* ServiceNow Configuration Item Name - CONDITIONALLY OPTIONAL - If blank, ServiceNow Assignment Group Name must be specified - The Configuration Item to map to the PagerDuty Service
* ServiceNow Assignment Group Name - CONDITIONALLY OPTIONAL - If blank, ServiceNow Configuration Item Name must be specified - The Assignment Group to map to the PagerDuty  Escalation Policy
* Sync Option (must be one of: `auto` or `manual`)
* ServiceNow Integration (must be one of: `v4`,`v5`,`v6`,`v7`)

The REST API User and Password are for the Extension to be created in PagerDuty.
The Admin User and Password are used to retrieve and update the Assignment Group in ServiceNow.

## Running

Parameters:
* p = API Key (required)
* f = input file name (required)
* i = ServiceNow instance (required)
* a = ServiceNow REST API User id (required)
* s = ServiceNow REST API Password (required)
* u = ServiceNow Admin User id  (required) - MUST HAVE UPDATE PRIVILEGES on the sys_user_group and cmdb_ci tables
* w = ServiceNow Admin Password (required)
* d (optional) - include this to print debug messages

Example:
```
./snowlink -i dev2345 -a pagerduty -s aho#$fR% -u admin -w @$GBgF%! -p 0123456789001234567890 -f /tmp/myfile.csv
```
OR
```
./snowlink -i dev2345 -a pagerduty -s aho#$fR% -u admin -w @$GBgF%! -p 0123456789001234567890 -f /tmp/myfile.csv -d
```
Used in conjunction with PagerDuty's ServiceNow integration, this script will read a CSV file and for each line create a ServiceNow extension in PagerDuty (if necessary) and then set the corresponding IDs in ServiceNow's Assignment Group.


