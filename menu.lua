
--[[

     Awesome-Freedesktop
     Freedesktop.org compliant desktop entries and menu

     Menu section

     Licensed under GNU General Public License v2
      * (c) 2016, Luke Bonham
      * (c) 2014, Harvey Mittens

--]]

local Gio        = require("lgi").Gio
local awful_menu = require("awful.menu")
local menu_gen   = require("menubar.menu_gen")
local menu_utils = require("menubar.utils")

local io, pairs, string, table, os = io, pairs, string, table, os

-- Expecting a wm_name of awesome omits too many applications and tools
menu_utils.wm_name = ""

-- Menu
-- freedesktop.menu
local menu = {}

-- Check if a path is a directory.
-- @tparam string path The directory path
-- @treturn boolean True if path exists and is a directory
function menu.is_dir(path)
    return Gio.File.new_for_path(path):query_file_type({}) == "DIRECTORY"
end

-- Remove non existent paths in order to avoid issues
local existent_paths = {}
for k,v in pairs(menu_gen.all_menu_dirs) do
    if menu.is_dir(v) then
        table.insert(existent_paths, v)
    end
end
menu_gen.all_menu_dirs = existent_paths

-- Determines whether an table includes a certain element
-- @param tab a given table
-- @param val the element to search for
-- @return true if the given string is found within the search table; otherwise, false if not
function menu.has_value (tab, val)
    for index, value in pairs(tab) do
        if val:find(value) then
            return true
        end
    end
    return false
end

-- Icon names for the desktop environments found in OnlyShowIn keys.
local desktop_icons = {
    GNOME = "gnome", KDE = "kde", LXDE = "lxde", LXQt = "lxqt", MATE = "mate",
    Unity = "unity", XFCE = "xfce4-logo", ["X-Cinnamon"] = "cinnamon",
    ubuntu = "ubuntu-logo",
}

local function by_name(a, b)
    return a[1] < b[1]
end

-- Use MenuBar parsing utils to build a menu for Awesome
-- @param args.before Items placed before the generated categories
-- @param args.after Items placed after the generated categories
-- @param args.skip_items Names (Lua patterns) of entries to leave out
-- @param args.sub_menu Name of a single item holding the generated categories
-- @param args.group_by_desktop When true, an entry whose .desktop file has an
--   OnlyShowIn key goes into a sub-menu of its category named after the first
--   desktop environment listed there, before the entries meant for every
--   environment. Needs menubar.menu_gen entries carrying `only_show_in`.
-- @return awful.menu
function menu.build(args)
    local args       = args or {}
    local before     = args.before or {}
    local after      = args.after or {}
    local skip_items = args.skip_items or {}
    local sub_menu   = args.sub_menu or false
    local group_by_desktop = args.group_by_desktop or false

    local result     = {}
    local _menu      = awful_menu({ items = before })

    menu_gen.generate(function(entries)
        -- Add category icons
        for k, v in pairs(menu_gen.all_categories) do
            table.insert(result, { k, {}, v.icon })
        end

        -- Get items table
        for k, v in pairs(entries) do
            for _, cat in pairs(result) do
                if cat[1] == v.category then
                    if not menu.has_value(skip_items, v.name) then
                        local target = cat[2]
                        local desktop = group_by_desktop and v.only_show_in
                                        and v.only_show_in[1]
                        if desktop then
                            cat.desktops = cat.desktops or {}
                            target = cat.desktops[desktop]
                            if not target then
                                target = {}
                                cat.desktops[desktop] = target
                            end
                        end
                        table.insert(target, { v.name, v.cmdline, v.icon })
                    end
                    break
                end
            end
        end

        -- Cleanup things a bit
        for i = #result, 1, -1 do
            local v = result[i]
            if #v[2] == 0 and not v.desktops then
                -- Remove unused categories
                table.remove(result, i)
            else
                --Sort entries alphabetically (by name)
                table.sort(v[2], function (a, b) return string.byte(a[1]) < string.byte(b[1]) end)
                -- One sub-menu per desktop environment, before the generic entries
                if v.desktops then
                    local desktops = {}
                    for name in pairs(v.desktops) do
                        table.insert(desktops, name)
                    end
                    table.sort(desktops)
                    for i, name in ipairs(desktops) do
                        local items = v.desktops[name]
                        table.sort(items, by_name)
                        local icon = menu_utils.lookup_icon(desktop_icons[name] or name:lower())
                        table.insert(v[2], i, { name, items, icon })
                    end
                    v.desktops = nil
                end
                -- Replace category name with nice name
                v[1] = menu_gen.all_categories[v[1]].name
            end
        end

        -- Sort categories alphabetically also
        table.sort(result, function(a, b) return string.byte(a[1]) < string.byte(b[1]) end)

        -- Add menu item to hold the generated menu
        if sub_menu then
            result = {{sub_menu, result}}
        end

        -- Add items to menu
        for _, v in pairs(result) do _menu:add(v) end
        for _, v in pairs(after)  do _menu:add(v) end
    end)

    -- Hold the menu in the module
    menu.menu = _menu

    return _menu
end

return menu
