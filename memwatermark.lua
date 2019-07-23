local setmetatable = setmetatable
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local vicious = require("vicious")
local vhelpers = require("vicious.helpers")

local memwatermark = { mt = {} }

local function actual_px(px) return (beautiful.get().scale_factor or 1) * px end
local function gen_mem_icon(theme)
    return wibox.widget {
        {
            markup = '&#xe021;',
            widget = wibox.widget.textbox,
            font = theme.minor_font or 'pixel 8'
        },
        top = actual_px(theme.siji_icon_padding or 2),
        layout = wibox.container.margin
    }
end

function memwatermark.new(args)
    args = args or {}
    local theme = beautiful.get()
    local mem_icon = args.mem_icon or gen_mem_icon(theme)
    local show_icon = (args.show_icon == nil and true) or args.show_icon

    local _mem_widget_text = wibox.widget {
        text = 'n/a',
        widget = wibox.widget.textbox
    }

    local mem_widget_text = wibox.widget {
        layout = wibox.layout.fixed.horizontal,
        (show_icon and mem_icon) or nil,
        _mem_widget_text
    }

    local mem_widget = wibox.widget {
        {
            {
                max_value = 1,
                value = 0,
                paddings = 0,
                border_width  = 0,
                color = theme.memwatermark_graph_color or args.graph_color or {
                    type = "linear",
                    from = {0, 0},
                    to = {50, 0},
                    stops = {{0, "#fabd2f"},
                    {0.3, "#af3a03"},
                    {1, "#af3a03"}}
                },
                background_color = theme.memwatermark_bg_color or args.bg_color or "#494b4f",
                widget = wibox.widget.progressbar,
            },
            forced_height = actual_px(theme.memwatermark_height or args.width or 26),
            forced_width = actual_px(theme.memwatermark_width or args.width or 40),
            direction = 'east',
            layout = wibox.container.rotate
        },
        {
            nil,
            mem_widget_text,
            expand = 'outside',
            layout = wibox.layout.align.horizontal
        },
        layout = wibox.layout.stack
    }
    
    vicious.register(mem_widget,
                    vicious.widgets.mem,
                    function (_, args)
                        local bar = mem_widget.children[1].children[1]
                        local label = _mem_widget_text
                        bar:set_value(args[1] / 100.0)
                        label.markup = args[1] .. "%"
                    end, 5)
    return mem_widget
end

function memwatermark.mt:__call(...)
    return memwatermark.new(...)
end

return setmetatable(memwatermark, memwatermark.mt)
