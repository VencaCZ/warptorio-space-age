local json = require("cjson")

local function serializeTable(val, name, skipnewlines, depth)
    skipnewlines = skipnewlines or false
    depth = depth or 0

    local tmp = string.rep(" ", depth)

    if name then
        if string.match(name,":") then
            return nil
        end
        if string.match(name,"-") then
            tmp = tmp .. "[\""..name.."\"]" .. " = "
        else
            tmp = tmp .. name .. " = "
        end
    end

    if type(val) == "table" then
        tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")

        for k, v in pairs(val) do
			local new_k = k
			if type(k) == "number" then
				k=nil
			end
            local new_value = serializeTable(v, k, skipnewlines, depth + 1)
            if new_value then
                tmp =  tmp .. new_value .. "," .. (not skipnewlines and "\n" or "")
            end
        end

        tmp = tmp .. string.rep(" ", depth) .. "}"
    elseif type(val) == "number" then
        tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
        tmp = tmp .. string.format("%q", val)
    elseif type(val) == "boolean" then
        tmp = tmp .. (val and "true" or "false")
    else
        tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
    end

    return tmp
end

local function readJsonFile(filePath)
    local file = io.open(filePath, "r")
    if not file then
        error("Could not open file: " .. filePath)
    end
    local content = file:read("*a")
    file:close()
    return content
end

local function main()
    if #arg < 1 then
        print("Usage: lua script.lua <json_file>")
        return
    end
    local jsonFile = arg[1]
    local jsonContent = readJsonFile(jsonFile)
    local tab = json.decode(jsonContent)
    local json_string = serializeTable(tab)

    if tab then
        print("return " .. json_string)
    else
        print("Failed to decode JSON")
    end
end

main()
