--[[------------------------------------------------------

  editor.LibraryView test
  -----------------------

  ...

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('editor.LibraryView')
local withUser = should:testWithUser()

local function makeLib()
  local op
  local lib = editor.Library {
    db = sqlite3.open_memory(),
    table_name = 'nodes',
    sources = {
      fixture.path('_prototypes'),
    },
  }
  lib:sync()
  return lib
end

function should.displayView(t)
  t.view = editor.LibraryView(makeLib())
  t.view:move(10,10)
  t.view:show()
  assertTrue(true)
  t.view:close()
end

function withUser.should.drawLibraryView(t)
  t.view = editor.LibraryView(makeLib())
  t.view:move(10,10)
  t.view:show()
  function t.view.list_view:click()
    t.continue = true
  end
  t:timeout(function()
    return t.continue
  end)
  assertTrue(t.continue)
  t.view:close()
end

test.all()
