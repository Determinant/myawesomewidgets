local setmetatable = setmetatable
local wibox = require("wibox")
local beautiful = require("beautiful")
local vicious = require("vicious")
local vhelpers = require("vicious.helpers")
local rootmod = (...):match("(.-)[^%.]+$")
local linegraph = require(rootmod .. "linegraph")
local mygraph = require(rootmod .. "mygraph")

local cputide = { mt = {} }

local function actual_px(px) return (beautiful.get().scale_factor or 1) * px end
local function gen_cpu_icon(theme)
    return wibox.widget {
        {
            markup = '&#xe026;',
            widget = wibox.widget.textbox,
            font = theme.minor_font or 'pixel 8'
        },
        top = actual_px(theme.siji_icon_padding or 2),
        layout = wibox.container.margin
    }
end

function try_thermal()
    local wargs = {
                    {"coretemp.0/hwmon/hwmon1/", "core"},
                    {"coretemp.0/hwmon/hwmon2/", "core"},
                    {"coretemp.0/hwmon/hwmon3/", "core"},
                    {"coretemp.0/hwmon/hwmon4/", "core"},
                    {"hwmon0/", "hwmon"}
                }
    local zone = { -- Known temperature data sources
        ["sys"]  = {"/sys/class/thermal/",     file = "temp",       div = 1000},
        ["core"] = {"/sys/devices/platform/",  file = "temp2_input",div = 1000},
        ["hwmon"] = {"/sys/class/hwmon/",      file = "temp1_input",div = 1000},
        ["proc"] = {"/proc/acpi/thermal_zone/",file = "temperature"}
    }
    for i = 1, #wargs do
        local warg = wargs[i]
        local _thermal = vhelpers.pathtotable(zone[warg[2]][1] .. warg[1])
        local f = _thermal[zone[warg[2]].file]
        if f then
            return warg
        end
    end
    return nil
end

function cputide.new(args)
    args = args or {}
    local theme = beautiful.get()
    local cpu_icon = args.cpu_icon or gen_cpu_icon(theme)
    local show_icon = (args.show_icon == nil and true) or args.show_icon

    local _cpu_widget_text = wibox.widget {
        text = 'n/a',
        widget = wibox.widget.textbox
    }

    local cpu_widget_text = wibox.widget {
        layout = wibox.layout.fixed.horizontal,
        (show_icon and cpu_icon) or nil,
        _cpu_widget_text
    }

    local cpu_freq = wibox.widget {
        background_color = "#00000000",
        color = theme.cputide_power_color or args.cpu_low_color or "#4b975f",
        max_value = 50,
        min_value = 20,
        line_width = 1,
        widget = linegraph
    }

    local cpu_widget = wibox.widget {
        {
            height = actual_px(theme.cputide_height or args.height or 26),
            width = actual_px(theme.cputide_width or args.width or 50),
            background_color = theme.cputide_bg_color or args.bg_color or "#494b4f",
            base_color = theme.cputide_low_color or args.low_color or "#fabd2f",
            blend_color = theme.cputide_high_color or args.high_color or "#ff0000",
            widget = mygraph
        },
        {
            nil,
            cpu_freq,
            expand = 'outside',
            layout = wibox.layout.align.horizontal
        },
        {
            nil,
            cpu_widget_text,
            expand = 'outside',
            layout = wibox.layout.align.horizontal
        },
        layout = wibox.layout.stack
    }

    vicious.register(_cpu_widget_text,
                    vicious.widgets.thermal,
                    "$1°C",
                    5,
                    try_thermal())
    vicious.register(cpu_widget.children[1], vicious.widgets.cpu, "$1")
    vicious.register(cpu_freq, vicious.widgets.cpufreq, "$1", 2, "cpu0")
    return cpu_widget
end

function cputide.mt:__call(...)
    return cputide.new(...)
end

return setmetatable(cputide, cputide.mt)
