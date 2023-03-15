# Originally by James Babiarz
# Re-written by Matt Seng

function Get-GpoContainingSetting {
	param(
		[Parameter(Mandatory=$true,Position=0)]
		[string]$XmlQuery,
		
		[string]$NameQuery = "*",
		
		[string]$Domain,
		
		[string]$Server,
		
		[switch]$Quiet,
		
		[switch]$PassThru,
		
		[switch]$PassThruFull,
		
		[int]$Verbosity = 0,
		
		[int]$ThrottleLimit = 10
	)
	
	function log {
		param(
			[string]$Msg,
			[int]$L = 0,
			[int]$V = 0,
			[switch]$Match,
			[switch]$Debug,
			[switch]$Err,
			[switch]$PassThru,
			[switch]$Raw
		)
		
		if(((-not $Quiet) -or ($Err)) -or $Raw) {
			if(-not $Raw) {
				$indent = ""
				for($i = 0; $i -lt $L; $i += 1) {
					$indent = "    $indent"
				}
				$ts = Get-Date -Format "HH:mm:ss"
				$Msg = "[$ts]$($indent) $Msg"
			}
			
			$params = @{
				Object = $Msg
			}
			
			if($Match) {
				$params.ForegroundColor = "Green"
			}
			if($Debug) {
				$params.ForegroundColor = "Yellow"
			}
			if($Err) {
				$params.ForegroundColor = "Red"
			}
			
			if($V -le $Verbosity) {
				if(-not $PassThru) {
					Write-Host @params
				}
				else {
					$msg
				}
			}
		}
	}
	
	function count($array) {
		$count = 0
		if($array) {
			$count = @($array).count
		}
		$count
	}
	
	function Import-Gpmc {
		log "Importing Group Policy Management module..."
		if(-not (Get-Module "GroupPolicy")) {
			$err = "unknown"
			try {
				# Importing the GroupPolicy module in PowerShell 7 throws a warning we don't care about, so ignore it
				Import-Module "GroupPolicy" -ErrorAction "Stop" 3> $null
			}
			catch {
				$err = $_.Exception.Message
			}
			
			if(-not (Get-Module "GroupPolicy")) {
				log "Failed to import GroupPolicy module! Error: `"$err`"."
				return $false
			}
		}
		return $true
	}
	
	function Get-AllGpos {
		log "Getting all GPOs in the domain..."
		$params = @{}
		if($Domain) { $params.Domain = $Domain }
		if($Server) { $params.Server = $Server }
		$gpos = Get-GPO -All @params
		$gposCount = count $gpos
		log "Found $gposCount GPOs." -L 1
		$gpos
	}
	
	function Get-FilteredGpos($gpos) {
		log "Filtering GPOs by given value of -NameQuery: `"$NameQuery`"..."
		$filteredGpos = $gpos | Where { $_.DisplayName -like $NameQuery }
		$filteredGposCount = count $filteredGpos
		log "Found $filteredGposCount GPOs with matching names." -L 1
		$filteredGpos
	}
	
	function Get-MatchingGpos($filteredGpos) {
		log "Filtering GPOs by given value of -XmlQuery: `"$XmlQuery`"..."
		log "Matches:" -L 1
		$logfunction = ${function:log}.ToString()
		$matchingGpos = $filteredGpos | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
			$XmlQuery = $using:XmlQuery
			$Quiet = $using:Quiet
			$Verbosity = $using:Verbosity
			$Domain = $using:Domain
			$Server = $using:Server
			${function:log} = $using:logfunction
			
			$gpo = $_
			$name = $gpo.DisplayName
			$id = $gpo.Id
			$err = "unknown"
			log "Processing GPO: `"$name`" (`"$id`")..." -L 2 -V 1 -Debug
			
			$params = @{
				Guid = $id
				ReportType = "Xml"
				ErrorAction = "Stop"
			}
			if($Domain) { $params.Domain = $Domain }
			if($Server) { $params.Server = $Server }
			try {
				$report = Get-GPOReport @params
			}
			catch {
				$err = $_.Exception.Message
			}
			
			if(-not $report) {
				# Wrap these up so they are output more or less "synchronously"
				$errString = log "Failed to get report for GPO: `"$name`"!" -L 3 -PassThru
				$errString += "`n" + (log "Error: `"$err`"." -L 4 -PassThru)
				if($err -like "*The server does not support the requested critical extension*") {
					$errString += "`n" + (log "This particular error probably means you're querying the DC too quickly. Try lowering the value of -ThrottleLimit." -L 4 -PassThru)
				}
				log $errString -Raw -Err
			}
			else {
				if($report -like $XmlQuery) { 
					log "$name" -L 2 -Match
					$gpo
				}
			}
		}
		log "Done searching XML." -L 1
		
		$matchingGposCount = count $matchingGpos
		log "Found $matchingGposCount GPOs with matching XML." -L 1
		
		$matchingGpos
	}
	
	function Return-Gpos($matchingGpos) {
		if($PassThruFull) {
			$matchingGpos
		}
		else {
			if($matchingGpos) {
				$matchingGpos | Select -ExpandProperty "DisplayName"
			}
		}
	}
	
	function Get-Runtime($startTime) {
		$endTime = Get-Date
		$runtime = $endTime - $startTime
		log "Runtime: $runtime"
	}
	
	function Do-Stuff {
		$startTime = Get-Date
		if(Import-Gpmc) {
			$gpos = Get-AllGpos
			$filteredGpos = Get-FilteredGpos $gpos | Sort "DisplayName"
			$matchingGpos = Get-MatchingGpos $filteredGpos
			if($PassThru) {
				$returnObject = Return-Gpos $matchingGpos
			}
		}
		Get-Runtime $startTime
		log "EOF"
		$returnObject
	}
	
	Do-Stuff
}