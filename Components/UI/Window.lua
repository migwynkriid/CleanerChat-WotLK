local Core = unpack(select(2, ...))

----
-- Window
--
-- Owns the per-window pieces of a Glass chat window: the mover handle, the
-- container, the tab dock, the pool of SlidingMessageFrames, and the
-- frames/tabs currently shown in it.
--
-- CleanerChat historically rendered *every* chat frame into a single hard-coded
-- window. Grouping those pieces behind a Window object is the foundation for
-- supporting multiple separate windows (one Glass window per Blizzard dock
-- group). This is the behaviour-preserving foundation: the main window is built
-- with the original frame names so existing references (e.g.
-- _G["GlassChatDock"]) and saved settings are unchanged.
--
-- opts:
--   id              - stable window identifier (defaults to "Main")
--   parent          - parent frame (defaults to UIParent)
--   primaryChatFrame- the Blizzard ChatFrame this window is anchored to
--   moverName       - explicit name for the mover frame (else "GlassMoverFrame"<id>)
--   containerName   - explicit name for the container frame (else "GlassFrame"<id>)
local function CreateWindow(opts)
  opts = opts or {}

  local id = opts.id or "Main"
  local parent = opts.parent or _G.UIParent

  local window = {
    id = id,
    primaryChatFrame = opts.primaryChatFrame,
    -- Render state for this window. `frames`/`tabs` are keyed by chat-frame
    -- index, matching the existing UIManager state shape.
    frames = {},
    tabs = {},
  }

  -- Settings this window reads from. The main window uses the shared profile;
  -- additional windows get their own copy (see Core:GetWindowProfile).
  window.profile = Core:GetWindowProfile(id)

  -- Mover handle (drag/resize). Self-positions from the profile.
  window.moverFrame = Core.Components.CreateMoverFrame(
    opts.moverName or ("GlassMoverFrame" .. id), parent, window.profile
  )
  -- Back-reference so the mover can identify its window for config updates.
  window.moverFrame.window = window
  -- Update the mover's title to show which window it belongs to.
  window.moverFrame:SetWindowLabel(id)

  -- Container that everything in this window is anchored to.
  window.container = Core.Components.CreateMainContainerFrame(
    opts.containerName or ("GlassFrame" .. id), parent, window.profile
  )
  window.container:SetPoint("TOPLEFT", window.moverFrame)
  -- Back-reference so the container can scope its hover events to this window.
  window.container.window = window

  -- Tab dock and the message-frame pool live inside the container. Each window
  -- owns its own dock (named per window; the main window keeps "GlassChatDock")
  -- and its SMFs carry a back-reference to this window so their tabs target the
  -- correct dock.
  window.dock = Core.Components.CreateChatDock(
    window.container, opts.dockName or ("GlassChatDock" .. id), window.profile
  )
  -- Back-reference so the dock only reacts to its own window's hover events.
  window.dock.window = window
  window.pool = Core.Components.CreateSlidingMessageFramePool(window.container, window)

  return window
end

Core.Components.CreateWindow = CreateWindow
