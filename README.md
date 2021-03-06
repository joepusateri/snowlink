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
* p = PagerDuty API Key (required) - This can be an API token (global or user) or an OAuth2 token as long as it has sufficient permissions.
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

## More Detail

For those of you who are still  wondering what this thing does, I thought I'd write up a quick "raison d'&#234;tre" for snowlink.

In order for someone to use the PagerDuty ServiceNow integration, there needs to be a connection between certain objects in the two worlds.
* Incidents
* Configuration Items
* Assignment Groups
* Users

There are analogous objects in the PagerDuty world for each of these.  Users and Incidents are pretty clear, but the other two may not be. 

In every case, we map between the two environments by adding fields to the ServiceNow tables for the PagerDuty IDs. When an Incident is created from PagerDuty, the new Incident ID is stored in the Incident row on the ServiceNow side.

However to know which Service should refer to which Configuration Item and to know which Escalation Policy corresponds to which Assignment Group requires a similar assignment of PagerDuty IDs to the right objects. 

The integration will provision Services and Escalation Policies in PagerDuty from CIs and Assignment Groups, but if the Services and Policies already exist, the way to manually map is to enter the right IDs into the ServiceNow CI and Assignment Group records. See https://support.pagerduty.com/docs/servicenow-integration-guide#421-manually-provision-individual-configuration-items-to-pagerduty-optional

The fields we set are:

Configuration Item (cmdb_ci)
* Service ID
* Webhook ID

Assignment Group (sys_user_group)
* Escalation Policy ID
* Service ID (not needed when set to use both CIs and Assignment Groups)
* Webhook ID (not needed when set to use both CIs and Assignment Groups)

Please note that, while you can choose to use only Assignment Groups OR both CIs and Assignment Groups in the integration Settings, this script will fill ALL the fields on both objects as a convenience. 

In PagerDuty there needs to be a ServiceNow Extension on the Service to produce the Webhook ID. As a convenience, if the PagerDuty Service does not have an Extension to ServiceNow, this script will create one using the api-user and api-password fields.

So this script will take as input a CSV with a Service Name that maps to a Configuration Item Name, and optionally an Escalation Policy Name to map to an Assignment Group Name. It will look up the PagerDuty IDs and then update ServiceNow with those values.

To explain the optional columns in the CSV: A PagerDuty Service ALWAYS has an Escalation Policy associated with it, so we can refer to that Escalation Policy and the input does NOT need to specify it. Similarly a Configuration Item OPTIONALLY has an Assignment Group associated with it, so we look for that Assignment Group and the input MAY not need to specify it. Since it's optional in ServiceNow, if you do not specify the Assignment Group in the input and one is not associated to the CI in ServiceNow, it will skip that row because we won't know the Assignment Group.

Have fun!




