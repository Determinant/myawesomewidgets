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
                     "color", "background_color",
                     "max_value", "min_value", "max_records", "line_width" }

function graph:add_value(value, group)
    table.insert(self._private.values, 1, value)
    if #self._private.values > self._private.max_records then
        table.remove(self._private.values, #self._private.values)
    end
    self:emit_signal("widget::redraw_needed")
    return self
end

function graph:fit(_, width, height)
    return self._private.width, self._private.height
end

function graph:draw(_, cr, width, height)
    local values = self._private.values
    if #values == 0 then return end

    local max_value = self._private.max_value
    local min_value = self._private.min_value or 0
    local xscale = width / self._private.max_records
    local yscale = height / (max_value - min_value)

    if self._private.color ~= nil then
        cr:set_source(color(self._private.color))
    end
    local function cutoff(v)
        return math.max(0, v - min_value)
    end
    cr:set_line_width(self._private.line_width or 2)
    cr:move_to(0, height - cutoff(values[1]) * yscale)
    for i = 1, #values do
        cr:line_to((i - 1) * xscale, height - cutoff(values[i]) * yscale)
    end
    cr:stroke()
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
