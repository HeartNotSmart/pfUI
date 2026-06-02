pfUI:RegisterModule("addoncompat", function ()
  -- save addon decissions across logins
  pfUI_init.addons = pfUI_init.addons or {}

  -- used as a dummy for an always matching dependency
  local always = function()
    return true
  end

  -- The first entry of the conflict tables contain a function
  -- that is used as a dependency checker. For example, to make sure
  -- we don't deactivate snowfall when actionbars aren't in use.
  -- The second entry is a function that runs specific code. This
  -- can be used to enable a specific option when the addon gets disabled.

  local hardconflict = {
    ["ClassicSnowFall"] = {
      function() return pfUI.bars end, -- dependency
      function() pfUI_config.bars.keydown = "1" end, -- option
    },
  }

  local softconflict = {
    ["MinimapButtonFrame"] = { always, function() pfUI_config.abuttons.enable = "1" end },
    ["MBB"] = { always, function() pfUI_config.abuttons.enable = "1" end },
    ["SellValue"] = { always },
    ["EquipCompare"] = { always },
    ["EQCompare"] = { always },
    ["OmniCC"] = { always },
    ["ShaguBoP"] = { always },
    ["ShaguCombat"] = { always },
    ["ShaguCopy"] = { always },
    ["ShaguError"] = { always },
    ["ShaguMount"] = { always },
    ["ShaguPlates"] = { always },
    ["ShaguTooltips"] = { always },
    ["ShaguValue"] = { always },
    ["ShaguTweaks"] = { always },
    ["ColorGuildFrame-1.0"] = { always },
    ["ColorSocialFrame"] = { always },
    ["DebuffTimers"] = { always },
    ["EquipColor"] = { always },
    ["FocusFrame"] = { always },
    ["GrayAutoSell"] = { always },
    ["QuickBind"] = { always },
    ["SmallerRollFrames"] = { always },
    ["EzDismount"] = { always },
    ["AddOnOrganizer"] = { always },
    ["Prat"] = { always },
  }

  local require_reload
  local require_config_reload
  local queue_soft = {}
  local queue_hard = {}
  local queue_config = {}

  local function IsWoWTranslateAddon(name, title)
    name = string.lower(tostring(name or ""))
    title = string.lower(tostring(title or ""))
    name = string.gsub(name, "[^%w]", "")
    title = string.gsub(title, "[^%w]", "")

    return string.find(name, "wowtranslate") or string.find(title, "wowtranslate")
  end

  -- scan through all addons
  for i=1, GetNumAddOns() do
    local name, title, notes, enabled = GetAddOnInfo(i)
    if enabled and not pfUI_init.addons[name] then
      if hardconflict[name] and hardconflict[name][1]() then
        queue_hard[name] = i
      end

      if softconflict[name] and softconflict[name][1]() then
        queue_soft[name] = i
      end

      if IsWoWTranslateAddon(name, title)
      and not pfUI_init.addons["wowtranslate_unitframes"]
      and pfUI_config.unitframes
      and pfUI_config.unitframes.disable ~= "1"
      and pfUI_config.unitframes.translate_wowtranslate ~= "1" then
        queue_config["wowtranslate_unitframes"] = name
      end
    end
  end

  local function RunQueue()
    -- run through hardlist
    local name, id = next(queue_hard)
    if name and id then
      -- disable addon
      DisableAddOn(id)

      -- trigger action if availabe
      if hardconflict[name][2] then
        hardconflict[name][2]()
      end

      -- ask for reload
      CreateQuestionDialog(
        string.format(T["The addon \"|cff33ffcc%s|r\" doesn't work with pfUI and has been disabled."], name) .. "\n"
        .. T["Do you want to reload the UI now?"],
        {T["Yes"], function()
          ReloadUI()
        end},
        {T["No"], function()
          queue_hard[name] = nil
        end},
        nil, RunQueue)
      return
    end

    -- run through optional config prompts
    local key, name = next(queue_config)
    if key and name then
      CreateQuestionDialog(
        T["WoWTranslate was detected."] .. "\n"
        .. "hover tooltip to translate unit frames" .. "\n"
        .. T["Do you want to enable translated unit frames?"],
        {T["Yes"], function()
          queue_config[key] = nil
          pfUI_init.addons[key] = true
          pfUI_config.unitframes.translate_wowtranslate = "1"
          require_config_reload = true
        end},
        {T["No"], function()
          queue_config[key] = nil
          pfUI_init.addons[key] = true
        end},
        nil, RunQueue)
      return
    end

    -- run through softlist
    local name, id = next(queue_soft)
    if name and id then
      CreateQuestionDialog(
        string.format(T["Every feature that \"|cff33ffcc%s|r\" offers is already built into pfUI."], name) .. "\n"
        .. T["Do you want to disable the addon?"],
        {T["Yes"], function()
          queue_soft[name] = nil

          -- trigger action if availabe
          if softconflict[name][2] then
            softconflict[name][2]()
          end

          DisableAddOn(id)
          require_reload = true
        end},
        {T["No"], function()
          queue_soft[name] = nil

          -- cache value to not ask again
          pfUI_init.addons[name] = true
        end},
        nil, RunQueue)
      return
    end

    -- in case of changes, ask for reload
    if require_reload or require_config_reload then
      local text = T["Some settings need to reload the UI to take effect.\nDo you want to reload now?"]
      if require_reload then
        text = T["The addon selection has changed."] .. "\n"
        .. T["Do you want to reload the UI now?"]
      end

      CreateQuestionDialog(
        text,
        {T["Yes"], function()
          ReloadUI()
        end},
        {T["No"], function() end},
        nil)
    end
  end

  -- run the addonconflict queue when firstrun is ready
  local delay = CreateFrame("Frame")
  delay:SetScript("OnUpdate", function()
    -- throttle to to one query per .1 second
    if ( this.tick or 1) > GetTime() then return else this.tick = GetTime() + .1 end

    -- make sure the firstrun dialog has finished
    if pfUI.firstrun and pfUI.firstrun.steps then
      for _, step in pairs(pfUI.firstrun.steps) do
        if not pfUI_init[step.name] then return end
      end
    end

    RunQueue()
    this:SetScript("OnUpdate", nil)
  end)
end)
