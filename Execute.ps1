$FilesToRun = Get-ChildItem -Path $ExtractFolder -Recurse -File |
    Where-Object { $_.Extension -in ".exe", ".msi" }

foreach ($File in $FilesToRun) {

    Write-Info "Running $($File.FullName)..."

    switch ($File.Extension.ToLower()) {
        ".exe" {
            Start-Process -FilePath $File.FullName -Wait
        }
        ".msi" {
            Start-Process -FilePath "msiexec.exe" `
                -ArgumentList "/i `"$($File.FullName)`"" `
                -Wait
        }
    }

    Write-Good "Finished $($File.Name)"
}
