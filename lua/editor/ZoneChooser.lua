--[[------------------------------------------------------

  editor.ZoneChooser
  --------------------

  This is part of the splash screen seen when launching the editor:
  it shows a list of found networks that can be joined or
  proposes to create a new network.

  +- Show a list of networks     (list of morph servers)
    +- [---] Choose network      ==> execute callback [.]
    +- [New] Create network
      +- Choose host             (list of hosts from stem/process/gui)
        +- [---] Choose host
          +- Enter project path
          +- [Start]             ==> launches morph server (return value = nil/network name)
                                 ==> execute callback [.]
          +- [Back]              ==> show host chooser
        +- [Back]                ==> show network chooser
    +- [Quit] quit application

--]]------------------------------------------------------
local lib = mimas.WidgetClass('editor.ZoneChooser')
editor.ZoneChooser = lib

--============================================= PRIVATE
-- constants

-- dummy (no prior networks)
local function mockList(data)
  data = data or {}
  function self:count()
    return #data
  end

  function self:data(row)
    return data[row]
  end

  function self:addObserver(observer)
    -- noop
  end
  return self
end

local makeZoneChooser, makeHostChooser, makePathSelector

-- 1. Choose network
function makeZoneChooser(self)
  self.dlg = editor.SimpleDialog {
    data    = self.networks_data_source,
    message = 'Choose zone',
    ok      = 'New',
    cancel  = 'Quit',
  }
  self.lay:addWidget(self.dlg)

  function self.dlg.select(dlg, row)
    self.network_id = row
    local name = self.networks_data_source.data(row)
    -- The user has selected a network. We
    -- are done.
    dlg:close()
    self.delegate:selectNetwork(name)
  end

  function self.dlg.ok(dlg)
    dlg:close()
    makeHostChooser(self)
  end

  function self.dlg:cancel()
    app:quit()
  end
end

-- 2. New network --> choose host
function makeHostChooser(self)
  self.dlg = editor.SimpleDialog {
    data    = self.hosts_data_source,
    message = 'Choose host',
    cancel  = 'Back',
    ok      = 'Local',
  }

  function self.dlg.select(dlg, row)
    -- The user has selected a host.
    self.host_name = self.hosts_data_source.data(row)
    dlg:close()
    -- Ask for project path
    makePathSelector(self)
  end

  function self.dlg.ok(dlg)
    self.host_name = 'localhost'
    dlg:close()
    -- Ask for project path
    makePathSelector(self)
  end

  function self.dlg.cancel(dlg)
    -- Abort choosing host
    dlg:close()
    makeZoneChooser(self)
  end
  self.lay:addWidget(self.dlg)
end

-- 3. Chosen host --> open path
function makePathSelector(self)
  local is_local = self.host_name == 'localhost'
  self.dlg = editor.SimpleDialog {
    message = string.format('Please enter project path on "%s"', self.host_name),
    line    = 'Zone',
    line_value = 'default', -- FIXME: use last value (create editor.Settings)
    line2   = 'Project path',
    line2_value = '',       -- FIXME: use last value (create editor.Settings)
    cancel  = 'Back',
    ok      = 'Start',
  }

  function self.dlg.cancel(dlg)
    -- Abort choosing path
    dlg:close()
    self.host_name = nil
    makeHostChooser(self)
  end

  function self.dlg.ok(dlg)
    -- Start morph server on the host with the given path.
    self.zone = dlg:line()
    self.project_path = dlg:line2()
    dlg:close()
    self.delegate:startNetwork(self.host_name, self.project_path)
  end

  self.lay:addWidget(self.dlg)
  if is_local then
    function self.dlg.widgets.line2.click()
      self.dlg:openProjectDialog()
    end

    -- open file dialog
    app:post(function()
      self.dlg:openProjectDialog()
    end)
  end
end

--============================================= PUBLIC
function lib:init(delegate)
  self.delegate = delegate

  self.hosts_data_source    = delegate:hostsDataSource()
  self.networks_data_source = delegate:networksDataSource()
  self.lay  = mimas.VBoxLayout(self)
  makeZoneChooser(self)
  self:resize(300, 300)
  self:setStyle 'background:transparent;'
  self:show()
  self:center()
end

function lib:paint(p, w, h)
  local bp = 7 -- full box padding
  local arc_radius = 15
  local bg = mimas.Color()
  bg:setRgba(38/256,38/256,38/256)

  local pen = mimas.EmptyPen
  p:setBrush(bg)
  p:setPen(pen)
  p:drawRoundedRect(bp, bp, w - 2*bp, h - 2*bp, arc_radius)
end
