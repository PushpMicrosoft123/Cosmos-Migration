Cosmos document DB migration aims to support legacy data by solving migration challenges that can occur due to non-schema nature of Document DB. It provides smooth and automated way of updating legacy documents in NoSQL database (currently supported Cosmos DocumentDB).

# Description
Project consists of multiple powershell scripts, each responsible for one specific operation, and together they form a pipeline of tasks to complete migration. 
- ## Modularity: 
    Complete automation is broken into smaller tasks in the form of Powershell scripts to reduce the coupling and maintain the modularity, It also helps users to run a specific task or group of tasks based on their requirement. Moreover, each script can be modified independently to make it extensible for the requirements that are not achievable in their normal form.
- ## Zero Infrastructure Cost:
     Since processing happens on a local machine, there are no cost involve in terms of infra set up. If you want to run scripts for more that 50K records, you can think of runnng it on a VM with more computing power and space.

- ## Complete Automation using DevOps pipelines:
     To trigger end to end migration each script can be added as a release task in your CI pipelines once all the dependencies are installed.
     
- ## Understanding scripts
    #### 1. createBackUp.ps1
    This script creates a backup container before performing any migration or document updates to allow roll backs at later stages in case of errors.
    Run this script to create a back-Up container for your Cosmos Document DB container.
    #### Parameters:
    **-cosmosConnectionString:** your cosmos db connection string. Please append database name to connection string before passing. Your patter should be : {cosmos connection string from Azure portal};Database={yourDBname}
    **-sourceContainerName**: Source container to be backed-Up.
    **-backupContainerName:** provide new collection name for your back-Up container.
    **-partitionKey:** Partition key to be set for new back-Up container.
    **Suggestion:** Once Back-Up is completed please compare the document count of original collection and Back-Up collection to ensure if back-Up was success.
    
    ## Sample command for creating back-Up:
    .\createBackUp.ps1 -cosmosConnectionString "" -backupContainerName ""  -sourceContainerName "Test" -partitionKey "/_partitionKey"
    
    #### 2. loadAndTransform.ps1
    Core powershell script that loads Cosmos DB documents on your machine/DevOps Agents into a single Json file and transform them to new state. Below activities can be performed as part of transformation stage:
    1. Add new key-value pairs.
    2. Edit existing key-value pairs.
    3. Delete properties.
    4. Copy values from one key to another within your Json document(Supports linear copy, array to array copy and nested structures with depth as 100).
    5. Type conversion from one data type to another. for eg: flat object to array, string to int/decimal or int/decimal to string.
    6. Filter documents using select query to perform add/edit/delete/type-conversion operations on specific documents.
        
    #### Parameters:
    **-cosmosConnectionString:** connection string to your target cosmos DB. Please append DB name as mentioned in previous script.
    **-collectionName:** Can be left as empty.
    **-sourceContainerName:** source container name from where the data will be imported to your target json file.
    **-directoryToStoreMigratedFiles:** provide working directory that script will use to store documents imported from back-Up container.
    **-importFromCosmosRequired:** a boolean flag to skip import operation. Pass $false/$true as required.
    **-importedFileLocation:** a target json file path where all the documents will be loaded in the form of array.
    **-folderPrefix:** optional prefix literal used by script to create a unique folder in working directory.
    **-inputJsonPath** json location which provides update document details. File should have below key-value pairs based on the command selected:
    
    **Copy from source to target:**
    ```
    {
    "command": "CopyToTarget", // supported commands "TypeConversion", "AddTarget", "CopyToTarget" and "DeleteTarget"
    "sourceProperty":"K[].C[].P",
    "targetProperty":"K[].C[].E",
    "targetPropertyConstantValue":"",
    "dataType":"array",
    "keepTargetValueAfterDataTypeChange":false,
    "forceReplace": true,
    "selectQuery":"",
    }
    ```
    **Data type conversion: converts Target Property Data Type:**
    ```
    {
    "command": "TypeConversion",
    "sourceProperty":"K[].C[].P",
    "targetProperty":"K[].C[].P",
    "targetPropertyConstantValue":"",
    "dataType":"array",
    "keepTargetValueAfterDataTypeChange":true,
    "forceReplace": false,
    "selectQuery":"",
    }
    ```
    **AddTarget:**
    ```
    {
    "command": "AddTarget",
    "sourceProperty":"",
    "targetProperty":"K[].C[].P",
    "targetPropertyConstantValue":100,
    "dataType":"",
    "keepTargetValueAfterDataTypeChange":false,
    "forceReplace": false,
    "selectQuery":"",
    }
    ```
    **DeleteTarget:**
    ```
    {
    "command": "DeleteTarget",
    "sourceProperty":"",
    "targetProperty":"K[].C[].P",
    "targetPropertyConstantValue":"",
    "dataType":"",
    "keepTargetValueAfterDataTypeChange":false,
    "forceReplace": false,
    "selectQuery":"",
    }
    ```
    
    **Understanding above Keys:**
    **-sourceProperty:** If performing copy operation provide the source property name to copy value from. Please use period(.) to point nested properties. For Example:
    Sample Json:
    A
    {
    B:[
    {
    C:D,
    E:F
    }
    ]
    }
    to use C as an input property the correct format is A.B[].C. Please note arrays should have square brackets appended with their name as shown B[] previously.
    
    **-targetProperty:** If performing copy/add operation pass target property which has to be modified. follow the format mentioned for source property to pass nested                 properties.
    **-targetPropertyConstantValue:** If adding new property use this parameter to pass value to be used for the target property (supports only string). Keep it empty for copy          operations.
    **-filterProperty:** use this parameter to perform operation only for limited documents. Currently filter is supported on root level of Json structure.
    **-filterPropertyValue:** Value to be used for filter property.
    **-forceReplace:** Use this flag to force replace target values. If passed as $false script will not updatethe targets if there is an existing value for them.
    **-keepTargetValueAfterDataTypeChange:** enable this flag if you want to preserve source values in new data type model.
    **-dataType:** Target data types. Supported values: "array", "string", "int" and "decimal".
    
    ## Sample command for data transformation:
    .\loadAndTransform.ps1 -cosmosConnectionString "" -sourceContainerName "" -directoryToStoreUpdatedDocuments "" -importFromCosmosRequired $true -importedFileLocation ""            -inputJsonPath ".\input.json"  -folderPrefix "dev"  
    
   #### 3. exportToCosmos.ps1
   This PowerShell script deletes the target container if exists in order to upload transformed documents generated by previous script.
   #### Parameters: 
   **-userName:** Azure service principal client Id
   **-secret:** Azure service principal client Secret
   **-tenantId:** Azure tenant Id
   **-subscriptionId:** Azure Subscription Id
   **-sourceFilePath:** Json file path containing transformed documents.
   **-targetContainerName:** Target container for uploading  source file.
   **-deletingExistingContainerRequired:** A flag to skip container deletion.
   **-partitionKey:** Partition key to be set for new container.
   **-cosmosConnectionString:** connection string pointing to cosmos database.Please append DB name as mentioned in back-Up script.
   **-accountName:** Azure Cosmos account name.
   **-resourceGroup:** resource group where cosmos is deployed.
   **-databaseName:** Cosmos database name required to delte the old container.
   **-requestUnit:** Request unit to be set for new continer.
    
   ## Sample command to export json file to new container:
   .\exportToCosmos.ps1 -userName "" -secret "" -tenantId "" -subscriptionId "" -sourceFilePath "" -targetContainerName "" -deletingExistingContainerRequired $false -   partitionKey "/_yourpartitionKey" -cosmosConnectionString "" -accountName "" -resourceGroup "" -databaseName "" -requestUnit 4000 -dmtPath ".\dt1.8.3\drop\dt.exe"
   
   # Dependencies
   - Azure CLI (used in exportToCosmos.ps1 script to delete target container)
   - PowerShell V7.x to run the scripts
   
   # Author
   Pushpdeep Gupta (pushpdeepamity@gmail.com)
   Git Username: https://github.com/PushpMicrosoft123
   
   # Version History
   - 1.0
     Initial realease
   - 1.1 
     Support for data type conversion.
     
   # License 
    This project is licensed under the [MIT LICENSE](https://choosealicense.com/licenses/mit/)
  
