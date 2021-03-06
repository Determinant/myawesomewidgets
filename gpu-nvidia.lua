---------------------------------------------------
-- Licensed under the GNU General Public License v2
-- (based on the implementation of vicious.widgets.cpu)
--  * (c) 2020, Ted Yin <tederminant@gmail.com>
---------------------------------------------------

-- {{{ Grab environment
local io = { popen = io.popen }
local setmetatable = setmetatable
local string = {
    match = string.match
}
-- }}}


-- gpu-nvidia: provides NVIDIA GPU information
local gpu_nvidia = {}
local gpu_usage  = {}

-- {{{ GPU widget type
local function worker(format)
    local f = io.popen("nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,power.draw,power.limit,clocks.sm --format=csv")
    for line in f:lines() do
        util, temp, watt_draw, watt_limit, sm_freq =
            string.match(line, "([0-9]*) %%, ([0-9]*), ([0-9.]*) W, ([0-9.]*) W, ([0-9]*) MHz$")
        if util ~= nil then
            gpu_usage = {util, temp, watt_draw, watt_limit, sm_freq}
            for i = 1, #gpu_usage do
                gpu_usage[i] = tonumber(gpu_usage[i])
            end
        end
    end
    f:close()
    return gpu_usage
end
-- }}}

return setmetatable(gpu_nvidia, { __call = function(_, ...) return worker(...) end })
