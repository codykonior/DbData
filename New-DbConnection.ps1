<#

.SYNOPSIS
Create an SQL Server connection string using the underlying .NET builder class.

.DESCRIPTION
A simplified and safer way of creating a dynamic connection string instead of trying to remember all of the different components.

There is far more possible options than are provided here.

.PARAMETER ServerInstance
Specify as ServerName\Instance.

.PARAMETER DatabaseName
The database name if required. Defaults to no database, but it's strongly recommended you use something (at least master) so that connection pooling can be used automatically.

.PARAMETER UserName
If specified SQL Authentication will be used.

.PARAMETER Password
If specified SQL Authentication will be used.

.PARAMETER ApplicationName
Free text recorded by SQL Server so that Database Administrators can identify what a session is being used for. Also useful for connection pooling.

.PARAMETER ApplicationIntent
ReadOnly or ReadWrite for AlwaysOn Availability Groups.

.PARAMETER HostName
Populated with the computer name being connected from so that Database Administrators can identify where a session comes from, but can be masked.

.PARAMETER ConnectTimeout
The number of seconds to wait before timing out the connection.

.PARAMETER MultipleActiveResultSets
A switch to enable this functionality which is required for Entity Framework (but not LINQ to SQL).

.PARAMETER MultiSubnetFailover
For High Availability scenarios connections will be concurrently attempted on multiple IPs returned by the server part of the ServerInstance name.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
A connection string.

.EXAMPLE
Connect to a remote server.

$serverInstance = "AGL1"
New-DbConnection $serverInstance

# Data Source=AG1L;Integrated Security=True

.EXAMPLE
Connect to a remote server with a username and password.
    
$serverInstance = "AGL1"
New-DbConnection $serverInstance Northwind some_user unsafe_password

# Data Source=AGL1;Initial Catalog=Northwind;Integrated Security=False;User ID=some_user;Password=unsafe_password

#>

function New-DbConnection {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("SqlServerName")]
		[string] $ServerInstance,
        
        $Database,

		$UserName,
		$Password,

		$ApplicationName,
		[System.Data.SqlClient.ApplicationIntent] $ApplicationIntent,
		$HostName,
		
        [int] $ConnectTimeout,
        [switch] $MultipleActiveResultSets,
		[switch] $MultiSubnetFailover
	)

    Begin {
    }

    Process {
	    $connectionBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder

	    $connectionBuilder."Data Source" = $ServerInstance
            if ($Database) {
    	        $connectionBuilder."Initial Catalog" = $Database
	    }
        if ($UserName){
		    $connectionBuilder."Integrated Security" = $false
		    $connectionBuilder."User ID" = $UserName
		    $connectionBuilder."Password" = $Password
	    } else {
		    $connectionBuilder."Integrated Security" = $true
	    }
	    if ($ApplicationIntent) {
		    $connectionBuilder."ApplicationIntent" = $ApplicationIntent
	    }
        if ($ConnectTimeout) {
            $connectionBuilder."Connect Timeout" = $ConnectTimeout
        }
	    if ($ApplicationName) {
		    $connectionBuilder."Application Name" = $ApplicationName
	    }
	    if ($HostName) {
		    $connectionBuilder."Workstation Id" = $HostName
	    }
	    if ($MultipleActiveResultSets) {
		    $connectionBuilder."MultipleActiveResultSets" = $MultipleActiveResultSets
	    } 
	    if ($MultiSubnetFailover) {
		    $connectionBuilder."MultiSubnetFailover" = $MultiSubnetFailover
	    } 

	    $connectionBuilder.ConnectionString
    } 

    End {
    }
} 
