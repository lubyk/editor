--[[------------------------------------------------------

  editor.MachineList test
  -----------------------

  ...

--]]------------------------------------------------------
require 'lubyk'

local should = test.Suite('editor.MachineList')

function addTabs(list)
  list:addProcess{name = 'Two', hue = 0.7}
  list:addProcess{name = 'Process One', hue = 0.9}
  list:addProcess{name = 'Armand', hue = 0.3}
end

function should.drawMachineList(t)
  t.win = mimas.Window()
  t.lay = mimas.HBoxLayout(t.win)
  t.lay:addStretch()
  t.lay:setContentsMargins(0,0,0,0)
  t.win:move(10,10)
  t.win:resize(500,500)
  t.list = editor.MachineList()
  t.lay:addWidget(t.list, 0, mimas.AlignRight)
  addTabs(t.list)
  t.win:show()

  sleep(800)
  t.list:addProcess{name = 'Dune', hue = 0.2}
  sleep(800)
  t.list:removeProcess('Process One')
  sleep(800)
  t.list:addMachine('foobar', {ip = '10.0.0.3'})
  sleep(11800)
  t.win:close()
  assertTrue(true)
end

test.all()

