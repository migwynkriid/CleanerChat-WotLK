-- Unit tests for the shared CleanerChat helpers in Core/API/Utils.lua.
--
-- These helpers are pure (or near-pure) Lua and need no WoW client, so we load
-- Utils.lua with a fake addon namespace and a couple of global stubs. Run with:
--   busted spec
-- from the addon root.

-- Load Core/API/Utils.lua into a fresh namespace. Utils.lua's signature is
-- `local _, ns = ...`, so we pass (addonName, ns) and return the populated ns.
local function loadUtils()
  local ns = {}
  local chunk = assert(loadfile("Core/API/Utils.lua"))
  chunk("TestAddon", ns)
  return ns
end

describe("ns.MakePattern", function()
  local ns
  before_each(function() ns = loadUtils() end)

  it("converts %d tokens into number captures", function()
    assert.are.equal("(%d+) Gold", ns.MakePattern("%d Gold"))
  end)

  it("converts %s tokens into greedy captures", function()
    assert.are.equal("Received item: (.+)", ns.MakePattern("Received item: %s"))
  end)

  it("handles mixed tokens", function()
    assert.are.equal(
      "You gain (%d+) experience from (.+).",
      ns.MakePattern("You gain %d experience from %s.")
    )
  end)

  it("returns nil for nil or empty input", function()
    assert.is_nil(ns.MakePattern(nil))
    assert.is_nil(ns.MakePattern(""))
  end)
end)

describe("ns.SafeMatch", function()
  local ns
  before_each(function() ns = loadUtils() end)

  it("returns captures for a valid pattern", function()
    assert.are.equal("42", ns.SafeMatch("you have 42 gold", "(%d+)"))
  end)

  it("returns nil (instead of erroring) for a nil pattern", function()
    assert.is_nil(ns.SafeMatch("anything", nil))
  end)
end)

describe("ns.StripBrackets", function()
  local ns
  before_each(function() ns = loadUtils() end)

  it("removes surrounding square brackets", function()
    assert.are.equal("Thunderfury", ns.StripBrackets("[Thunderfury]"))
  end)

  it("preserves the |H hyperlink body around the name", function()
    assert.are.equal(
      "|cffff8000|Hitem:19019|hThunderfury|h|r",
      ns.StripBrackets("|cffff8000|Hitem:19019|h[Thunderfury]|h|r")
    )
  end)

  it("passes nil through unchanged", function()
    assert.is_nil(ns.StripBrackets(nil))
  end)
end)

describe("ns.MakePatternCache", function()
  local ns
  before_each(function() ns = loadUtils() end)

  it("lazily compiles and memoizes patterns on first lookup", function()
    local P = ns.MakePatternCache()
    assert.are.equal("(%d+) Gold", P["%d Gold"])
    -- Second lookup returns the same memoized value.
    assert.are.equal("(%d+) Gold", P["%d Gold"])
    assert.are.equal(rawget(P, "%d Gold"), "(%d+) Gold")
  end)

  it("returns nil for empty keys", function()
    local P = ns.MakePatternCache()
    assert.is_nil(P[""])
  end)
end)

describe("ns.PrintToFrame", function()
  local ns
  before_each(function() ns = loadUtils() end)

  local function mockFrame()
    local calls = {}
    return {
      calls = calls,
      AddMessage = function(_, ...) calls[#calls + 1] = { ... } end,
    }, calls
  end

  it("colours the message using ChatTypeInfo for the chat type", function()
    _G.ChatTypeInfo = { LOOT = { r = 0.1, g = 0.2, b = 0.3 } }
    local frame, calls = mockFrame()
    ns.PrintToFrame(frame, "hello", "LOOT")
    assert.are.same({ "hello", 0.1, 0.2, 0.3 }, calls[1])
  end)

  it("falls back to no colour for an unknown chat type", function()
    _G.ChatTypeInfo = {}
    local frame, calls = mockFrame()
    ns.PrintToFrame(frame, "plain", "NOPE")
    assert.are.same({ "plain" }, calls[1])
  end)

  it("is a no-op when the frame or message is missing", function()
    assert.has_no.errors(function()
      ns.PrintToFrame(nil, "x", "LOOT")
      ns.PrintToFrame({ AddMessage = function() end }, nil, "LOOT")
    end)
  end)
end)

describe("ns.CreateFrameBuffer", function()
  local ns
  before_each(function() ns = loadUtils() end)

  it("accumulates per frame and flushes with the collected state", function()
    _G.C_Timer = { After = function(_, fn) fn() end } -- synchronous flush
    local flushed
    local buffer = ns.CreateFrameBuffer(
      function() return { items = {} } end,
      function(_, state) flushed = state.items end
    )

    local frameKey = {}
    local acc = buffer.Get(frameKey)
    table.insert(acc.items, "a")
    table.insert(acc.items, "b")
    buffer.Schedule(frameKey)

    assert.are.same({ "a", "b" }, flushed)
  end)

  it("starts a fresh accumulator after a flush", function()
    _G.C_Timer = { After = function(_, fn) fn() end }
    local buffer = ns.CreateFrameBuffer(
      function() return { items = {} } end,
      function() end
    )
    local frameKey = {}
    table.insert(buffer.Get(frameKey).items, "x")
    buffer.Schedule(frameKey)
    assert.are.equal(0, #buffer.Get(frameKey).items)
  end)

  it("only schedules one flush per frame regardless of how often Schedule is called", function()
    local pending = {}
    _G.C_Timer = { After = function(_, fn) pending[#pending + 1] = fn end } -- deferred
    local flushCount = 0
    local buffer = ns.CreateFrameBuffer(
      function() return { items = {} } end,
      function() flushCount = flushCount + 1 end
    )

    local frameKey = {}
    local acc = buffer.Get(frameKey)
    table.insert(acc.items, "x")
    buffer.Schedule(frameKey)
    table.insert(acc.items, "y")
    buffer.Schedule(frameKey) -- same frame -> must not arm a second timer

    assert.are.equal(1, #pending)
    pending[1]() -- run the next-frame flush
    assert.are.equal(1, flushCount)
  end)
end)
