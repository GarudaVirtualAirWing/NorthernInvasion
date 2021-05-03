local socket = require('socket.core')

REPL = {}

-- Setup logging
REPL.logfile = io.open(lfs.writedir().."Logs\\REPL.log", "w")
REPL.log = function(str)
    if REPL.logfile then
        REPL.logfile:write(os.time() .. " - " .. str .. "\n")
    end
end

REPL.resetConnection = function()
    REPL.log("Connection is resetting...")
    if REPL.uconn then REPL.uconn:close() end
    REPL.uconn = socket.udp()
    REPL.uconn:settimeout(0)
    REPL.uconn:setsockname("*", 15301)
    REPL.connection = nil
end

REPL.log("ALIVE")
REPL.resetConnection()

mist.scheduleFunction(function()
    -- Preconnect
    if REPL.connection == nil then
        local data, ip, port = REPL.uconn:receivefrom()
        if data == nil then
            return
        end

        if data == "connect" then
            REPL.log("Got connection request from " .. ip)
            REPL.uconn:setpeername(ip, port)
            local success, err = REPL.uconn:send("Connected!\0")
            
            if success then
                REPL.connection = {
                    ip = ip,
                    port = port
                }
                REPL.log("Completed connection request for " .. ip)
                REPL.connection.heartbeat = timer.getTime()
                return
            else
                REPL.log("Connection request for " .. ip .. " failed: " .. err)
                REPL.resetConnection()
            end
        end

    end

    -- Connected
    if REPL.connection ~= nil then
        if timer.getTime() > REPL.connection.heartbeat + 10 then
            REPL.resetConnection()
            return
        end

        local data, err = REPL.uconn:receive()
        if data == nil then
            if err == "timeout" then return end
            REPL.log(err)
            REPL.resetConnection()
            return
        end

        if data == "HEARTBEAT" then
            REPL.log("Got HEARTBEAT")
            REPL.connection.heartbeat = timer.getTime()
            return
        end

        if data == "GOODBYE" then
            REPL.log("Disconnect request from " .. REPL.connection.ip)
            REPL.resetConnection()
            return
        end

        REPL.log("Got command ".. data .. " from " .. REPL.connection.ip)
        local out = assert(loadstring('return ' .. data))
        if out then
            local success, err = pcall(function()
                local success, output = pcall(out)
                if success then
                    if output == nil then output = "nil" end
                    if type(output) == "table" then
                        output = mist.utils.tableShow(output)
                    else
                        output = tostring(output)
                    end
                    REPL.uconn:send(os.time() .. " - " .. output .. "\0")
                    return
                else
                    REPL.log(os.time() .. " - " .. output)
                    REPL.uconn:send(os.time() .. " - " .. output .. "\0")
                    return
                end
            end)

            if not success then
                REPL.log(os.time() .. " - " .. err)
                REPL.uconn:send(os.time() .. " - " .. err .. "\0")
            end
        end
    end
end, {}, timer.getTime() + 1, 1)
