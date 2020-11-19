import requests
from requests.auth import HTTPBasicAuth

def request(instance=None, creds=None, table=None, method="GET", params=None, data=None, addheaders=None):

    if not instance or not table or not creds:
        return None

    url = f'https://{instance}.service-now.com/api/now/table/{table}'
    headers = {
        "Content-Type": "application/json"
    }

    if data != None:
        headers["Content-Type"] = "application/json"

    if addheaders:
        headers.update(addheaders)

    req = requests.Request(
        method=method,
        url=url,
        headers=headers,
        params=params,
        json=data,
        auth=HTTPBasicAuth(creds['user'], creds['password'])
    )

    prepped = req.prepare()
    response = requests.Session().send(prepped)
    response.raise_for_status()

    if len(response.content) > 0:
        return response.json()
    else:
        return None

