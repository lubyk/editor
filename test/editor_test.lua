--[[------------------------------------------------------

  editor test
  -----------

  ...

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('editor')

function should.autoLoad()
  assertTrue(editor)
end

test.all()
