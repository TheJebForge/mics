local versionsLink = "https://raw.githubusercontent.com/TheJebForge/mics/master/updater/versions.json"

local function printError(...)
    term.setTextColor(colors.red)
    print(...)
    term.setTextColor(colors.white)
end

local lastYield = os.clock()

local function yieldIfNeeded()
    local clock = os.clock()

    if clock - lastYield > 1 then
        sleep(0)
    end
end

term.setTextColor(colors.white)

-- Retrieving version data of MICS
print("Getting versions.json...")

local versionsFile, err = http.get(versionsLink)

if not versionsFile then
    printError("Failed to get versions.json file", err)
    return
end

local versions = textutils.unserialiseJSON(versionsFile.readAll())
versionsFile.close()

-- Checking local version
local localVersion = nil

if fs.exists("mics/version") then
    local localVersionFile = fs.open("mics/version", "r")
    localVersion = localVersionFile.readAll()
    localVersionFile.close()
end

local function downloadFile(path, commit)
    local link = "https://raw.githubusercontent.com/TheJebForge/mics/" .. commit .. "/" .. path

    term.setTextColor(colors.lightGray)
    write(path .. "...")

    local response, err = http.get(link)
    
    if not response then
        printError("ERR")
        printError("Could not download " .. path, err)

        return false
    end

    local localPath = fs.combine("mics", path)

    local file = fs.open(localPath, "w")
    
    file.write(response.readAll())

    response.close()
    file.close()

    print("OK")
    term.setTextColor(colors.white)

    return true
end

local function runFile(path, commit)
    local link = "https://raw.githubusercontent.com/TheJebForge/mics/" .. commit .. "/" .. path

    term.setTextColor(colors.lightGray)
    print("Running " .. path .. "...")
    term.setTextColor(colors.white)

    local response, err = http.get(link)
    
    if not response then
        printError("Could not fetch " .. path, err)
        return false
    end

    local code, err = load(response.readAll())
    response.close()

    if not code then
        printError("Could not run " .. path, err)
        return false
    end

    code()

    return true
end

-- If there's no local version, we're installing fresh
if not localVersion then
    print("Latest version is " .. versions.latest)

    local commit = versions.versions[versions.latest]
    local newInstallLink = "https://raw.githubusercontent.com/TheJebForge/mics/" .. commit .. "/updater/newInstall.json"

    print("Getting list of directories and files")
    local newInstallFile, err = http.get(newInstallLink)

    if not newInstallFile then
        printError("Failed to get newInstall.json file", err)
        return
    end

    local newInstall = textutils.unserialiseJSON(newInstallFile.readAll())
    newInstallFile.close()

    print("Creating directiories...")
    
    for _, dir in pairs(newInstall.directories) do
        local path = fs.combine("mics", dir)
        
        term.setTextColor(colors.lightGray)

        if not fs.exists(path) then
            fs.makeDir(path)
            print(path)
        else
            print(path .. " already exists")
        end

        term.setTextColor(colors.white)

        yieldIfNeeded()
    end

    print("Downloading files...")

    for _, filePath in pairs(newInstall.files) do
        if not downloadFile(filePath, commit) then
            return
        end

        yieldIfNeeded()
    end

    print("Writing local version...")

    local localVersionFile = fs.open("mics/version", "w")
    localVersionFile.write(versions.latest)
    localVersionFile.close()

    print("Setting up startup.lua...")

    local startupFile = fs.open("startup.lua", "w")
    startupFile.write([[shell.run("mics/mics.lua")]])
    startupFile.close()
else
    print("Loading semver module...")
    
    local semverFile, err = http.get("https://raw.githubusercontent.com/TheJebForge/mics/master/lib/semver.lua")

    if not semverFile then
        printError("Could not download semver.lua", err)
        return
    end

    local semver = load(semverFile.readAll())()
    semverFile.close()

    local localVersionSemver = semver(localVersion)
    local latestVersionSemver = semver(versions.latest)

    if localVersionSemver >= latestVersionSemver then
        print("Up to date!")
        return
    end

    print("Updates are available! Updating...")

    local queue = {
        latestVersionSemver
    }

    while #queue > 0 do
        local version = queue[#queue]
        local stringVersion = tostring(version)

        local update = versions.updates[stringVersion]

        if update then
            local proceedWithThis = true

            if update.dependsOn then
                local previousVersion = semver(update.dependsOn)

                if previousVersion > localVersionSemver then
                    queue[#queue + 1] = previousVersion
                    proceedWithThis = false
                end
            end

            if proceedWithThis then
                print("Updating to " .. stringVersion)

                if update.filesToDelete then
                    for _, path in pairs(update.filesToDelete) do
                        local correctedPath = fs.combine("mics", path)

                        if fs.exists(correctedPath) then
                            term.setTextColor(colors.lightGray)
                            print("Deleting " .. correctedPath)
                            term.setTextColor(colors.white)

                            fs.delete(correctedPath)
                        end
                    end
                end

                local commit = versions.versions[stringVersion]

                if update.filesToDownload then
                    for _, path in pairs(update.filesToDownload) do
                        if not downloadFile(path, commit) then
                            return
                        end
                    end
                end

                if update.filesToRun then
                    for _, path in pairs(update.filesToRun) do
                        if not runFile(path, commit) then
                            return
                        end
                    end
                end

                queue[#queue] = nil
            end
        end
    end

    print("Updating local version...")

    local localVersionFile = fs.open("mics/version", "w")
    localVersionFile.write(versions.latest)
    localVersionFile.close()
end

print("Done! Restarting...")
sleep(1)

os.reboot()