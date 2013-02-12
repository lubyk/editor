--[[------------------------------------------------------

  _control.lk.Label
  -----------------

  Display any html content.

--]]------------------------------------------------------
local lib = lk.SubClass(editor.Control)
_control.lk.Label = lib.new

-- default select size and options
local const = {
  PARAM_NAMES = {
    {'text', 'Text'},
    {'font_size', 'Font size'},
  },
  DEFAULT = {
    w = 80,
    h = 20,
    font_size = 16,
    text = '--',
  },
}
lib.const = const

function lib:init(id, view)
  self.label = mimas.Label()
  self.label:setAlignment(mimas.AlignLeft + mimas.AlignVCenter)
  self:setFontSize(const.DEFAULT.font_size)
  self:addWidget(self.label)
  self.label:move(0,0)

  self:initControl(id, view)
  self:setupConnectors {
    s = 'print',
  }
  self.range    = nil
  self.no_range = true
  self:resize(const.DEFAULT.w, const.DEFAULT.h)
end

function lib:resized(w, h)
  self.w = w
  self.h = h
  self.label:resize(w, h)
end

function lib:setFontSize(p)
  self.label:setStyle(string.format([[
  font-size:%ipx;
  ]], p))
end

-- Set widget view parameters.
function lib:setParams(p)
  self:setHue(p.hue)
  self:setFontSize(p.font_size*1)
  self:setText(p.text)
end

function lib:setText(txt)
  if txt == '' then
    txt = '--'
  end
  self.label:setText(txt)
end

function lib:control(x, y, typ)
  -- noop
end

local noBrush = mimas.NoBrush
local noPen   = mimas.NoPen
local Align = mimas.AlignLeft + mimas.AlignVCenter

function lib:paintControl(p, w, h)
  -- only draw label text
end

