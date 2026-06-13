--[[
hairline — KOReader plugin

Du sendependaj baskuloj por la legilo-progresbreto:

  • Algluu al malsupra ekran-rando
        Nuligas la kontener-rembulaĵon kaj la vertikalan centrigon
        ene de la footer-kontenero, do la breto sidas ekzakte ĉe la
        malsupra ekran-rando.

  • Travidebla nelegita flanko
        Anstataŭigas la paintTo-metodon de la footer-progresbreto
        per varianto kiu tute ne pentras la fonan kaj bordero-
        rektangulojn. Nur la legita parto, ĉapitromarkiloj kaj
        la komenc-pozicia markilo videblas; la dekstra (nelegita)
        flanko montras la paĝon malsube.

La menu-baskuloj aperas en *Status bar settings → Hairline*.
Agordoj konserviĝas en settings/hairline.lua.
]]

local BD             = require("ui/bidi")
local DataStorage    = require("datastorage")
local Device         = require("device")
local Geom           = require("ui/geometry")
local LuaSettings    = require("luasettings")
local Math           = require("optmath")
local SpinWidget     = require("ui/widget/spinwidget")
local UIManager      = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local T              = require("ffi/util").template
local logger         = require("logger")
local _              = require("gettext")
local Screen         = Device.screen

local INITIAL_MARKER_HEIGHT_THRESHOLD = Screen:scaleBySize(12)

-- ── Komuna stato kaj agordoj ──────────────────────────────────────────

local shared = {
    flush_bottom      = true,
    transparent_right = true,
}

local _settings = nil
local function _get_settings()
    if not _settings then
        _settings = LuaSettings:open(
            DataStorage:getSettingsDir() .. "/hairline.lua")
    end
    return _settings
end

local function _load_settings_into_shared()
    local s = _get_settings()
    local fb = s:readSetting("flush_bottom")
    local tr = s:readSetting("transparent_right")
    shared.flush_bottom      = fb == nil and true or fb
    shared.transparent_right = tr == nil and true or tr
end

local function _persist()
    local s = _get_settings()
    s:saveSetting("flush_bottom",      shared.flush_bottom)
    s:saveSetting("transparent_right", shared.transparent_right)
    s:flush()
end

-- ── Travidebla paintTo por ProgressWidget ────────────────────────────
-- Kopio de ProgressWidget:paintTo, sed sen la unuaj du paintRect-vokoj
-- kiuj pentris bordercolor + bgcolor. Sen bordersize/margin_h/margin_v
-- la plenŝtopo plenigas la tutan dimen, kio rezultas en: nur la legita
-- portio + ĉapitromarkiloj + komenc-pozicia markilo videblas; la cetero
-- estas tute ne pentrita.

local function transparent_paintTo(self, bb, x, y)
    local my_size = self:getSize()
    if not self.dimen then
        self.dimen = Geom:new{ x = x, y = y, w = my_size.w, h = my_size.h }
    else
        self.dimen.x = x
        self.dimen.y = y
        self.dimen.w = my_size.w
        self.dimen.h = my_size.h
    end
    if self.dimen.w == 0 or self.dimen.h == 0 then return end

    local _mirroredUI = BD.mirroredUILayout()
    if self.invert_direction then _mirroredUI = not _mirroredUI end

    local fill_width  = my_size.w
    local fill_y      = y
    local fill_height = my_size.h

    -- Alterna plenŝtopo (ne-linearaj fluoj).
    if self.alt and self.alt[1] ~= nil then
        for i = 1, #self.alt do
            local tick_x = fill_width * ((self.alt[i][1] - 1) / self.last)
            local width  = fill_width * (self.alt[i][2] / self.last)
            if _mirroredUI then tick_x = fill_width - tick_x - width end
            bb:paintRect(x + math.floor(tick_x), fill_y,
                         math.ceil(width), math.ceil(fill_height),
                         self.altcolor)
        end
    end

    -- Ĉefa plenŝtopo (legita parto).
    if self.percentage and self.percentage >= 0 and self.percentage <= 1 then
        local fill_x = x
        if self.fill_from_right or (_mirroredUI and not self.fill_from_right) then
            fill_x = math.floor(x + fill_width * (1 - self.percentage))
        end
        bb:paintRect(fill_x, fill_y,
                     math.ceil(fill_width * self.percentage),
                     math.ceil(fill_height),
                     self.fillcolor)

        -- Komenc-pozicia markilo.
        if self.initial_pos_marker and self.initial_pos_icon
                and self.initial_percentage and self.initial_percentage >= 0 then
            local marker_x
            if _mirroredUI then
                marker_x = x + math.ceil(fill_width - fill_width * self.initial_percentage)
            else
                marker_x = x + math.ceil(fill_width * self.initial_percentage)
            end
            local icon_x, icon_y
            if self.height <= INITIAL_MARKER_HEIGHT_THRESHOLD then
                icon_x = Math.round(marker_x - self.height * (1/4))
                icon_y = y - Math.round(self.height * (1/6))
            else
                icon_x = Math.round(marker_x - self.height * (1/2))
                icon_y = y
            end
            self.initial_pos_icon:paintTo(bb, icon_x, icon_y)
        end
    end

    -- Ĉapitromarkiloj — pentritaj per bordercolor (kutime nigra).
    if self.ticks and self.last and self.last > 0 then
        for _, tick in ipairs(self.ticks) do
            local tick_x = fill_width * (tick / self.last)
            if _mirroredUI then tick_x = fill_width - tick_x end
            bb:paintRect(x + math.floor(tick_x), fill_y,
                         self.tick_width, math.ceil(fill_height),
                         self.bordercolor)
        end
    end
end

-- ── Aplikado al konkretaj instancoj ───────────────────────────────────

local function _flatten_geometry(pb)
    if pb._hairline_orig == nil then
        pb._hairline_orig = {
            margin_h         = pb.margin_h,
            margin_v         = pb.margin_v,
            _orig_margin_v   = pb._orig_margin_v,
            bordersize       = pb.bordersize,
            _orig_bordersize = pb._orig_bordersize,
            radius           = pb.radius,
        }
    end
    pb.margin_h         = 0
    pb.margin_v         = 0
    pb._orig_margin_v   = 0
    pb.bordersize       = 0
    pb._orig_bordersize = 0
    pb.radius           = 0
end

local function _restore_geometry(pb)
    local o = pb._hairline_orig
    if not o then return end
    pb.margin_h         = o.margin_h
    pb.margin_v         = o.margin_v
    pb._orig_margin_v   = o._orig_margin_v
    pb.bordersize       = o.bordersize
    pb._orig_bordersize = o._orig_bordersize
    pb.radius           = o.radius
    pb._hairline_orig = nil
end

local function _apply_transparent(pb)
    if not pb then return end
    if shared.transparent_right then
        _flatten_geometry(pb)
        if not pb._hairline_has_override then
            pb._hairline_has_override = true
        end
        pb.paintTo = transparent_paintTo
    else
        if pb._hairline_has_override then
            pb.paintTo = nil           -- forigi la instanc-shadowingon
            pb._hairline_has_override = nil
        end
        _restore_geometry(pb)
    end
end

local function _apply_flush(footer)
    if not footer then return end
    if shared.flush_bottom then
        footer.bottom_padding = 0
        if footer.footer_content then
            footer.footer_content.padding_bottom  = 0
            footer.footer_content._padding_bottom = 0
        end
        if footer.horizontal_group then
            footer.horizontal_group.align = "bottom"
            footer.horizontal_group:resetLayout()
        end
    end
end

local function _refresh_footer(ui)
    local footer = ui and ui.view and ui.view.footer
    if not footer then return end
    _apply_transparent(footer.progress_bar)
    _apply_flush(footer)
    footer:refreshFooter(true, true)
    if ui.view and ui.view.dialog then
        UIManager:setDirty(ui.view.dialog, "ui")
    end
end

-- ── Klasaj patches (instalataj nur unufoje) ───────────────────────────

local _class_patched = false

local function _get_bar_height_setting(footer)
    if not footer or not footer.settings then return nil end
    if footer.settings.progress_style_thin then
        return footer.settings.progress_style_thin_height
    else
        return footer.settings.progress_style_thick_height
    end
end

local function _set_bar_height_setting(footer, value)
    if not footer or not footer.settings then return end
    if footer.settings.progress_style_thin then
        footer.settings.progress_style_thin_height = value
    else
        footer.settings.progress_style_thick_height = value
    end
end

local function _build_menu_subitems(ui)
    return {
        {
            text         = _("Stick bar to bottom edge"),
            checked_func = function() return shared.flush_bottom end,
            callback     = function()
                shared.flush_bottom = not shared.flush_bottom
                _persist()
                _refresh_footer(ui)
            end,
        },
        {
            text         = _("Transparent unread side"),
            checked_func = function() return shared.transparent_right end,
            callback     = function()
                shared.transparent_right = not shared.transparent_right
                _persist()
                _refresh_footer(ui)
            end,
        },
        {
            text_func = function()
                local footer = ui and ui.view and ui.view.footer
                local h = _get_bar_height_setting(footer) or 0
                return T(_("Bar height: %1 px"), h)
            end,
            keep_menu_open = true,
            callback = function(touchmenu_instance)
                local footer = ui and ui.view and ui.view.footer
                if not footer then return end
                local cur     = _get_bar_height_setting(footer) or 1
                local default = footer.settings.progress_style_thin
                    and footer.default_settings.progress_style_thin_height
                    or  footer.default_settings.progress_style_thick_height
                UIManager:show(SpinWidget:new{
                    title_text          = _("Progress bar height"),
                    value               = cur,
                    value_min           = 1,
                    value_max           = 30,
                    value_step          = 1,
                    value_hold_step     = 2,
                    default_value       = default,
                    keep_shown_on_apply = true,
                    callback = function(spin)
                        _set_bar_height_setting(footer, spin.value)
                        footer:refreshFooter(true, true)
                        if touchmenu_instance then
                            touchmenu_instance:updateItems()
                        end
                    end,
                })
            end,
        },
    }
end

local function _patchReaderFooterClass()
    if _class_patched then return end
    local ReaderFooter = require("apps/reader/modules/readerfooter")

    local orig_updateFooterContainer = ReaderFooter.updateFooterContainer
    function ReaderFooter:updateFooterContainer()
        if shared.flush_bottom then
            self.bottom_padding = 0
        end
        orig_updateFooterContainer(self)
        _apply_flush(self)
        _apply_transparent(self.progress_bar)
    end

    local orig_init = ReaderFooter.init
    function ReaderFooter:init()
        orig_init(self)
        _apply_transparent(self.progress_bar)
        _apply_flush(self)
    end

    -- Injektu niajn item-ojn en la status_bar-submenuon de la footer.
    local orig_addToMainMenu = ReaderFooter.addToMainMenu
    function ReaderFooter:addToMainMenu(menu_items)
        orig_addToMainMenu(self, menu_items)
        if menu_items.status_bar and menu_items.status_bar.sub_item_table then
            table.insert(menu_items.status_bar.sub_item_table, {
                text           = _("Hairline"),
                separator      = true,
                sub_item_table = _build_menu_subitems(self.ui),
            })
        end
    end

    _class_patched = true
    logger.dbg("[hairline] ReaderFooter class patched")
end

-- ── Plugin ────────────────────────────────────────────────────────────

local Hairline = WidgetContainer:extend{
    name = "hairline",
}

function Hairline:init()
    _load_settings_into_shared()
    _patchReaderFooterClass()

    -- Tuja apliko al la jam-konstruita footer.
    local footer = self.ui and self.ui.view and self.ui.view.footer
    if footer then
        _apply_transparent(footer.progress_bar)
        _apply_flush(footer)
    end
end

function Hairline:onReaderReady()
    -- Footer kelkfoje konstruiĝas post plugin-init; certigi aplikon.
    local footer = self.ui and self.ui.view and self.ui.view.footer
    if footer then
        _apply_transparent(footer.progress_bar)
        _apply_flush(footer)
        if shared.flush_bottom or shared.transparent_right then
            footer:refreshFooter(true, true)
            if self.ui.view and self.ui.view.dialog then
                UIManager:setDirty(self.ui.view.dialog, "ui")
            end
        end
    end
end

function Hairline:onFlushSettings()
    if _settings then _settings:flush() end
end

return Hairline
