--[[------------------------------------------------------

  editor.LinkView test
  --------------------

  ...

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('editor.LinkView')
local withUser = should:testWithUser()

-- TODO
local function mockSlot(x,y)
  local self = {x = x, y = y}
  self.slot = self
  self.node = self
  self.zone = self
  self.color = mimas.Color(0.3)
  function self:globalPosition()
    return self.x, self.y
  end
  return self
end

function should.createLinkView(t)
  local src = mockSlot(100, 100)
  local trg = mockSlot(190,50)
  t.link = editor.LinkView(src,trg)
  t.link:show()
  sleep(50)
  t.link:hide()
  assertTrue(t.link)
end

function withUser.should.displayLink(t)
  t.win = mimas.Window()
  t.win:move(10,10)
  t.win:resize(200,200)
  local src = mockSlot(100, 100)
  local trg = mockSlot(190,50)
  t.link = editor.LinkView(src,trg)
  t.win:addWidget(t.link)
  t.win:show()
  function t.win:mouse(x, y)
    local gx, gy = self:globalPosition()
    trg.x = x + gx
    trg.y = y + gy
    t.link:slotMoved()
  end
  function t.win:click(x, y, op)
    if op == mimas.MouseRelease then
      t.continue = true
      t.win:close()
    end
  end
  t:timeout(function()
    return t.continue
  end)
  assertTrue(t.continue)
end

test.all()
