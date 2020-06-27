local setmetatable = setmetatable
local wibox = require("wibox")
local beautiful = require("beautiful")
local vicious = require("vicious")
local vhelpers = require("vicious.helpers")
local rootmod = (...):match("(.-)[^%.]+$")
local mygraph = require(rootmod .. "mygraph")
local linegraph = require(rootmod .. "linegraph")
local gpu_nvidia = require(rootmod .. "gpu-nvidia")

local gputide = { mt = {} }

local function actual_px(px) return (beautiful.get().scale_factor or 1) * px end
local function gen_gpu_icon(theme)
    return wibox.widget {
        {
            markup = '&#xe022;',
            widget = wibox.widget.textbox,
            font = theme.minor_font or 'pixel 8'
        },
        top = actual_px(theme.siji_icon_padding or 2),
        layout = wibox.container.margin
    }
end

function gputide.new(args)
    args = args or {}
    local theme = beautiful.get()
    local gpu_icon = args.gpu_icon or gen_gpu_icon(theme)
    local show_icon = (args.show_icon == nil and true) or args.show_icon
    local height = actual_px(theme.gputide_height or args.height or 26)
    local width = actual_px(theme.gputide_width or args.width or 50)


    local _gpu_widget_text = wibox.widget {
        text = 'n/a',
        widget = wibox.widget.textbox
    }

    local gpu_widget_text = wibox.widget {
        layout = wibox.layout.fixed.horizontal,
        (show_icon and gpu_icon) or nil,
        _gpu_widget_text
    }

    local gpu_curves = wibox.widget {
        width = width,
        height = height,
        background_color = "#00000000",
        colors = {
            theme.gputide_power_color or "#82a6fa",
            theme.gputide_freq_color or "#4b975f",
        },
        line_widths = { 2, 1 },
        widget = linegraph
    }

    local gpu_widget = wibox.widget {
        {
            width = width,
            height = height,
            background_color = theme.gputide_bg_color or args.bg_color or "#494b4f",
            base_color = theme.gputide_low_color or args.low_color or "#fabd2f",
            blend_color = theme.gputide_high_color or args.high_color or "#ff0000",
            widget = mygraph
        },
        {
            nil,
            gpu_curves,
            expand = 'outside',
            layout = wibox.layout.align.horizontal
        },
        {
            nil,
            gpu_widget_text,
            expand = 'outside',
            layout = wibox.layout.align.horizontal
        },
        layout = wibox.layout.stack
    }

    vicious.register(gpu_widget, gpu_nvidia, function(_, args)
        gpu_widget.children[1]:add_value(args[1] / 100)
        _gpu_widget_text:set_text(string.format("%.0f°C", args[2]))
        gpu_curves:add_value({args[3] / args[4], args[5] / 2000})
    end)

    return gpu_widget
end

function gputide.mt:__call(...)
    return gputide.new(...)
end

return setmetatable(gputide, gputide.mt)
