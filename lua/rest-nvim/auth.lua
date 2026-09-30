local M = {}
local nio = require("nio")
local logger = require("rest-nvim.logger")

local token_cache = {}

function M.oauth2_client_credentials(token_url, client_id, client_secret)
    local cached = token_cache[client_id]
    if cached and os.time() < (cached.expires_at - 60) then
        logger.debug("OAuth2: using cached token for client_id:" .. client_id)
        return cached.token
    end

    logger.debug("OAuth2: fetching new token from " .. token_url)

    local args = {
        "curl",
        "-s",
        "-X",
        "POST",
        token_url,
        "-H",
        "Content-Type: application/x-www-form-urlencoded",
        "-d",
        "grant_type=client_credentials",
        "-d",
        "client_id=" .. client_id,
        "-d",
        "client_secret=" .. client_secret,
    }

    local future = nio.control.future()

    vim.system(args, { text = true }, function(out)
        vim.schedule(function()
            future.set(out)
        end)
    end)

    local result = future.wait()

    if result.code ~= 0 then
        logger.error("OAuth2 request failed: " .. (result.stderr or ""))
        return ""
    end

    local ok, parsed = pcall(vim.json.decode, result.stdout)
    if not ok or type(parsed) ~= "table" or not parsed.access_token then
        logger.error("OAuth2 parse error or missing token: " .. result.stdout)
        return ""
    end

    local token = parsed.access_token
    local expires_in = tonumber(parsed.expires_in) or 3600

    token_cache[client_id] = {
        token = token,
        expires_at = os.time() + expires_in,
    }

    return token
end

return M
