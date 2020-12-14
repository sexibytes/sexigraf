#!/usr/bin/pwsh
#
param([Parameter (Mandatory=$true)] [string] $server, [Parameter (Mandatory=$true)] [Parameter (Mandatory=$false)] [string] $sessionfile, [Parameter (Mandatory=$false)] [string] $credstore)

$exec_start = Get-Date
$script_version = "0.9.1"

