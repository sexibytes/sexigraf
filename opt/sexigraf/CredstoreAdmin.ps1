#!/usr/bin/pwsh -Command
#
param([Parameter (Mandatory=$true)] [string] $credstore, [string] $server, [string] $username, [string] $password, [switch] $add, [switch] $remove, [switch] $list, [switch] $createstore, [switch] $check)

# https://www.powershellmagazine.com/2013/08/19/mastering-everyday-xml-tasks-in-powershell/
# https://github.com/dotnet/platform-compat/blob/master/docs/DE0001.md

try {
    if ($createstore -ne $true) {
        $createstorexml = New-Object -TypeName XML
        $createstorexml.Load($credstore)
    }
} catch {
    write-host "credstore not found or not valid xml"
    exit 1
}

if ($createstore) {
    if (!$(Test-Path $credstore)) {
        try {
            $XmlWriter = New-Object System.XMl.XmlTextWriter($credstore,$Null)
            $xmlWriter.Formatting = 'Indented'
            $xmlWriter.Indentation = 1
            $XmlWriter.IndentChar = "`t"
            $xmlWriter.WriteStartDocument()
            $xmlWriter.WriteProcessingInstruction("xml-stylesheet", "type='text/xsl' href='style.xsl'")
            $xmlWriter.WriteStartElement('viCredentials')
            $xmlWriter.WriteStartElement('passwordEntry')
            $xmlWriter.WriteElementString('server',"__localhost__")
            $xmlWriter.WriteElementString('username',"login")
            $xmlWriter.WriteElementString('password',"xxxxx")
            $xmlWriter.WriteEndElement()  
            $xmlWriter.WriteEndDocument()
            $xmlWriter.Flush()
            $xmlWriter.Close()
        } catch {
            write-host "cannot create file"
            exit 1 
        }
    } else {
        write-host "file already exists"
        exit 1     
    }
} elseif ($check) {
    if ($server) {
        $XPath = '//passwordEntry[server="' + $server + '"]'
        if ($(Select-XML -Xml $createstorexml -XPath $XPath)){
            $item = Select-XML -Xml $createstorexml -XPath $XPath
            return $item.Node.count
        } else {
            return 0
        }
    } else {
        write-host "specify -server"
        exit 1
    }
} elseif ($list) {
    $viCredentialsList = @()
    foreach ($viCredential in $createstorexml.viCredentials.passwordEntry) {
        if ($viCredential.server.ToString() -ne "__localhost__") {
            $viCredentialEntry = "" | Select-Object server, username
            $viCredentialEntry.server = $viCredential.server.ToString()
            $viCredentialEntry.username = $viCredential.username.ToString()
            $viCredentialsList += $viCredentialEntry
        }
    }
    return $viCredentialsList|Sort-Object server|Format-Table -hidetableheaders -Property server, username
} elseif ($add) {
    if ($server -and $username -and $password) {
        $XPath = '//passwordEntry[server="' + $server + '"]'
        if (!$(Select-XML -Xml $createstorexml -XPath $XPath)){
            try {
                $item = Select-XML -Xml $createstorexml -XPath '//passwordEntry[1]'
                $newnode = $item.Node.CloneNode($true)
                $newnode.server = $server
                $newnode.username = $username
                $newnode.password = [Convert]::ToBase64String($([System.Text.Encoding]::Unicode.GetBytes($password)))
                # [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($newnode.password))
                $passwordEntry = Select-XML -Xml $createstorexml -XPath '//viCredentials'
                $passwordEntry.Node.AppendChild($newnode)
                $createstorexml.Save($credstore)
            } catch {
                write-host "cannot add entry"
                exit 1 
            }
        } else {
            write-host "$server entry already exists"
            exit 1
        }
    } else {
        write-host "specify -server and -username and -password"
        exit 1
    }
} elseif ($remove) {
    if ($server) {
        try {
            $XPath = '//passwordEntry[server="' + $server + '"]'
            $item = Select-XML -Xml $createstorexml -XPath $XPath
            $null = $item.Node.ParentNode.RemoveChild($item.node)
            $createstorexml.Save($credstore)
        } catch {
            write-host "cannot remove entry"
            exit 1 
        }
    } else {
        write-host "specify -server"
        exit 1
    }
} else {
    write-host "specify -list, -createstore, -add, -remove or -check"
    exit 1
}