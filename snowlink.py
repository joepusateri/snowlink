import argparse
import sys
import csv
import urllib.parse

import pd
import snow
import extension_type

DEBUG = False


# Get all services and store the EP for each

def findExistingExtension(token, snow_url_target, service_id, int_version_key):
    me = 'findExistingExtension'
    extensions_response = pd.fetch_extensions(token, {'extension_object_id': service_id})
    if DEBUG: print(f'   {me}: Extensions API Call Response for \"{service_id}\" {extensions_response}')
    for ext in extensions_response:
        if DEBUG: print(f'   {me}: Found extension {ext} on the service')
        # If the extension has a SNOW user defined...
        if 'snow_user' in ext['config']:
            snow_version = ext['extension_schema']['id']
            snow_url = ext['config']['target']

            # check that the extension is the same SNOW version AND the URL is for the right SNOW instance
            # BUT be careful in case the URL has extra URL params
            if snow_version == int_version_key and snow_url_target in snow_url:
                if DEBUG: print(f'   {me}: Got the ServiceNow extension of the right type and instance. id={ext["id"]}')
                return ext['id']


def createExtension(token, snow_instance, snow_api_user, snow_api_pw, sync, int_version_key, service_id):
    me = 'createExtension'
    # create extension
    if DEBUG: print(f'   {me}: Creating extension id={int_version_key}')

    body = {
        "extension": {
            "name": f'ServiceNow ({snow_instance})',
            "config": {
                "snow_user": snow_api_user,
                "snow_password": snow_api_pw,
                "sync_options": "sync_all" if (sync == "auto") else "manual_sync",
                "target": f'https://{snow_instance}.service-now.com/api/x_pd_integration/pagerduty2sn'
            },
            "extension_schema": {
                "id": int_version_key,
                "type": "extension_schema_reference"
            },
            "extension_objects": [
                {
                    "id": service_id,
                    "type": "service_reference",
                }
            ]
        }
    }

    if DEBUG: print(f'   {me}: Create Extension with data={body}')
    create_extension_response = pd.request(token=token, endpoint="extensions", method="POST", data=body)
    found_webhook_id = create_extension_response['extension']['id']
    if DEBUG: print(f'   {me}: Created Extension service id={service_id} webhook id={found_webhook_id}')
    return found_webhook_id


def findConfigurationItem(parm_snow_update_user, parm_snow_update_pw, parm_snow_ci_name, parm_snow_instance):
    me = 'findConfigurationItem'
    if DEBUG: print(f'   {me}: Retrieving Assignment Group \"{parm_snow_ci_name}\" from {parm_snow_instance}')
    # get sys_id for SN Assignment Group

    # ?sysparm_query=
    return snow.request(parm_snow_instance,
                        {"user": parm_snow_update_user, "password": parm_snow_update_pw},
                        f'cmdb_ci?sysparm_query=name={urllib.parse.quote(parm_snow_ci_name)}',
                        "GET"
                        )


def findAssignmentGroupId(parm_snow_update_user, parm_snow_update_pw, parm_snow_assignment_group_name,
                          parm_snow_instance):
    me = 'findAssignmentGroupId'
    if DEBUG: print(
        f'   {me}: Retrieving Assignment Group \"{parm_snow_assignment_group_name}\" from {parm_snow_instance}')
    # get sys_id for SN Assignment Group
    res = snow.request(parm_snow_instance,
                       {"user": parm_snow_update_user, "password": parm_snow_update_pw},
                       f'sys_user_group?sysparm_query=name={urllib.parse.quote(parm_snow_assignment_group_name)}',
                       "GET"
                       )
    return res['result'][0]['sys_id']


def updateConfigurationItem(snow_update_user, snow_update_password, snow_ci_id, snow_instance, webhook_id, service_id):
    me = 'updateConfigurationItem'
    if DEBUG: print(f'   {me}: Updating Configuration Item {snow_ci_id}')
    # get sys_id for SN Configuration Item

    if snow_ci_id:

        # push SN CI update
        body = {
            "x_pd_integration_pagerduty_webhook": webhook_id,
            "x_pd_integration_pagerduty_service": service_id
        }
        if DEBUG: print(f'   {me}: Preparing SNOW CI Update {body}')

        sci_update = snow.request(snow_instance,
                                  {"user": snow_update_user, "password": snow_update_password},
                                  f'cmdb_ci/{snow_ci_id}',
                                  "PUT",
                                  data=body
                                  )

        if DEBUG: print(
            f'   {me}: Successfully updated Configuration Item \"{sci_update["result"]["name"]}\" ID: {snow_ci_id}')

    else:
        print(f'Unable to update Configuration Item ID: {snow_ci_id}')


def updateAssignmentGroup(snow_update_user, snow_update_password, snow_ag_id, snow_instance, webhook_id, service_id,
                          ep_id):
    me = 'updateAssignmentGroup'
    if DEBUG: print(f'   {me}: Updating Assignment Group {snow_ag_id}')
    # get sys_id for SN Assignment Group

    if snow_ag_id:

        # push SN Assignment Group update
        body = {
            "x_pd_integration_pagerduty_webhook": webhook_id,
            "x_pd_integration_pagerduty_escalation": ep_id,
            "x_pd_integration_pagerduty_service": service_id
        }
        if DEBUG: print(f'   {me}: Preparing SNOW Assignment Group Update {body}')

        sag_update = snow.request(snow_instance,
                                  {"user": snow_update_user, "password": snow_update_password},
                                  f'sys_user_group/{snow_ag_id}',
                                  "PUT",
                                  data=body
                                  )

        if DEBUG: print(
            f'   {me}: Successfully updated Assignment Group \"{sag_update["result"]["name"]}\" ID: {snow_ag_id}')

    else:
        print(f'Unable to update Assignment Group ID: {snow_ag_id}')


def pair(line_count, token, parm_snow_instance, parm_snow_api_user, parm_snow_api_pw,
         parm_snow_update_user, parm_snow_update_pw, parm_service_target, parm_escalation_policy,
         parm_snow_ci_name, parm_snow_assignment_group_name, parm_sync, int_version_key):
    snow_url_target = f'https://{parm_snow_instance}.service-now.com/api/x_pd_integration/pagerduty2sn'
    services_response = pd.fetch_services(token, {'query': parm_service_target})
    me = 'pair'
    if DEBUG: print(f'   {me}: Service API Call response for \"{parm_service_target}\" {services_response}')

    if len(services_response) > 0:
        service_id = services_response[0]['id']
        ep_id = services_response[0]['escalation_policy']['id']
        epname = services_response[0]['escalation_policy']['summary']
    else:
        print(f'PagerDuty Service Not found for \"{parm_service_target}\". Skipping...')
        return 1
    if DEBUG: print(
        f'   {me}: Found {parm_service_target} service_id={service_id} escalation policy: id={ep_id} name={epname}')

    if parm_escalation_policy and epname != parm_escalation_policy:
        if DEBUG: print(f'   {me}: Trying to find Escalation Policy \"{parm_escalation_policy}\" from input')
        eps_response = pd.fetch_escalation_policies(token, {'query': parm_escalation_policy})
        if len(eps_response) > 0:
            ep_id = eps_response[0]['id']
            if DEBUG: print(f'   {me}: Escalation Policy found by name \"{parm_escalation_policy}\" id={ep_id}')

    found_extension_id = findExistingExtension(token, snow_url_target, service_id, int_version_key)
    # if found, get webhook id
    if found_extension_id:
        found_webhook_id = found_extension_id
        if DEBUG: print(
            f'   {me}: Found ServiceNow Extension for {parm_service_target} ({service_id} {ep_id} {found_webhook_id})')
    else:
        found_webhook_id = createExtension(token, parm_snow_instance, parm_snow_api_user, parm_snow_api_pw, parm_sync,
                                           int_version_key, service_id)
        if DEBUG: print(
            f'   {me}: Created ServiceNow Extension for {parm_service_target} ({service_id} {ep_id} {found_webhook_id})')

    snow_related_ag_id = ""
    if parm_snow_ci_name:
        snow_ci = findConfigurationItem(parm_snow_update_user, parm_snow_update_pw, parm_snow_ci_name,
                                        parm_snow_instance)
        if DEBUG: print(f'   {me}: Searching for CI \"{parm_snow_ci_name}\" results={snow_ci}')
        if snow_ci['result']:
            snow_ci_id = snow_ci['result'][0]['sys_id']
            if snow_ci_id == "":
                print(f'Could not find expected Configuration Item \"{parm_snow_ci_name}\". Skipping...')
                return 1

            if snow_ci['result'][0]['assignment_group']:
                snow_related_ag_id = snow_ci['result'][0]['assignment_group']['value']
        if DEBUG: print(f'   {me}: Found CI snow_ci_id={snow_ci_id} Related Assignment Group id={snow_related_ag_id}')

        if snow_related_ag_id == "" and parm_snow_assignment_group_name == "":
            print(
                f'Assignment group not provided and the Configuration Item \"{parm_snow_ci_name}\" has no related Assignment Group.  Skipping...')
            return 1

    snow_ag_id = ""
    if parm_snow_assignment_group_name:
        snow_ag_id = findAssignmentGroupId(parm_snow_update_user, parm_snow_update_pw, parm_snow_assignment_group_name,
                                           parm_snow_instance)
    else:  # AG Name not provided
        if snow_related_ag_id != "":  # Related AG found
            if DEBUG: print(f'   {me}: No Assignment Group provided, using ID: {snow_related_ag_id}')
            # find SNOW AG
            snow_ag_id = snow_related_ag_id

    if DEBUG: print(f'   {me}: Using SNOW Assignment Group id={snow_ag_id}')

    # update SNOW with values
    if snow_ci_id:
        updateConfigurationItem(parm_snow_update_user, parm_snow_update_pw, snow_ci_id, parm_snow_instance,
                                found_webhook_id, service_id)
    else:
        if parm_snow_ci_name:
            print(f'Provided Configuration Item \"{parm_snow_ci_name}\" not found. Skipping...\n')
            return 1

    # update SNOW with values
    updateAssignmentGroup(parm_snow_update_user, parm_snow_update_pw, snow_ag_id, parm_snow_instance, found_webhook_id,
                          service_id, ep_id)
    return 0


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description="Syncs PagerDuty IDs to ServiceNow")
    ap.add_argument('-p', '--api-key', required=True, help="PagerDuty REST API key")
    ap.add_argument('-f', '--filename', required=True, help="CSV file with pairs to match")
    ap.add_argument('-i', '--instance', required=True, help="ServiceNow instance id (e.g. dev12345)")
    ap.add_argument('-a', '--api-user', required=True, help="ServiceNow API User id")
    ap.add_argument('-s', '--api-password', required=True, help="ServiceNow API User password")
    ap.add_argument('-u', '--update-user', required=True, help="ServiceNow Update User id")
    ap.add_argument('-w', '--update-password', required=True, help="ServiceNow Update User password")
    ap.add_argument('-d', '--debug', required=False, help="Debug flag", action="store_true")
    args = ap.parse_args()

    DEBUG = args.debug

    with open(args.filename, mode='r') as csv_file:
        csv_reader = csv.reader(csv_file, delimiter=',')
        line_count = success_count = 0
        for row in csv_reader:
            line_count += 1
            print(
                f'Row {line_count}: {row[0]}, {row[1]}, {row[2]}, {row[3]}, {row[4]}, {row[5]}, ({extension_type.extension_type_ids[row[5]]})')
            if pair(line_count, args.api_key, args.instance, args.api_user, args.api_password, args.update_user,
                    args.update_password,
                    row[0], row[1], row[2], row[3], row[4],
                    extension_type.extension_type_ids[row[5]]) == 0: success_count += 1
        print(f'Processed {success_count} / {line_count} rows successfully.')
