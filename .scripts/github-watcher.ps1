$repo = "C:\Users\HP\Langzio-Darija"
$debounceSeconds = 5

Write-Host "Langzio-Darija Auto GitHub Sync"
Write-Host "Watching: $repo"
Write-Host "Press Ctrl+C to stop"

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $repo
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite, [System.IO.NotifyFilters]::FileName, [System.IO.NotifyFilters]::DirectoryName
$watcher.EnableRaisingEvents = $true

$action = {
    $path = $Event.SourceEventArgs.FullPath

    if ($path -like "$repo\.git\*" -or
        $path -like "$repo\.scripts\*" -or
        $path -like "$repo\node_modules\*") {
        return
    }

    Start-Sleep -Seconds $debounceSeconds

    Set-Location $repo

    $changes = git status --porcelain

    if (-not $changes) {
        return
    }

    Write-Host ""
    Write-Host "Changes detected. Synchronizing..." -ForegroundColor Yellow

    git add .

    $staged = git diff --cached --name-only

    if (-not $staged) {
        return
    }

    git commit -m "chore: auto-sync Cursor changes"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Commit created. Pushing to GitHub..." -ForegroundColor Cyan

        git push origin main

        if ($LASTEXITCODE -eq 0) {
            Write-Host "GitHub synchronized successfully." -ForegroundColor Green
        }
        else {
            Write-Host "GitHub push failed." -ForegroundColor Red
        }
    }
}

Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $action | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Deleted -Action $action | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $action | Out-Null

while ($true) {
    Start-Sleep -Seconds 1
}
