local setmetatable = setmetatable
local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")
local naughty = require("naughty")
local rootmod = (...):match("(.-)[^%.]+$")
local mpc = require(rootmod .. "mpc")

local mpdbox = { mt = {} }

local function actual_px(px) return (beautiful.get().scale_factor or 1) * px end

function shorten_str(s, len)
    if string.len(s) > len then
        s = string.sub(s, 0, len - 1) .. ".."
    end
    return s
end

function html_escape(s)
    if s == nil then return s end
    s = string.gsub(s, '<', '&lt;')
    s = string.gsub(s, '&', '&amp;')
    return string.gsub(s, '>', '&gt;')
end

function gen_icon(char, color, theme)
    return wibox.widget {
        {
            markup = string.format('<span color="%s">%s</span>', color, char),
            widget = wibox.widget.textbox,
            font = theme.minor_font or 'pixel 8'
        },
        top = actual_px(theme.siji_icon_padding or 2),
        layout = wibox.container.margin
    }
end

function mpdbox.new(args)
    args = args or {}
    local theme = beautiful.get()
    local bracket_left = args.bracket_left or '('
    local bracket_right = args.bracket_right or ')'
    local color1 = theme.mpdbox_color1 or args.color1 or "#d79921"
    local color2 = theme.mpdbox_color2 or args.color2 or "#fe8019"

    local music_icon = args.music_icon or gen_icon("&#xe05c;", color2, theme)
    local pause_icon = args.pause_icon or gen_icon("&#xe059;", color2, theme)
    local show_brackets = (args.show_brackets == nil and true) or args.show_brackets
    local show_music_icon = (args.show_music_icon == nil and true) or args.show_music_icon
    local mpc_conn
    local mpdbox_progress = wibox.widget {
        width = actual_px(theme.mpdbox_width or args.width or 100),
        max_value = 1,
        value = 0,
        paddings = { top = actual_px(3), bottom = actual_px(3) },
        border_width = 0,
        color = theme.mpdbox_bg_progress or args.bg_progress or {
            type = "linear",
            from = {0, 0},
            to = {100, 0},
            stops = {{0, "#fabd2f88"},
                    {1, "#af3a0344" }}
        },
        bar_shape = gears.shape.rounded_bar,
        background_color = gears.color.transparent,
        widget = wibox.widget.progressbar,
    }

    local mpc_timeout_poller = gears.timer {
        timeout = 1,
        autostart = false,
        callback = function ()
            mpc_conn:send("ping")
        end
    }

    local mpdbox_text = wibox.widget {
        widget = wibox.widget.textbox,
        markup = "n/a",
    }

    local function mpc_error_handler(err)
        mpdbox_text:set_markup(
            string.format("err: %s <span font_weight=\"bold\">|</span> ", tostring(err)))
        mpc_timeout_poller:start()
    end

    local mpdbox_scroll = wibox.widget {
        layout = wibox.container.margin,
        left = ((show_brackets or show_music_icon) and 2) or 0,
        right = (show_brackets and 2) or 0,
        {
            layout = wibox.container.scroll.horizontal,
            max_size = actual_px(100),
            step_function = wibox.container.scroll.step_functions
                                .linear_increase,
            speed = 8,
            fps = 1,
            mpdbox_text
        }
    }

    local _icon = (show_music_icon and wibox.widget {
        music_icon,
        layout = wibox.container.margin
    }) or nil

    local _mpdbox = wibox.widget {
        layout = wibox.layout.fixed.horizontal,
        (show_brackets and {
            widget = wibox.widget.textbox,
            text = bracket_left
        }) or nil,
        _icon,
        {
            {
                reflection = {horizontal = true},
                layout = wibox.container.mirror,
                mpdbox_progress
            },
            mpdbox_scroll,
            layout = wibox.layout.stack
        },
        (show_brackets and {
            widget = wibox.widget.textbox,
            text = bracket_right
        }) or nil
    }

    _mpdbox.mpdbox_text = mpdbox_text
    _mpdbox.mpdbox_progress = mpdbox_progress
    _mpdbox._mpc_poller = gears.timer {
        timeout = 1,
        autostart = true,
        callback = function ()
            mpc_conn:send("status", function(_, result)
                _mpdbox._mpc_duration,
                _mpdbox._mpc_elapsed =
                    result.duration, result.elapsed
                _mpdbox:update_progress()
                if result.state ~= "play" then
                    _mpdbox._mpc_poller:stop()
                end
            end)
        end
    }

    _mpdbox._mpc_title = ""
    _mpdbox._mpc_artist = ""
    _mpdbox._mpc_album = ""
    _mpdbox._mpc_track = ""
    _mpdbox._mpc_state = "stop"
    _mpdbox._mpc_elapsed = 0
    _mpdbox._mpc_duration = 0

    mpc_conn = mpc.new(nil, nil, nil, mpc_error_handler,
        "status", function(_, result)
            mpc_timeout_poller:stop()
            _mpdbox._mpc_state,
            _mpdbox._mpc_duration,
            _mpdbox._mpc_elapsed =
                result.state, result.duration or 0, result.elapsed or 0
            _mpdbox:update_playstate()
        end,
        "currentsong", function(_, result)
            _mpdbox._mpc_title,
            _mpdbox._mpc_artist,
            _mpdbox._mpc_track,
            _mpdbox._mpc_album =
                result.title, result.artist, result.track, result.album
            _mpdbox:update_playstate()
        end)

    _mpdbox.mpc_conn = mpc_conn
    _mpdbox.update_progress = mpdbox.update_progress
    _mpdbox.update_playstate = mpdbox.update_playstate
    _mpdbox.color1 = color1
    _mpdbox.color2 = color2
    _mpdbox._icon = _icon
    _mpdbox._music_icon = music_icon
    _mpdbox._pause_icon = pause_icon
    return _mpdbox
end

function mpdbox.update_progress(mpcw)
    mpcw.mpdbox_progress:set_value(1 - mpcw._mpc_elapsed / mpcw._mpc_duration)
end


function mpdbox.update_playstate(mpcw)
    local text = string.format(
        '<span color="%s">%s</span> by ' ..
        '<span color="%s">%s</span> ab. %s @ %s',
        mpcw.color1, html_escape(mpcw._mpc_title) or "n/a",
        mpcw.color2, html_escape(mpcw._mpc_artist) or "n/a",
        shorten_str(html_escape(mpcw._mpc_album) or "n/a", 10),
        html_escape(mpcw._mpc_track) or "n/a")

    if mpcw._mpc_state == "pause" then
        if mpcw._icon ~= nil then
            mpcw._icon:set_children({mpcw._pause_icon})
        end
        text = text .. " <span font_weight=\"bold\">|paused|</span> "
        mpcw._mpc_poller:stop()
    elseif mpcw._mpc_state == "stop" then
        text = text .. " <span font_weight=\"bold\">|stopped|</span> "
        mpcw._mpc_poller:stop()
    else
        if mpcw._icon ~= nil then
            mpcw._icon:set_children({mpcw._music_icon})
        end
        text = text .. " <span font_weight=\"bold\">|</span> "
        mpcw._mpc_poller:again()
    end

    mpcw:update_progress()
    mpcw.mpdbox_text:set_markup(text)
end

function mpdbox.mt:__call(...)
    return mpdbox.new(...)
end

return setmetatable(mpdbox, mpdbox.mt)
