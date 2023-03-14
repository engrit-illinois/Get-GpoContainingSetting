# Originally by James Babiarz
# Re-written by Matt Seng

function Get-GpoContainingSetting {
	param(
		[Parameter(Mandatory=$true,Position=0)]
		[string]$SettingQuery,
		
		[string]$GpoNameQuery = "*",
		
		[string]$Domain = "ad.uillinois.edu"
	)
	
	function log {
		param(
			[string]$Msg,
			[int]$L = 0
		)
		$indent = ""
		for($i = 0; $i -lt $L; $i += 1) {
			$indent = "    $indent"
		}
		$ts = Get-Date -Format "FileDateTime"
		Write-Host "[$ts]$($indent) $msg"
	}
	
	function count($array) {
		$count = 0
		if($array) {
			# If we didn't check $array in the above if statement, this would return 1 if $array was $null
			# i.e. @().count = 0, @($null).count = 1
			$count = @($array).count
			# We can't simply do $array.count, because if it's null, that would throw an error due to trying to access a method on a null object
		}
		$count
	}
	
	log "Importing Group Policy Management module..."
	if(-not (Get-Module "GroupPolicy")) {
		Import-Module "GroupPolicy"
	}
	
	log "Getting all the GPOs in domain: `"$Domain`" ..."
	$allGpos = Get-GPO -All -Domain $Domain
	$allGposCount = count $allGpos
	log "Found $allGposCount GPOs." -L 1
	
	log "Filtering GPOs by given value of -GpoNameQuery: `"$GpoNameQuery`"..."
	$filteredGpos = $allGpos | Where { $_.DisplayName -like $GpoNameQuery } | Sort DisplayName
	$filteredGposCount = count $filteredGpos
	log "Found $filteredGposCount GPOs with matching names." -L 1
	
	log "Searching XML in filtered GPOs..."
	log "Matches:" -L 1
	$logfunction = ${function:log}.ToString()
	$matchingGpos = $filteredGpos | ForEach-Object -Parallel {
		$SettingQuery = $using:SettingQuery
		${function:log} = $using:logfunction
		$gpo = $_
		$report = Get-GPOReport -Guid $gpo.Id -ReportType "Xml"
		if($report -like $SettingQuery) { 
			log "`"$($gpo.DisplayName)" -L 2
			$gpo.DisplayName
		}
	}
	log "Done searching XML." -L 1
	
	$matchingGposCount = count $matchingGpos
	log "Found $matchingGposCount GPOs with matching XML."
	
	log "EOF"
}