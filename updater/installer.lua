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

-- If there's no local version, we're installing fresh
if not localVersion then
    print("Latest version is " .. versions.latest)

    local commit = versions.versions[versions.latest]
    local newInstallLink = "https://raw.githubusercontent.com/TheJebForge/mics/" .. commit .. "/updater/newInstall.json"

    print("Getting list of directories and files")
    local newInstallFile, err = http.get(newInstallLink)

    if not newInstallFile then
        printError("Failed to get newInstall.json file", err)
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

    local function downloadFile(path)
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

    for _, filePath in pairs(newInstall.files) do
        if not downloadFile(filePath) then
            break
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
    
    print("Done! Restarting...")
    sleep(1)

    os.reboot()
end