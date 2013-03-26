--[[------------------------------------------------------
--

  editor.Application
  ------------------

  Singleton to start splash screen and open editor
  windows (editor.Zone). This class has no public methods.

--]]------------------------------------------------------
require 'mimas'
require 'mimas.Application'
local lib          = lk.SubClass(mimas.Application)
lib.type           = 'editor.Application'
lib.__index        = lib
editor.Application = lib
local app          = app
local private      = {}

-- We transform mimas.Application into an editor.Application.
function lib.new()
  local self = app
  setmetatable(self, lib)
  self.start = lk.Thread(function()
    self:init()
  end)
  for _, v in pairs(arg) do
    if v == '--install' then
      self.need_install = true
    end
  end
  self:setTheme(editor.Settings.theme or 'dark')
  return self
end

-- Platform specific app path (used to check installation on first run).
local app_base_path = {
  macosx = '/Applications',
  -- FIXME
  linux  = '/usr/local/',
}

function lib:init()
  -- editing windows' models
  self.zones     = {}
  -- list of found zones
  self.zone_list = {}
  -- hosts
  self.host_list = {'localhost'}

  if self.need_install then
    local app_lua_path = arg[0]
    if not app_lua_path:match('^'..app_base_path[Lubyk.plat]) then
      self.dlg = mimas.SimpleDialog {
        'Lubyk ' .. Lubyk.version_str .. ' starting.',
        '<h2>Please install Lubyk in "' .. app_base_path[Lubyk.plat] .. '"</h2>',
        {
          'hbox',
          {},
          {'btn', 'Quit', default=true},
        },
      }
      function self.dlg:btn(btn)
        self:close()
      end
    else
      self.dlg = mimas.SimpleDialog {
        'Lubyk ' .. Lubyk.version_str .. ' starting.',
        '<h2>Bootstrap file installation needed.</h2>',
        {
          'hbox',
          {},
          {'btn', 'Quit'},
          {'btn', 'Install', default=true},
        },
      }
      function self.dlg:btn(btn)
        if btn == 'Quit' then
          self:close()
        else
          -- Install
          if Lubyk.plat == 'macosx' then
            os.execute('open "' .. Lubyk.lib .. '/InstallLubyk.app"')
            self:close()
          end
        end
      end
    end

    self.dlg:resize(self.dlg:minimumSize())
    self.dlg:show()
  else
    self:selectZone(Lubyk.zone)
  end
end

--=============================================== ProcessWatch delegate
function lib:processConnected(service)
  local service_name = process.name
  if service_name == '' then
    -- morph
    -- found new zone
    self.morph = service
  else
    -- process
    -- we are not interested in processes in Main
  end
end

function lib:removeService(service)
  local service_name = service.name
  if service_name == '' then
    -- morph
    self.morph = nil
    private.disconnectMorph(self, process)
  else
    -- process
    -- we are not interested in processes in Main
  end
end

--============================================= ZoneChooser delegate

function lib:zonesDataSource()
  return self.zone_data
end

function lib:hostsDataSource()
  return self.host_data
end

function lib:selectZone(zone_name)
  self.zone = editor.Zone(self.process_watch, zone_name)
end

function lib:removeZone(zone_name)
  -- Window was closed.
  self.zones[zone_name] = nil
end

function lib:startZone(opts)
  -- Spawn Morph server
  lk.spawn([[
  require 'lubyk'
  morph = lk.DavMorph(%s)
  run()
  ]], opts)
end

--=============================================== Receive an openFile event

function lib:openFile(path)
  -- We receive spurious openFile events for the arguments passed to 
  -- Resources/app.lua. Check for correct file type.
  if string.match(path, '.lkp$') then
    if self.morph then
      -- kill it
      self.morph.push:send(lubyk.quit_url)
      self.morph = nil
    end

    -- Manage recent files
    local s = editor.Settings
    if not s.open_recent then
      s.open_recent = {path}
    else
      for i, rpath in ipairs(s.open_recent) do
        if rpath == path then
          -- already in list
          table.remove(s.open_recent, i)
          break
        end
      end
      table.insert(s.open_recent, 1, path)
      while #s.open_recent > s.open_recent_max and #s.open_recent > 0 do
        table.remove(s.open_recent, #s.open_recent)
      end
    end
    s:save()

    -- If we have a local stem, do not create a new one.
    local stem = self.zone.found_processes['@'..Lubyk.host]
    self:startZone {
      path = path,
      start_stem = not stem,
    }
  end
end

