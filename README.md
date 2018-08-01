# snowlink

Used in conjunction with PagerDuty's ServiceNow integration, this script will read a CSV file and for each line create a ServiceNow extension in PagerDuty (if necessary) and then set the corresponding IDs in ServiceNow's Assignment Group.

## Getting Started

Download the example CSV and edit it with your values

Columns:
* ServiceNow instance (e.g. dev12345)
* ServiceNow REST API User id
* ServiceNow REST API Password
* ServiceNow Admin User id (i.e. it must have update privileges on the sys_user_group table)
* ServiceNow Admin Password
* PagerDuty Service Name
* ServiceNow Assignment Group Name
* Sync Option (either "auto" or "manual")
* ServiceNow Integration (either "v4" or "v5")

## Running

Parameters:
* p = API Key (required)
* f = input file name (required)
* d (optional) - to debug

Example:
./snowlink -p 0123456789001234567890 -f /tmp/myfile.csv

OR

./snowlink -p 0123456789001234567890 -f /tmp/myfile.csv -d



