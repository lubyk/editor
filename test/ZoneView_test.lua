--[[------------------------------------------------------

  editor.ZoneView test
  --------------------

  ...

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('editor.ZoneView')
local withUser = should:testWithUser()

function should.displayZoneView()
  local zone = editor.Zone(nil, 'foobar')
  local view = editor.ZoneView(zone)
  view:show()
  sleep(100)
  view:hide()
end

test.all()
