--[[------------------------------------------------------

editor.Control test
-------------------

  ...

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('editor.Control')

function should.autoload()
  assertType('table', editor.Control)
end

function should.findControl()
  local s = editor.Control.getControl('lk.Slider')
  assertEqual(_control.lk.Slider, s)
end

function should.respondToSet()
  local s = editor.Control()
  s:set {
    hue = 0.2
  }
  assertEqual(0.2, s.hue)
end

test.all()


