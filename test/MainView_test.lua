--[[------------------------------------------------------

  editor.ZoneView test
  --------------------

  ...

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('editor.ZoneView')

function should.drawMainView(t)
  t.remote   = lk.Process(fixture.path('simple.yml'))
  t.editor   = editor.Zone()
  t.watch    = lk.ProcessWatch():addDelegate(t.editor)
  t.editor:setView(editor.ZoneView(t.editor))
  t.editor.view:show()
  sleep(2000)
end

test.gui()
