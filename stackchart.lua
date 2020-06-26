local setmetatable = setmetatable
local ipairs = ipairs
local math = math
local table = table
local type = type
local color = require("gears.color")
local base = require("wibox.widget.base")
local beautiful = require("beautiful")
local naughty = require("naughty")
local graph = { mt = {} }

function hex2rgb(hex)
    hex = hex:gsub("#","")
    return {tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))}
end

function rgb_blend(rgb1, rgb2, alpha)
    function _blend(c1, c2)
        return math.floor((alpha * (c1 / 255.0) + (1 - alpha) * (c2 / 255.0)) * 255)
    end
    return {_blend(rgb1[1], rgb2[1]),
            _blend(rgb1[2], rgb2[2]),
            _blend(rgb1[3], rgb2[3])}
end

function rgb2hex(rgb)
    return string.format("#%02x%02x%02x", rgb[1], rgb[2], rgb[3])
end

local properties = { "width", "height",
                     "colors", "color", "background_color", "padding" }

function graph:add_value(value, group)
    self._private.values = value
    self:emit_signal("widget::redraw_needed")
    return self
end

function graph:fit(_, width, height)
    return self._private.width, self._private.height
end

function graph:draw(_, cr, width, height)
    local values = self._private.values
    if #values == 0 then return end

    local yscale = height / #values

    cr:set_line_width(self._private.line_width or 1.25)
    local sum = 0
    for i = 1, #values do
        sum = sum + values[i]
    end
    local side_margin = self._private.padding * width
    local acc_ratio = self._private.padding / 2
    for i = 1, #values do
        local r = values[i] / sum
        local ratio = math.max(r - self._private.padding, 0)
        local c = (type(values[i]) == "table" and values[i]['color']) or self._private.colors[i] or self._private.color
        cr:rectangle(side_margin, height * acc_ratio, width - side_margin * 2, height * ratio)
        if c ~= nil then
            cr:set_source(color(rgb2hex(rgb_blend({0, 0, 0}, hex2rgb(c), 0.5))))
        end
        cr:fill_preserve()
        if c ~= nil then
            cr:set_source(color(c))
        end
        cr:stroke()
        acc_ratio = acc_ratio + r
    end
end

--- Clear the graph.
function graph:clear()
    self._private.values = {}
    self:emit_signal("widget::redraw_needed")
    return self
end

--- Set the graph height.
-- @param height The height to set.
function graph:set_height(height)
    if height >= 5 then
        self._private.height = height
        self:emit_signal("widget::layout_changed")
    end
    return self
end

--- Set the graph width.
-- @param width The width to set.
function graph:set_width(width)
    if width >= 5 then
        self._private.width = width
        self:emit_signal("widget::layout_changed")
    end
    return self
end

-- Build properties function
for _, prop in ipairs(properties) do
    if not graph["set_" .. prop] then
        graph["set_" .. prop] = function(_graph, value)
            if _graph._private[prop] ~= value then
                _graph._private[prop] = value
                _graph:emit_signal("widget::redraw_needed")
            end
            return _graph
        end
    end
    if not graph["get_" .. prop] then
        graph["get_" .. prop] = function(_graph)
            return _graph._private[prop]
        end
    end
end

function graph.new(args)
    args = args or {}
    local width = args.width or 100
    local height = args.height or 20

    if width < 5 or height < 5 then return end

    local _graph = base.make_widget(nil, nil, {enable_properties = true})

    _graph._private.width     = width
    _graph._private.height    = height
    _graph._private.values    = {}
    _graph._private.colors    = {}
    _graph._private.padding   = 0.05

    _graph.add_value = graph["add_value"]
    _graph.clear = graph["clear"]
    _graph.draw = graph["draw"]
    _graph.fit = graph["fit"]

    for _, prop in ipairs(properties) do
        _graph["set_" .. prop] = graph["set_" .. prop]
        _graph["get_" .. prop] = graph["get_" .. prop]
    end

    return _graph
end

function graph.mt:__call(...)
    return graph.new(...)
end

return setmetatable(graph, graph.mt)
