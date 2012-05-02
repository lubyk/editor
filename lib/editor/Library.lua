--[[------------------------------------------------------

  editor.Library
  --------------

  Database of node objects that can be used in patches. The
  Library can contain many sources patterns (folders) that
  are parsed to update Library content.

--]]------------------------------------------------------

local lib      = {type='editor.Library'}
lib.__index    = lib
editor.Library = lib
local private  = {}

setmetatable(lib, {
  __call = function(lib, ...)
    return lib.new(...)
  end
})

--- Create a new editor.Link reflecting the content of a remote
-- link. If the process view is not shown, the LinkView is not
-- created.
-- 'table_name' can be 'prototypes' or 'controls'
function lib.new(opts)
  assert(opts.table_name, 'Missing table_name')
  opts = opts or {table_name = 'prototype'}
  local self = {
    -- List of directories to search for files.
    sources = {},
    -- This is the name of the table containing the objects in the
    -- database. It is also used to get the sources from editor
    -- Settings.
    table_name  = opts.table_name,
    ignore_code = opts.ignore_code,
  }
  if opts.db then
    self.db = opts.db
  else
    self.filepath = editor.Settings.db_path
    lk.makePath(lk.pathDir(self.filepath))
    if lk.exist(self.filepath) then
      self.db = sqlite3.open(self.filepath)
    else
      self.db = sqlite3.open(self.filepath)
    end
  end
  setmetatable(self, lib)

  private.prepareDb(self)
  private.setupSources(self, opts.sources)
  return self
end

function lib:addSource(path)
  local dir = lk.Dir(path)
  table.insert(self.sources, dir)
end

-- Recreate database from content in filesystem.
function lib:sync()
  local db = self.db
  db:exec(private.gsub('DELETE from NODE_TABLE;', 'NODE_TABLE', self.table_name))
  for _, dir in ipairs(self.sources) do
    for folder in dir:list() do
      if lk.fileType(folder) == 'directory' then
        local _, lib_name = lk.pathDir(folder)
        local dir = lk.Dir(folder)
        for file in dir:glob('[.]lua$') do
          private.addNode(self, lib_name, file)
        end
      end
    end
  end
end

function lib:nodeCount(filter)
  filter = private.prepareFilter(filter)
  local stmt = self.get_node_count_with_filter_stmt
  stmt:bind_names {filter = filter}
  return stmt:first_row()[1]
end

function lib:code(name)
  local stmt = self.get_code_by_name_stmt
  stmt:bind_names {name = name}
  local row = stmt:first_row()
  if row then
    return row[1]
  else
    return nil
  end
end

function lib:node(filter, pos)
  if type(filter) == 'number' then
    pos = filter
    filter = nil
  end
  filter = private.prepareFilter(filter)
  local stmt = self.get_node_by_position_and_filter_stmt
  local filter = private.prepareFilter(filter)
  stmt:bind_names {
    p = (pos or 1) - 1,
    filter = filter,
  }
  local row = stmt:first_row()
  if row then
    return {
      --id   = row[1],
      name = row[2],
      path = row[3],
      code = row[4],
      keywords = row[5],
    }
  else
    return nil
  end
end

--=============================================== PRIVATE

local function gsub(str, pat, rep)
  local str = string.gsub(str, pat, rep)
  -- Avoid returning substitution count values 
  return str
end
private.gsub = gsub

function private:setupSources(user_list)
  -- prototypes_base_src, controls_base_src (path relative to Lubyk.lib)
  local list = editor.Settings[self.table_name .. '_base_src']
  if list then
    -- Use the real list in case we have a copy-on-write (empty) placeholder
    -- list.
    list = list._placeholder or list
    for _, path in ipairs(list) do
      self:addSource(Lubyk.lib .. '/' .. path)
    end
  end

  -- prototypes_src, controls_src (extra paths provided by user)
  list = user_list or editor.Settings[self.table_name .. '_src']
  if list then
    -- Use the real list in case we have a copy-on-write (empty) placeholder
    -- list.
    list = list._placeholder or list
    for _, path in ipairs(list) do
      self:addSource(path)
    end
  end
end

-- Prepare the database for events
function private:prepareDb()
  local db = self.db
  -- FIXME: only create tables if db tables do not exist yet

  -- Code is not used for controls.
  if not false then
    db:exec(gsub([[
      CREATE TABLE NODE_TABLE (id INTEGER PRIMARY KEY, name TEXT, path TEXT, code TEXT, keywords TEXT);
      CREATE INDEX NODE_TABLE_keywords_idx ON NODE_TABLE(keywords);
      CREATE UNIQUE INDEX NODE_TABLE_id_idx ON NODE_TABLE(id);
      CREATE UNIQUE INDEX NODE_TABLE_name_idx ON NODE_TABLE(name);
    ]], 'NODE_TABLE', self.table_name))
  end

  ------------------------------------------------------------  READ nodes
  self.get_node_by_position_and_filter_stmt = db:prepare(gsub([[
    SELECT * FROM NODE_TABLE WHERE keywords LIKE :filter ORDER BY name LIMIT 1 OFFSET :p;
  ]], 'NODE_TABLE', self.table_name))

  self.get_code_by_name_stmt = db:prepare(gsub([[
    SELECT code FROM NODE_TABLE WHERE name = :name LIMIT 1;
  ]], 'NODE_TABLE', self.table_name))

  self.get_node_count_with_filter_stmt = db:prepare(gsub([[
    SELECT COUNT(*) FROM NODE_TABLE WHERE keywords LIKE :filter;
  ]], 'NODE_TABLE', self.table_name))

  ------------------------------------------------------------  WRITE nodes
  self.add_node_stmt = db:prepare(gsub([[
    INSERT INTO NODE_TABLE VALUES (NULL, :name, :path, :code, :keywords);
  ]], 'NODE_TABLE', self.table_name))
end

function private:addNode(lib_name, filepath)
  local name = lib_name .. '.' .. string.match(filepath, '([^%./]+)%.lua$')
  local stmt = self.add_node_stmt
  local code
  local keywords
  if not self.ignore_code then
    code = lk.readall(filepath)
    keywords = string.match(code, '@keywords ([^\n]+)')
    if keywords then
      keywords = keywords:gsub(',',' '):gsub(' +',' ') .. ' ' .. name
    end
  end
  stmt:bind_names {
    name = name,
    path = filepath,
    code = code,
    keywords = keywords or name,
  }
  stmt:step()
  stmt:reset()
end

function private.prepareFilter(filter)
  if not filter then
    return '%'
  elseif not string.match(filter, '%%') then
    return '%' .. (filter or '') .. '%'
  else
    return filter
  end
end
