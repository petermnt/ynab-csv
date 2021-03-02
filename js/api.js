var config;
var file;

function update(configInput) {
    config = configInput;
    Logger.log(config);

    const folder = config.driveFolder;
    const files = folder.getFiles();

    while (files.hasNext()) {
        file = files.next();
        const rawCSVString = file.getBlob().getDataAsString();

        create(JSON.stringify(config.accounts), file.getName(), rawCSVString);
    }
}

function updateWithFile(configInput) {
  config = configInput;
  create(JSON.stringify(config.accounts), config.fileName, config.csv);
}

function doCall(data) {
    const url = "https://api.youneedabudget.com/v1/budgets/" + config.budgetId + "/transactions"
    const properties = {
        "headers": {
            "Authorization": "Bearer " + config.accessToken,
            "Content-Type": "application/json"
        },
        "method": "post",
        "payload": data
    };
    UrlFetchApp.fetch(url, properties);

    Logger.log("Added transactions");

    if (file != null) {
        Logger.log("Removing " + file.getName());
        file.setTrashed(true);
    }
}
