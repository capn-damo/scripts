--==============================================================================
-- Nvidia-gauges.lua, based on sun_rings
-- by damo, August 2018 <damo@bunsenlabs.org>
--==============================================================================
--                            sun_rings.lua
--
--  Date    : 05 July 2017
--  Author  : Sun For Miles
--  Version : v0.41
--  License : Distributed under the terms of GNU GPL version 2 or later
--
--  This version is a modification of seamod_rings.lua which is modification of
--  lunatico_rings.lua which is modification of conky_orange.lua
--
--  conky_orange.lua:    http://gnome-look.org/content/show.php?content=137503
--  lunatico_rings.lua:  http://gnome-look.org/content/show.php?content=142884
--  seamod_rings.lua:    http://custom-linux.deviantart.com/art/Conky-Seamod-v0-1-283461046
--==============================================================================

require 'cairo'

--                                                                    gauge DATA
gauge = {
{
    name='nvidia',                 arg='temp',                  max_value=100,
    x=50,                          y=55,
    graph_radius=30,
    graph_thickness=7,
    graph_start_angle=225,
    graph_unit_angle=2.7,          graph_unit_thickness=2.7,
    graph_bg_colour=0xffffff,      graph_bg_alpha=0.1,
    graph_fg_colour=0x76DFE6,      graph_fg_alpha=0.3,
    hand_fg_colour=0x05C5DA,       hand_fg_alpha=0.5,
    txt_radius=22,                 hand_radius=24,
    hand_width = 2,
    txt_weight=0,                  txt_size=9.0,
    txt_fg_colour=0x678b8b,        txt_fg_alpha=0,
    graduation_radius=23,
    graduation_thickness=0,        graduation_mark_thickness=2,
    graduation_unit_angle=2.7,
    graduation_fg_colour=0xFFFFFF, graduation_fg_alpha=0.3,
    caption='',
    caption_weight=0.5,            caption_size=12.0,
    caption_fg_colour=0x05C5DA,    caption_fg_alpha=0.7,
    font = 'Noto Sans Mono',
},
-- This is a bit of a cheat: layered bg, for red sector, with fg no alpha
   { -- gpu high temps bg section (red)
    name='nvidia',                 arg='temp',                  max_value=6,
    x=50,                          y=55,
    graph_radius=30,
    graph_thickness=7,
    graph_start_angle=119,
    graph_unit_angle=2.7,          graph_unit_thickness=2.7,
    graph_bg_colour=0xff0000,      graph_bg_alpha=0.3,
    graph_fg_colour=0xCE7646,      graph_fg_alpha=0,
    hand_fg_colour=0x477CAF,       hand_fg_alpha=0.0,
    txt_radius=22,                 hand_radius=0,
    hand_width = 0,
    txt_weight=0,                  txt_size=9.0,
    txt_fg_colour=0xCE7646,        txt_fg_alpha=0,
    graduation_radius=23,
    graduation_thickness=8,        graduation_mark_thickness=0,
    graduation_unit_angle=2.7,
    graduation_fg_colour=0xFFFFFF, graduation_fg_alpha=0.5,
    caption='',
    caption_weight=0.5,            caption_size=8.0,
    caption_fg_colour=0xFFFFFF,    caption_fg_alpha=0.7,
    font = 'Noto Sans Mono',
    },
{
    name='nvidia',                 arg='gpuutil',               max_value=100,
    x=90,                          y=115,
    graph_radius=30,
    graph_thickness=7,
    graph_start_angle=225,
    graph_unit_angle=2.7,          graph_unit_thickness=2.7,
    graph_bg_colour=0xffffff,      graph_bg_alpha=0.1,
    graph_fg_colour=0x76DFE6,      graph_fg_alpha=0.3,
    hand_fg_colour=0x05C5DA,       hand_fg_alpha=0.5,
    txt_radius=22,                 hand_radius=24,
    hand_width = 2,
    txt_weight=0,                  txt_size=9.0,
    txt_fg_colour=0x678b8b,        txt_fg_alpha=0,
    graduation_radius=23,
    graduation_thickness=0,        graduation_mark_thickness=2,
    graduation_unit_angle=2.7,
    graduation_fg_colour=0xFFFFFF, graduation_fg_alpha=0.3,
    caption='',
    caption_weight=0.5,            caption_size=12.0,
    caption_fg_colour=0xFFFFFF,    caption_fg_alpha=0.5,
    font = 'Noto Sans Mono',

},
{
    name='nvidia',                 arg='memutil',               max_value=100,
    x=130,                          y=175,
    graph_radius=30,
    graph_thickness=7,
    graph_start_angle=225,
    graph_unit_angle=2.7,          graph_unit_thickness=2.7,
    graph_bg_colour=0xffffff,      graph_bg_alpha=0.1,
    graph_fg_colour=0x76DFE6,      graph_fg_alpha=0.3,
    hand_fg_colour=0x05C5DA,       hand_fg_alpha=0.5,
    txt_radius=22,                 hand_radius=24,
    hand_width = 2,
    txt_weight=0,                  txt_size=9.0,
    txt_fg_colour=0x678b8b,        txt_fg_alpha=0,
    graduation_radius=23,
    graduation_thickness=0,        graduation_mark_thickness=2,
    graduation_unit_angle=2.7,
    graduation_fg_colour=0xFFFFFF, graduation_fg_alpha=0.3,
    caption='',
    caption_weight=0.5,            caption_size=12.0,
    caption_fg_colour=0xFFFFFF,    caption_fg_alpha=0.5,
    font = 'Noto Sans Mono',

},
{
    name='nvidia',                 arg='fanlevel',               max_value=100,
    x=170,                          y=235,
    graph_radius=30,
    graph_thickness=7,
    graph_start_angle=225,
    graph_unit_angle=2.7,          graph_unit_thickness=2.7,
    graph_bg_colour=0xffffff,      graph_bg_alpha=0.1,
    graph_fg_colour=0x76DFE6,      graph_fg_alpha=0.3,
    hand_fg_colour=0x05C5DA,       hand_fg_alpha=0.5,
    hand_width = 2,
    txt_radius=22,                 hand_radius=24,
    txt_weight=0,                  txt_size=9.0,
    txt_fg_colour=0x678b8b,        txt_fg_alpha=0,
    graduation_radius=23,
    graduation_thickness=0,        graduation_mark_thickness=2,
    graduation_unit_angle=2.7,
    graduation_fg_colour=0xFFFFFF, graduation_fg_alpha=0.3,
    caption='',
    caption_weight=0.5,            caption_size=12.0,
    caption_fg_colour=0xFFFFFF,    caption_fg_alpha=0.5,
    font = 'Noto Sans Mono',

},
{
    name='nvidia_power',           arg='',                      max_value=300,
    x=210,                         y=295,
    graph_radius=30,
    graph_thickness=7,
    graph_start_angle=225,
    graph_unit_angle=0.9,         graph_unit_thickness=2.7,
    graph_bg_colour=0xffffff,      graph_bg_alpha=0.1,
    graph_fg_colour=0x76DFE6,      graph_fg_alpha=0.3,
    hand_fg_colour=0x05C5DA,       hand_fg_alpha=0.5,
    txt_radius=22,                 hand_radius=24,
    hand_width = 2,
    txt_weight=0,                  txt_size=9.0,
    txt_fg_colour=0x678b8b,        txt_fg_alpha=0,
    graduation_radius=23,
    graduation_thickness=0,        graduation_mark_thickness=2,
    graduation_unit_angle=0.9,
    graduation_fg_colour=0xFFFFFF, graduation_fg_alpha=0.3,
    caption='true',
    caption_weight=0.5,            caption_size=10.0,
    caption_fg_colour=0x05C5DA,    caption_fg_alpha=1.0,
    font = 'Noto Sans Mono',
},
}

-------------------------------------------------------------------------------
--                                                                 rgb_to_r_g_b
-- converts color in hexa to decimal
--
function rgb_to_r_g_b(colour, alpha)
    return ((colour / 0x10000) % 0x100) / 255., ((colour / 0x100) % 0x100) / 255., (colour % 0x100) / 255., alpha
end

-------------------------------------------------------------------------------
--                                                            angle_to_position
-- convert degree to rad and rotate (0 degree is top/north)
--
function angle_to_position(start_angle, current_angle)
    local pos = current_angle + start_angle
    return ( ( pos * (2 * math.pi / 360) ) - (math.pi / 2) )
end

-------------------------------------------------------------------------------
-- displays gauges
--                                                              draw_gauge_ring
function draw_gauge_ring(display, data, value)
    local max_value = data['max_value']
    local x, y = data['x'], data['y']
    local graph_radius = data['graph_radius']
    local hand_radius = data['hand_radius']
    local hand_width = data['hand_width']
    local graph_thickness, graph_unit_thickness = data['graph_thickness'], data['graph_unit_thickness']
    local graph_start_angle = data['graph_start_angle']
    local graph_unit_angle = data['graph_unit_angle']
    local graph_bg_colour, graph_bg_alpha = data['graph_bg_colour'], data['graph_bg_alpha']
    local graph_fg_colour, graph_fg_alpha = data['graph_fg_colour'], data['graph_fg_alpha']
    local hand_fg_colour, hand_fg_alpha = data['hand_fg_colour'], data['hand_fg_alpha']
    local graph_end_angle = (max_value * graph_unit_angle) % 360
    local font = data['font']
    local caption = data['caption']

    -- background ring
    cairo_arc(display, x, y, graph_radius, angle_to_position(graph_start_angle, 0), angle_to_position(graph_start_angle, graph_end_angle))
    cairo_set_source_rgba(display, rgb_to_r_g_b(graph_bg_colour, graph_bg_alpha))
    cairo_set_line_width(display, graph_thickness)
    cairo_stroke(display)

    -- arc of value
    local val = value % (max_value + 1)
    local start_arc = 0
    local stop_arc = 0
    local i = 1
    while i <= val do
        start_arc = (graph_unit_angle * i) - graph_unit_thickness
        stop_arc = (graph_unit_angle * i)
        cairo_arc(display, x, y, graph_radius, angle_to_position(graph_start_angle, start_arc), angle_to_position(graph_start_angle, stop_arc))
        cairo_set_source_rgba(display, rgb_to_r_g_b(graph_fg_colour, graph_fg_alpha))
        cairo_stroke(display)
        i = i + 1
    end
    local angle = start_arc

    -- hand
    start_arc = (graph_unit_angle * val) - graph_unit_thickness
    stop_arc = (graph_unit_angle * val)
    cairo_set_line_width(display, hand_width)
    cairo_move_to(display,x,y)
    cairo_arc(display, x, y, hand_radius, angle_to_position(graph_start_angle, start_arc), angle_to_position(graph_start_angle, start_arc))
    cairo_set_source_rgba(display, rgb_to_r_g_b(hand_fg_colour, hand_fg_alpha))
    cairo_stroke(display)

    -- graduations marks
    local graduation_radius = data['graduation_radius']
    local graduation_thickness, graduation_mark_thickness = data['graduation_thickness'], data['graduation_mark_thickness']
    local graduation_unit_angle = data['graduation_unit_angle']
    local graduation_fg_colour, graduation_fg_alpha = data['graduation_fg_colour'], data['graduation_fg_alpha']
    if graduation_radius > 0 and graduation_thickness > 0 and graduation_unit_angle > 0 then
        local nb_graduation = graph_end_angle / graduation_unit_angle
        local i = 0
        while i < nb_graduation do
            cairo_set_line_width(display, graduation_thickness)
            start_arc = (graduation_unit_angle * i) - (graduation_mark_thickness / 2)
            stop_arc = (graduation_unit_angle * i) + (graduation_mark_thickness / 2)
            cairo_arc(display, x, y, graduation_radius, angle_to_position(graph_start_angle, start_arc), angle_to_position(graph_start_angle, stop_arc))
            cairo_set_source_rgba(display,rgb_to_r_g_b(graduation_fg_colour,graduation_fg_alpha))
            cairo_stroke(display)
            cairo_set_line_width(display, graph_thickness)
            i = i + 1
        end
    end

    -- text
    local txt_radius = data['txt_radius']
    local txt_weight, txt_size = data['txt_weight'], data['txt_size']
    local txt_fg_colour, txt_fg_alpha = data['txt_fg_colour'], data['txt_fg_alpha']
    local movex = txt_radius * math.cos(angle_to_position(graph_start_angle, angle))
    local movey = txt_radius * math.sin(angle_to_position(graph_start_angle, angle))
    cairo_select_font_face (display, font, CAIRO_FONT_SLANT_NORMAL, txt_weight)
    cairo_set_font_size (display, txt_size)
    cairo_set_source_rgba (display, rgb_to_r_g_b(txt_fg_colour, txt_fg_alpha))
    cairo_move_to (display, x + movex - (txt_size / 2), y + movey + 3)
    cairo_show_text (display, value)
    cairo_stroke (display)

    -- caption
    if caption == "true" and data['arg'] == "" then
        caption = os.caption("nvidia-smi --format=csv,noheader --query-gpu=power.draw",false)
    else
        caption = data['caption']
    end
    local caption_weight, caption_size = data['caption_weight'], data['caption_size']
    local caption_fg_colour, caption_fg_alpha = data['caption_fg_colour'], data['caption_fg_alpha']
    local tox = graph_radius * (math.cos((graph_start_angle * 2 * math.pi / 360)-(math.pi/2)))
    local toy = graph_radius * (math.sin((graph_start_angle * 2 * math.pi / 360)-(math.pi/2)))
    cairo_select_font_face (display, font, CAIRO_FONT_SLANT_NORMAL, caption_weight);
    cairo_set_font_size (display, caption_size)
    cairo_set_source_rgba (display, rgb_to_r_g_b(caption_fg_colour, caption_fg_alpha))
    cairo_move_to (display, x + tox + 2, y + toy + 15)
    -- bad hack but not enough time !
    --if graph_start_angle < 105 then
        --cairo_move_to (display, x + tox - 30, y + toy + 1)
    --end
    cairo_show_text (display, caption)
    cairo_stroke (display)
end

function get_caption(caption_text,arg)
    if caption_text == "true" and arg == "" then
        return "power"
    end

end

function os.capture(cmd, raw)
      local f = assert(io.popen(cmd, 'r'))
      local s = assert(f:read('*a'))
      f:close()
      if raw then return n end
      s = string.gsub(s, '^%s+', '')
      s = string.gsub(s, '%s+$', '')
      s = string.gsub(s, 'W',' ')   -- remove "Watts symbol"
      s = string.gsub(s, '[\n\r]+', ' ')
      n = tonumber(s)
      return n
end
function os.caption(cmd, raw)
      local f = assert(io.popen(cmd, 'r'))
      local s = assert(f:read('*a'))
      f:close()
      if raw then return s end
      s = string.gsub(s, '^%s+', '')
      s = string.gsub(s, '%s+$', '')
      s = string.gsub(s, '[\n\r]+', ' ')
      return s
end
-------------------------------------------------------------------------------
--                                                               go_gauge_rings
-- loads data and displays gauges
--
function go_gauge_rings(display)
    local function load_rings(display, data)
        if data['name'] == 'nvidia' then
            str = string.format('${%s %s}',data['name'], data['arg'])
            str = conky_parse(str)
            value = tonumber(str)
            draw_gauge_ring(display, data, value)
        else
            local power = os.capture("nvidia-smi --format=csv,noheader --query-gpu=power.draw",false)
            value = tonumber(power)
            draw_gauge_ring(display, data, value)
        end
    end
    for i in pairs(gauge) do
        load_rings(display, gauge[i])
    end
end


-------------------------------------------------------------------------------
--                                                                         MAIN
function conky_main()
    if conky_window == nil then
        return
    end

    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
    local display = cairo_create(cs)

    local updates = conky_parse('${updates}')
    update_num = tonumber(updates)

    if update_num > 5 then
        go_gauge_rings(display)
    end

    cairo_surface_destroy(cs)
    cairo_destroy(display)

end
