var config;

function update(configInput) {
    config = configInput;

    const folder = DriveApp.getFolderById(config.driveFolder);
    const files = folder.getFiles();

    while (files.hasNext()) {
        const file = files.next();
        const rawCSVString = file.getBlob().getDataAsString();

        create(JSON.stringify(config.accounts), file.getName(), rawCSVString);
    }
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
    file.setTrashed(true);
}
