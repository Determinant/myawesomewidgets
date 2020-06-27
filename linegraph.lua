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

local properties = { "width", "height",
                     "colors", "color", "background_color",
                     "max_value", "min_value", "max_records",
                     "line_width", "line_widths" }

function graph:add_value(value, group)
    if type(value) == "number" then
        value = {value}
    end
    for i = 1, #value do
        local values = self._private.values[i]
        if values == nil then
            values = {}
            self._private.values[i] = values
        end
        table.insert(values, 1, value[i])
        if #values > self._private.max_records then
            table.remove(values, #values)
        end
    end
    self:emit_signal("widget::redraw_needed")
    return self
end

function graph:fit(_, width, height)
    return self._private.width, self._private.height
end

function graph:draw(_, cr, width, height)
    for i = 1, #self._private.values do
        local values = self._private.values[i]
        if #values == 0 then return end

        local max_value = self._private.max_value
        local min_value = self._private.min_value or 0
        local xscale = width / self._private.max_records
        local yscale = height / (max_value - min_value)
        local c = self._private.colors[i] or self._private.color
        if c ~= nil then
            cr:set_source(color(c))
        end
        local function gety(v)
            return height - math.max(0, v - min_value) * yscale
        end
        cr:set_line_width(
            self._private.line_widths[i] or self._private.line_width or 1)
        cr:move_to(0, gety(values[1]))
        for i = 1, #values do
            cr:line_to((i - 1) * xscale, gety(values[i]))
        end
        cr:stroke()
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
    _graph._private.line_widths    = {}
    _graph._private.max_value = 1
    _graph._private.max_records = width

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
