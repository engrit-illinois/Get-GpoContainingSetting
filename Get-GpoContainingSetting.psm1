# Originally by James Babiarz
# Re-written by Matt Seng

function Get-GpoContainingSetting {
	param(
		[Parameter(Mandatory=$true,Position=0)]
		[string]$SettingQuery,
		
		[string]$GpoNameQuery = "*",
		
		[string]$Domain = "ad.uillinois.edu",
		
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
		log "Getting all the GPOs in domain: `"$Domain`" ..."
		$gpos = Get-GPO -All -Domain $Domain
		$gposCount = count $gpos
		log "Found $gposCount GPOs." -L 1
		$gpos
	}
	
	function Get-FilteredGpos($gpos) {
		log "Filtering GPOs by given value of -GpoNameQuery: `"$GpoNameQuery`"..."
		$filteredGpos = $gpos | Where { $_.DisplayName -like $GpoNameQuery }
		$filteredGposCount = count $filteredGpos
		log "Found $filteredGposCount GPOs with matching names." -L 1
		$filteredGpos
	}
	
	function Get-MatchingGpos($filteredGpos) {
		log "Searching XML in filtered GPOs..."
		log "Matches:" -L 1
		$logfunction = ${function:log}.ToString()
		$matchingGpos = $filteredGpos | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
			$SettingQuery = $using:SettingQuery
			$Quiet = $using:Quiet
			$Verbosity = $using:Verbosity
			${function:log} = $using:logfunction
			
			$gpo = $_
			$name = $gpo.DisplayName
			$id = $gpo.Id
			$err = "unknown"
			log "Processing GPO: `"$name`" (`"$id`")..." -L 2 -V 1 -Debug
			try {
				$report = Get-GPOReport -Guid $id -ReportType "Xml" -ErrorAction "Stop"
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
				if($report -like $SettingQuery) { 
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
	
	function Do-Stuff {
		if(Import-Gpmc) {
			$gpos = Get-AllGpos
			$filteredGpos = Get-FilteredGpos $gpos | Sort "DisplayName"
			$matchingGpos = Get-MatchingGpos $filteredGpos
			if($PassThru) {
				Return-Gpos $matchingGpos
			}
		}
		log "EOF"
	}
	
	Do-Stuff
}