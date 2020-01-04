# Supported
* Revolut csv
* KBC Account csv (NL/EN)
* KBC Credit Card csv (NL/EN)

# Google apps script
## Requirements
```shell script
pub global activate apps_script_tools
```
## Get code
Generate transforming file:
```shell script
dart2js --csp -o out.js bin/google_apps_script.dart && apps_script_gsify -s create out.js -o out.gs && cat out.gs | pbcopy
```
Additional file in `js/api.js`

## Usage
* Reference library
```javascript
function run() {
  try {
    YNAB.update(
        {
            budgetId: "9fb61c1a-9d98-4b68-80a9-271aee5223d7",
            accounts: {
                "Revolut": "13fc7e67-aba4-4595-b150-e7c6f2bee6e7",
                "BE12345678901234": "890441dd-be4c-432f-9fdd-0ca5433abb32",
                "612344XXXXXX9876": "d177c003-8670-466b-9aaf-11220e10611e",
            },
            driveFolder: "drive-folder-id",
            accessToken: "ynab-access-token",
            dryRun: false
        }
    );
  } catch (e) {
    Logger.log(e);
    throw e;
  }
}
```

# Native
## Compile executable

## Usage
### Create config file
```json
{
  "accounts": {
    "Revolut": "13fc7e67-aba4-4595-b150-e7c6f2bee6e7",
    "BE12345678901234": "890441dd-be4c-432f-9fdd-0ca5433abb32",
    "612344XXXXXX9876": "d177c003-8670-466b-9aaf-11220e10611e"
  },
  "budgetId": "9fb61c1a-9d98-4b68-80a9-271aee5223d7",
  "authToken": "ynab-access-token"
}
```
### Command
```shell script
csv2ynab --help
csv2ynab -c path/to/config.json -i path/to/input.csv
```

```
-i, --input-file      Required File path
-c, --account-json    Required Config json path
-f, --force           Force mode. Does not add a import-id.
-d, --dryRun          Dry-run. Prints JSON.
-h, --help            Displays this help information.
```