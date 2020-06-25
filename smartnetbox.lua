local setmetatable = setmetatable
local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")
local vicious = require("vicious")
local vhelpers = require("vicious.helpers")

local smartnetbox = { mt = {} }

local default_color1 = "#d79921"
local default_color2 = "#fe8019"
local function actual_px(px) return (beautiful.get().scale_factor or 1) * px end

function network_gen_icon(char, color, left, right, theme)
    return wibox.widget {
        {
            markup = string.format('<span color="%s">%s</span>', color, char),
            widget = wibox.widget.textbox,
            font = theme.minor_font or 'pixel 8'
        },
        left = left,
        right = right,
        top = actual_px(theme.siji_icon_padding or 2),
        layout = wibox.container.margin
    }
end

function try_wired_network(candidates)
    for i = 1, #candidates do
        local name = candidates[i]
        local sysnet = vhelpers.pathtotable("/sys/class/net/" .. name)
        --if sysnet ~= nil and sysnet.operstate == 'up\n' then
        if sysnet ~= nil and sysnet.operstate ~= nil then
            return name
        end
    end
    return nil
end

function try_fmt(val)
    local fmts = {"%1.3f", "%2.2f", "%3.1f", " %4.0f"}
    local res = nil
    for i = 1, #fmts do

        local s = string.format(fmts[i], val)
        if #s == 5 then
            res = s
            break
        end
    end
    return res
end

function try_network_format(args, unit, unit_rep, net_dev)
    local down = args[string.format("{%s down_%s}", net_dev, unit)] or 0
    local up = args[string.format("{%s up_%s}", net_dev, unit)] or 0
    local down_rep = try_fmt(down)
    local up_rep = try_fmt(up)
    if down_rep == nil or up_rep == nil then
        return nil
    end
    return {up_rep, down_rep .. unit_rep}
end

function smartnetbox.new(args)
    args = args or {}
    local theme = beautiful.get()
    local color1 = theme.smartnetbox_color1 or args.color1 or default_color1
    local color2 = theme.smartnetbox_color2 or args.color2 or default_color2
    local upload_icon = args.upload_icon or network_gen_icon("&#xe064;", color1, 5, 0, theme)
    local download_icon = args.download_icon or network_gen_icon("&#xe067;", color2, 0, 5, theme)
    local show_icon = (args.show_icon == nil and true) or args.show_icon
    local devs = args.devs or {"wlp8s0", "wlp5s0", "wlp3s0", "wlan0", "enp4s0", "enp0s31f6", "ens33", "eth0"}
    local net_dev = try_wired_network(devs)
    local network_wired_widget = wibox.widget.textbox()
    vicious.register(
        network_wired_widget,
        vicious.widgets.net,
        function (_, args)
            local r =
                try_network_format(args, 'b', 'b', net_dev) or
                try_network_format(args, 'kb', 'k', net_dev) or
                try_network_format(args, 'mb', 'm', net_dev) or
                try_network_format(args, 'gb', 'g', net_dev)
            return string.format('<span color="%s">%s</span>/'..
                                '<span color="%s">%s</span>',
                color1, r[1], color2, r[2])
        end, 2)
    return wibox.widget {
        (show_icon and upload_icon) or nil,
        network_wired_widget,
        (show_icon and download_icon) or nil,
        layout = wibox.layout.fixed.horizontal
    }
end

function smartnetbox.mt:__call(...)
    return smartnetbox.new(...)
end

return setmetatable(smartnetbox, smartnetbox.mt)
