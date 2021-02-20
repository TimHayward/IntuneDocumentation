function ConvertTo-Hashtable {
    [CmdletBinding()]
    [OutputType('hashtable')]
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )
 
    process {
        ## Return null if the input is null. This can happen when calling the function
        ## recursively and a property is null
        if ($null -eq $InputObject) {
            return $null
        }
 
        ## Check if the input is an array or collection. If so, we also need to convert
        ## those types into hash tables as well. This function will convert all child
        ## objects into hash tables (if applicable)
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @(
                foreach ($object in $InputObject) {
                    ConvertTo-Hashtable -InputObject $object
                }
            )
 
            ## Return the array but don't enumerate it because the object may be pretty complex
            Write-Output -NoEnumerate $collection
        } elseif ($InputObject -is [psobject]) { ## If the object has properties that need enumeration
            ## Convert it to its own hash table and return it
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
            }
            $hash
        } else {
            ## If the object isn't an array, collection, or other object, it's already a hash table
            ## So just return it.
            $InputObject
        }
    }
}

#Open website
$webSite = Invoke-WebRequest -Uri https://docs.microsoft.com/en-us/graph/api/intune-deviceconfig-androiddeviceownergeneraldeviceconfiguration-create
$tables = @($webSite.ParsedHtml.getElementsByTagName("TABLE"))
$table = $tables[2]
$titles = @()
$rows = @($table.Rows)

$hashTable = @{}

foreach($row in $rows)
{
    $cells = @($row.Cells)
    ## If we've found a table header, remember its titles
    if($cells[0].tagName -eq "TH")
    {
        $titles = @($cells | ForEach-Object { ("" + $_.InnerText).Trim() })
        continue
    }
    ## If we haven't found any table headers, make up names "P1", "P2", etc.
    if(-not $titles)
    {
        $titles = @(1..($cells.Count + 2) | ForEach-Object { "P$_" })
    }
    ## Now go through the cells in the the row. For each, try to find the
    ## title that represents that column and create a hashtable mapping those
    ## titles to content
    $resultObject = [Ordered] @{}
    for($counter = 0; $counter -lt $cells.Count; $counter++)
    {
        $title = $titles[$counter]
        if(-not $title) { continue }
        $resultObject[$title] = ("" + $cells[$counter].InnerText).Trim()
    }
    ## And finally cast that hashtable to a PSCustomObject
    [PSCustomObject] $resultObject
    $Property = $resultObject.Property
    $Type = $resultObject.Type
    $Description = $resultObject.Description
    $hashTable += @{
        $Property = [ordered] @{
            Type = $Type
            Description = $Description
        }
    }
}


# $HashTable = descriptions
$TranslationFile = "C:\Support\Scripts\#microsoft.graph.androidDeviceOwnerGeneralDeviceConfiguration.json"

$translateJson = Get-Content $TranslationFile
$translation = $translateJson | ConvertFrom-Json | ConvertTo-Hashtable

$allRecords = @{}

foreach ($hash in $hashTable.GetEnumerator()){
    $HTDescription = $hash.Value.Description
    if($translation.Contains($hash.key)) {
        $t = $translation.GetEnumerator().Where({$PSItem.Key -contains $($hash.key)}) 
        [String]$HTName = $t.Name
        [String]$HTSection = $t.Value.Section
        [String]$HTDisplayName = $t.Value.Name
        [string]$HTDataType = $t.Value.DataType
    }
    if($HTDisplayName.Length -eq 0){
        $HTDisplayName = "Display Name TBC"
    }
    $allRecords += @{
        $HTName = @{
            Description = $HTDescription
            ItemType = $HTDataType
            Section = $HTSection
            DisplayName = $HTDisplayName
        }
    }
}
