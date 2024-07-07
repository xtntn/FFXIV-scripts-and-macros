--[[
    MarketBotty! Fuck it, I'm going there. Don't @ me.
    https://github.com/plottingCreeper/FFXIV-scripts-and-macros/tree/main/SND/MarketBotty
]]

my_characters = { --Characters to switch to in multimode
  'Character Name@Server',
  'Character Name@Server',
}
my_retainers = { --Retainers to avoid undercutting
  'Dont-undercut-this-retainer',
  'Or-this-one',
}
blacklist_retainers = { --Do not run script on these retainers
  'Dont-run-this-retainer',
  'Or-this-one',
}
item_overrides = { --Item names with no spaces or symbols
  StuffedAlpha = { maximum = 450 },
  StuffedBomBoko = { minimum = 450 },
  Coke = { minimum = 450, maximum = 5000 },
  RamieTabard = { default = 25000 },
}

undercut = 1 --There's no reason to change this. 1 gil undercut is life.
is_dont_undercut_my_retainers = true --Working!
is_price_sanity_checking = true --Ignores market results below half the trimmed mean of historical prices.
is_using_blacklist = true --Whether or not to use the blacklist_retainers list.
history_trim_amount = 5 --Trims this many from highest and lowest in history list
history_multiplier = "round" --if no active sales then get average historical price and multiply
is_using_overrides = true --item_overrides table.
is_check_for_hq = false --Not working yet :(

is_override_report = true
is_postrun_one_gil_report = true  --Requires is_verbose
is_postrun_sanity_report = true  --Requires is_verbose

is_verbose = true --Basic info in chat about what's going on.
is_debug = true --Absolutely flood your chat with all sorts of shit you don't need to know.
name_rechecks = 10 --Latency sensitive tunable. Probably sets wrong price if below 5

is_read_from_files = true --Override arrays with lists in files. Missing files are ignored.
is_write_to_files = true --Adds characters and retainers to characters_file and retainers_file
is_echo_during_read = false --Echo each character and retainer name as they're read, to see how you screwed up.
config_folder = os.getenv("appdata").."\\XIVLauncher\\pluginConfigs\\SomethingNeedDoing\\"
marketbotty_settings = "marketbotty_settings.lua" --loaded first
characters_file = "my_characters.txt"
retainers_file = "my_retainers.txt"
blacklist_file = "blacklist_retainers.txt"
overrides_file = "item_overrides.lua"

is_multimode = false --It worked once, which means it's perfect now. Please send any complaints to /dev/null
start_wait = false --For when starting script during AR operation.
after_multi = false  --"logout", "wait 10", "wait logout", number. See readme.
is_autoretainer_while_waiting = false
multimode_ending_command = "/ays multi e"
is_use_ar_to_enter_house = true --Breaks if you have subs ready.
is_autoretainer_compatibility = false --Not implemented. Last on the to-do list.

------------------------------------------------------------------------------------------------------

function file_exists(name)
  local f=io.open(name,"r")
  if f~=nil then io.close(f) return true else return false end
end

function CountRetainers()
  if not IsAddonVisible("RetainerList") then SomethingBroke("RetainerList", "CountRetainers()") end
  while string.gsub(GetNodeText("RetainerList", 2, 1, 13),"%d","")=="" do
    yield("/wait 0.1")
  end
  yield("/wait 0.1")
  total_retainers = 0
  retainers_to_run = {}
  yield("/wait 0.1")
  for i= 1, 10 do
    yield("/wait 0.01")
    include_retainer = true
    retainer_name = GetNodeText("RetainerList", 2, i, 13)
    if retainer_name~="" and retainer_name~=13 then
      if GetNodeText("RetainerList", 2, i, 5)~="None" then
        if is_using_blacklist then
          for _, blacklist_test in pairs(blacklist_retainers) do
            if retainer_name==blacklist_test then
              include_retainer = false
              break
            end
          end
        end
      else
        include_retainer = false
      end
      if include_retainer then
        total_retainers = total_retainers + 1
        retainers_to_run[total_retainers] = i
      end
      if is_write_to_files and type(file_retainers)=="userdata" then
        is_add_to_file = true
        for _, known_retainer in pairs(my_retainers) do
          if retainer_name==known_retainer then
            is_add_to_file = false
            break
          end
        end
        if is_add_to_file then
          file_retainers = io.open(config_folder..retainers_file,"a")
          file_retainers:write("\n"..retainer_name)
          io.close(file_retainers)
        end
      end
    end
  end
  debug("Retainers to run on this character: " .. total_retainers)
  return total_retainers
end

function OpenRetainer(r)
  if not IsAddonVisible("RetainerList") then SomethingBroke("RetainerList", "OpenRetainer("..r..")") end
  yield("/wait 0.3")
  yield("/click RetainerList_Retainer"..r)
  yield("/wait 0.5")
  while IsAddonVisible("SelectString")==false do
    if IsAddonVisible("Talk") then yield("/click Talk_Click") end
    yield("/wait 0.1")
  end
  if not IsAddonVisible("SelectString") then SomethingBroke("SelectString", "OpenRetainer("..r..")") end
  yield("/wait 0.3")
  yield("/click SelectString_Entry4")
  if not IsAddonVisible("RetainerSellList") then SomethingBroke("RetainerSellList", "OpenRetainer("..r..")") end
end

function CloseRetainer()
  while not IsAddonVisible("RetainerList") do
    if IsAddonVisible("RetainerSellList") then yield("/callback RetainerSellList true -1") end
    if IsAddonVisible("SelectString") then yield("/callback SelectString true -1") end
    if IsAddonVisible("Talk") then yield("/click Talk_Click") end
    yield("/wait 0.1")
  end
end

function CountItems()
  yield("/waitaddon RetainerSellList")
  while string.gsub(GetNodeText("RetainerSellList", 3),"%d","")=="" do
    yield("/wait 0.1")
  end
  count_wait_tick = 0
  while GetNodeText("RetainerSellList", 3)==raw_item_count and count_wait_tick < 5 do
    count_wait_tick = count_wait_tick + 1
    yield("/wait 0.1")
  end
  yield("/wait 0.1")
  raw_item_count = GetNodeText("RetainerSellList", 3)
  item_count_trimmed = string.sub(raw_item_count,1,2)
  item_count = string.gsub(item_count_trimmed,"%D","")
  debug("Items for sale on this retainer: "..item_count)
  return item_count
end

function ClickItem(item)
  CloseSales()
  while IsAddonVisible("RetainerSell")==false do
    if IsAddonVisible("ContextMenu") then
      yield("/callback ContextMenu true 0 0")
      yield("/wait 0.2")
    elseif IsAddonVisible("RetainerSellList") then
      yield("/callback RetainerSellList true 0 ".. item - 1 .." 1")
    else
      SomethingBroke("RetainerSellList", "ClickItem()")
    end
    yield("/wait 0.05")
  end
end

function ReadOpenItem()
  last_item = open_item
  open_item = ""
  item_name_checks = 0
  while item_name_checks < name_rechecks and ( open_item == last_item or open_item == "" ) do
    item_name_checks = item_name_checks + 1
    yield("/wait 0.1")
    --open_item = string.sub(string.gsub(GetNodeText("RetainerSell",18),"%W",""),3,-3)
    open_item = string.gsub(GetNodeText("RetainerSell",18),"%W","")
  end
  debug("Last item: "..last_item)
  debug("Open item: "..open_item)
end

function SearchResults()
  if IsAddonVisible("ItemSearchResult")==false then
    yield("/wait 0.1")
    if IsAddonVisible("ItemSearchResult")==false then
      yield("/callback RetainerSell true 4")
    end
  end
  yield("/waitaddon ItemSearchResult")
  if IsAddonVisible("ItemHistory")==false then
    yield("/wait 0.1")
    if IsAddonVisible("ItemHistory")==false then
      yield("/callback ItemSearchResult true 0")
    end
  end
  yield("/wait 0.1")
  ready = false
  search_hits = ""
  search_wait_tick = 10
  while ready==false do
    search_hits = GetNodeText("ItemSearchResult", 2)
    first_price = string.gsub(GetNodeText("ItemSearchResult", 5, 1, 10),"%D","")
    if search_wait_tick > 20 and string.find(GetNodeText("ItemSearchResult", 26), "No items found.") then
      ready = true
      debug("No items found.")
    end
    if (string.find(search_hits, "hit") and first_price~="") and (old_first_price~=first_price or search_wait_tick>20) then
      ready = true
      debug("Ready!")
    else
      search_wait_tick = search_wait_tick + 1
      if (search_wait_tick > 50) or (string.find(GetNodeText("ItemSearchResult", 26), "Please wait") and search_wait_tick > 10) then
        yield("/callback RetainerSell true 4")
        yield("/wait 0.1")
        if IsAddonVisible("ItemHistory")==false then
          yield("/callback ItemSearchResult true 0")
        end
        yield("/wait 0.1")
        search_wait_tick = 0
      end
    end
    yield("/wait 0.1")
  end
  old_first_price = first_price
  search_results = string.gsub(GetNodeText("ItemSearchResult", 2),"%D","")
  debug("Search results: "..search_results)
  return search_results
end

function SearchPrices()
  yield("/waitaddon ItemSearchResult")
  prices_list = {}
  prices_list_length = 0
  for i= 1, 10 do
    raw_price = GetNodeText("ItemSearchResult", 5, i, 10)
    if raw_price~="" and raw_price~=10 then
      trimmed_price = string.gsub(raw_price,"%D","")
      prices_list[i] = tonumber(trimmed_price)
    end
  end
  debug(open_item.." Prices")
  for price_number, _ in pairs(prices_list) do
    debug(prices_list[price_number])
    prices_list_length = prices_list_length + 1
  end
end

function SearchRetainers()
  search_retainers = {}
  for i= 1, 10 do
    market_search_retainer = GetNodeText("ItemSearchResult", 5, i, 5)
    if market_search_retainer~="" and market_search_retainer~=5 then
      search_retainers[i] = market_search_retainer
    end
  end
  if is_debug then
    debug(open_item.." Retainers")
    for i = 1,10 do
      if search_retainers[i] then
        debug(search_retainers[i])
      end
    end
  end
end

function HistoryAverage()
  while IsAddonVisible("ItemHistory")==false do
    yield("/callback ItemSearchResult true 0")
    yield("/wait 0.3")
  end
  yield("/waitaddon ItemHistory")
  history_tm_count = 0
  history_tm_running = 0
  history_list = {}
  first_history = string.gsub(GetNodeText("ItemHistory", 3, 2, 6),"%d","")
  while first_history=="" do
    yield("/wait 0.1")
    first_history = string.gsub(GetNodeText("ItemHistory", 3, 2, 6),"%d","")
  end
  yield("/wait 0.1")
  for i= 2, 21 do
    raw_history_price = GetNodeText("ItemHistory", 3, i, 6)
    if raw_history_price ~= 6 and raw_history_price ~= "" then
      trimmed_history_price = string.gsub(raw_history_price,"%D","")
      history_list[i-1] = tonumber(trimmed_history_price)
      history_tm_count = history_tm_count + 1
    end
  end
  debug("History items: "..history_tm_count)
  table.sort(history_list)
  for i=1, history_trim_amount do
    if history_tm_count > 2 then
      table.remove(history_list, history_tm_count)
      table.remove(history_list, 1)
      history_tm_count = history_tm_count - 2
    else
      break
    end
  end
  for history_tm_count, history_tm_price in pairs(history_list) do
    history_tm_running = history_tm_running + history_tm_price
  end
  history_trimmed_mean = history_tm_running // history_tm_count
  debug("History trimmed mean:" .. history_trimmed_mean)
  return history_trimmed_mean
end

function ItemOverride(mode)
  if is_using_overrides then
    itemor = nil
    is_price_overridden = false
    for item_test, _ in pairs(item_overrides) do
      if open_item == string.gsub(item_test,"%W","") then
        itemor = item_overrides[item_test]
        break
      end
    end
    if not itemor then return false end
    if itemor.default and mode == "default" then
      price = tonumber(itemor.default)
      is_price_overridden = true
      debug(open_item.." default price: "..itemor.default.." applied!")
    end
    if itemor.minimum then
      if price < itemor.minimum then
        price = tonumber(itemor.minimum)
        is_price_overridden = true
        debug(open_item.." minimum price: "..itemor.minimum.." applied!")
      end
    end
    if itemor.maximum then
      if price > itemor.maximum then
        price = tonumber(itemor.maximum)
        is_price_overridden = true
        debug(open_item.." maximum price: "..itemor.maximum.." applied!")
      end
    end
  end
end

function SetPrice(price)
  debug("Setting price to: "..price)
  if IsAddonVisible("ItemSearchResult") then
    yield("/callback ItemSearchResult true -1")
  end
  yield("/callback RetainerSell true 2 "..price)
  yield("/callback RetainerSell true 0")
  CloseSales()
end

function CloseSearch()
  while IsAddonVisible("ItemSearchResult") or IsAddonVisible("ItemHistory") do
    yield("/wait 0.1")
    if IsAddonVisible("ItemSearchResult") then yield("/callback ItemSearchResult true -1") end
    if IsAddonVisible("ItemHistory") then yield("/callback ItemHistory true -1") end
  end
end

function CloseSales()
  CloseSearch()
  while IsAddonVisible("RetainerSell") do
    yield("/wait 0.1")
    if IsAddonVisible("RetainerSell") then yield("/callback RetainerSell true -1") end
  end
end

function SomethingBroke(what_should_be_visible, extra_info)
  for broken_rechecks=1, 20 do
    if IsAddonVisible(what_should_be_visible) then
      still_broken = false
      break
    else
      yield("/wait 0.1")
    end
  end
  if still_broken then
    yield("/echo It looks like something has gone wrong.")
    if what_should_be_visible then yield("/echo "..what_should_be_visible.." should be visible, but it isn't.") end
    yield("/echo Attempting to fix this, please wait.")
    if extra_info then yield("/echo "..extra_info) end
    --yield("")
    yield("/echo On second thought, I haven't finished this yet.")
    yield("/echo Oops!")
    yield("/pcraft stop")
  end
end

function NextCharacter()
  current_character = GetCharacterName(true)
  next_character = nil
  debug("Current character: "..current_character)
  for character_number, character_name in pairs(my_characters) do
    if character_name == current_character then
      next_character = my_characters[character_number+1]
      break
    end
  end
  return next_character
end

function Relog(relog_character)
  echo(relog_character)
  yield("/ays relog " .. relog_character)
  while GetCharacterCondition(1) do
    yield("/wait 1.01")
  end
  while GetCharacterCondition(1, false) do
    yield("/wait 1.02")
  end
  while GetCharacterCondition(45) or GetCharacterCondition(35) do
    yield("/wait 1.03")
  end
  yield("/wait 0.5")
  while GetCharacterCondition(35) do
    yield("/wait 1.04")
  end
  yield("/wait 2")
end

function EnterHouse()
  if IsInZone(339) or IsInZone(340) or IsInZone(341) or IsInZone(641) or IsInZone(979) or IsInZone(136) then
    debug("Entering house")
    if is_use_ar_to_enter_house then
      yield("/ays het")
    else
      yield("/target Entrance")
      yield("/target Apartment Building Entrance")
    end
    yield("/wait 1")
    if string.find(string.lower(GetTargetName()), "entrance") then
      while IsInZone(339) or IsInZone(340) or IsInZone(341) or IsInZone(641) or IsInZone(979) or IsInZone(136) do
        if not is_use_ar_to_enter_house then
          yield("/lockon on")
          yield("/automove on")
        end
        yield("/wait 1.2")
      end
      het_tick = 0
      while het_tick < 3 do
        if IsPlayerOccupied() then het_tick = 0
        elseif IsMoving() then het_tick = 0
        else het_tick = het_tick + 0.2
        end
        yield("/wait 0.200")
      end
    else
      debug("Not entering house?")
    end
  end
end

function OpenBell()
  EnterHouse()
  target_tick = 1
  while GetCharacterCondition(50, false) do
    if target_tick > 99 then
      break
    elseif string.lower(GetTargetName())~="summoning bell" then
      debug("Finding summoning bell...")
      yield("/target Summoning Bell")
      target_tick = target_tick + 1
    elseif GetDistanceToTarget()<20 then
      yield("/lockon on")
      yield("/automove on")
      yield("/pinteract")
    else
      yield("/automove off")
      yield("/pinteract")
    end
    yield("/lockon on")
    yield("/wait 0.511")
  end
  if GetCharacterCondition(50) then
    yield("/lockon off")
    while not IsAddonVisible("RetainerList") do yield("/wait 0.100") end
    yield("/wait 0.4")
    return true
  else
    return false
  end
end

function WaitARFinish(ar_time)
  title_wait = 0
  if not ar_time then ar_time = 10 end
  while IsAddonVisible("_TitleMenu")==false do
    yield("/wait 5.01")
  end
  while true do
    if IsAddonVisible("_TitleMenu") and IsAddonVisible("NowLoading")==false then
      title_wait = title_wait + 1
    else
      title_wait = 0
    end
    if title_wait > ar_time then
      break
    end
    yield("/wait 1.0"..ar_time - title_wait)
  end
end

function echo(input)
  if is_verbose then
    yield("/echo [MarketBotty] "..input)
  else
    yield("/wait 0.01")
  end
end

function debug(debug_input)
  if is_debug then
    yield("/echo [MarketBotty][DEBUG] "..debug_input)
  else
    yield("/wait 0.01")
  end
end

function Clear()
  next_retainer = 0
  prices_list = {}
  item_list = {}
  item_count = 0
  search_retainers = {}
  last_item = ""
  open_item = ""
  is_single_retainer_mode = false
  undercut = 1
  target_sale_slot = 1
end

------------------------------------------------------------------------------------------------------

-- Tried to do this as functions, but it was too hard. Oh well.
if is_read_from_files then
  if file_exists(config_folder..marketbotty_settings) then
    chunk = loadfile(config_folder..marketbotty_settings)
    chunk()
  end
  file_characters = config_folder..characters_file
  if file_exists(file_characters) and is_multimode then
    my_characters = {}
    file_characters = io.input(file_characters)
    next_line = file_characters:read("l")
    i = 0
    while next_line do
      i = i + 1
      my_characters[i] = next_line
      if is_echo_during_read then debug("Character "..i.." from file: "..next_line) end
      next_line = file_characters:read("l")
    end
    file_characters:close()
    echo("Characters loaded from file: "..i)
    if i <= 1 then
      is_multimode = false
    end
  else
    echo(file_characters.." not found!")
  end
  file_retainers = config_folder..retainers_file
  if file_exists(file_retainers) and is_dont_undercut_my_retainers then
    my_retainers = {}
    file_retainers = io.input(file_retainers)
    next_line = file_retainers:read("l")
    i = 0
    while next_line do
      i = i + 1
      my_retainers[i] = next_line
      if is_echo_during_read then debug("Retainer "..i.." from file: "..next_line) end
      next_line = file_retainers:read("l")
    end
    file_retainers:close()
    echo("Retainers loaded from file: "..i)
  else
    echo(file_retainers.." not found!")
  end
  file_blacklist = config_folder..blacklist_file
  if file_exists(file_blacklist) and is_using_blacklist then
    blacklist_retainers = {}
    file_blacklist = io.input(file_blacklist)
    next_line = file_blacklist:read("l")
    i = 0
    while next_line do
      i = i + 1
      blacklist_retainers[i] = next_line
      if is_echo_during_read then debug("Blacklist "..i.." from file: "..next_line) end
      next_line = file_blacklist:read("l")
    end
    file_blacklist:close()
    echo("Blacklist loaded from file: "..i)
  else
    echo(file_blacklist.." not found!")
  end
  file_overrides = config_folder..overrides_file
  if file_exists(file_overrides) and is_using_overrides then
    chunk = nil
    item_overrides = {}
    chunk = loadfile(file_overrides)
    chunk()
    or_count = 0
    for _, i in pairs(item_overrides) do or_count = or_count + 1 end
    echo("Overrides loaded from file: "..or_count)
  else
    echo(file_overrides.." not found!")
  end
end
uc=1
au=1
if is_override_report then
  override_items_count = 0
  override_report = {}
end
if is_postrun_one_gil_report then
  one_gil_items_count = 0
  one_gil_report = {}
end
if is_postrun_sanity_report then
  sanity_items_count = 0
  sanity_report = {}
end

if IsAddonVisible("RetainerList") then is_multimode = false end

::MultiWait::
if start_wait and is_autoretainer_while_waiting then
    WaitARFinish()
    yield("/ays multi d")
end
after_multi = tostring(after_multi)
if string.find(after_multi, "wait logout") then
elseif string.find(after_multi, "wait") then
  multi_wait = string.gsub(after_multi,"%D","") * 60
  wait_until = os.time() + multi_wait
end

if is_write_to_files then
  is_add_to_file = true
  current_character = GetCharacterName(true)
  for _, character_name in pairs(my_characters) do
    if character_name == current_character then
      is_add_to_file = false
      break
    end
  end
  if is_add_to_file and current_character~="null" then
    file_characters = io.open(config_folder..characters_file,"a")
    file_characters:write("\n"..current_character)
    io.close(file_characters)
  end
end

::Startup::
Clear()
if GetCharacterCondition(1, false) then
  echo("Not logged in?")
  yield("/wait 1")
  Relog(my_characters[1])
  goto Startup
elseif GetCharacterCondition(50, false) then
  echo("Not at a summoning bell.")
  OpenBell()
  goto Startup
elseif IsAddonVisible("RecommendList") then
  helper_mode = true
  while IsAddonVisible("RecommendList") do
    yield("/callback RecommendList true -1")
    yield("/wait 0.1")
  end
  echo("Starting in helper mode!")
  goto Helper
elseif IsAddonVisible("RetainerList") then
  CountRetainers()
  goto NextRetainer
elseif IsAddonVisible("RetainerSell") then
  echo("Starting in single item mode!")
  is_single_item_mode = true
  goto RepeatItem
elseif IsAddonVisible("SelectString") then
  echo("Starting in single retainer mode!")
  yield("/click SelectString_Entry3")
  yield("/waitaddon RetainerSellList")
  is_single_retainer_mode = true
  goto Sales
elseif IsAddonVisible("RetainerSellList") then
  echo("Starting in single retainer mode!")
  is_single_retainer_mode = true
  goto Sales
else
  echo("Unexpected starting conditions!")
  echo("You broke it. It's your fault.")
  echo("Do not message me asking for help.")
  yield("/pcraft stop")
end

------------------------------------------------------------------------------------------------------

::NextRetainer::
if next_retainer < total_retainers then
  next_retainer = next_retainer + 1
else
  goto MultiMode
end
yield("/wait 0.1")
target_sale_slot = 1
OpenRetainer(retainers_to_run[next_retainer])

::Sales::
if CountItems() == 0 then goto Loop end

::NextItem::
ClickItem(target_sale_slot)

::Helper::
au = uc
while IsAddonVisible("RetainerSell")==false do
  yield("/wait 0.5")
  if GetCharacterCondition(50, false) or IsAddonVisible("RecommendList") then
    goto EndOfScript
  end
end

::RepeatItem::
ReadOpenItem()
if last_item~="" then
  if open_item == last_item then
    debug("Repeat: "..open_item.." set to "..price)
    goto Apply
  end
end

::ReadPrices::
SearchResults()
current_price = string.gsub(GetNodeText("RetainerSell",6),"%D","")
if (string.find(GetNodeText("ItemSearchResult", 26), "No items found.")) then
  if type(history_multiplier)=="number" then
    price = HistoryAverage() * history_multiplier
    price_length = string.len(tostring(price))
    if price_length >= 5 then
      exp = 10 ^ math.ceil(price_length * 0.6)
      price = math.tointeger(math.floor(price // exp) * exp)
    end
  else
    price_length = string.len(tostring(HistoryAverage()))
    price = math.tointeger(10 ^ price_length)
  end
  CloseSearch()
  ItemOverride("default")
  goto Apply
end
target_price = 1
if is_blind then
  raw_price = GetNodeText("ItemSearchResult", 5, i, 10)
  if raw_price~="" and raw_price~=10 then
    trimmed_price = string.gsub(raw_price,"%D","")
    price = trimmed_price - uc
    goto Apply
  else
    echo("Price not found")
    yield("/pcraft stop")
  end
else
  SearchPrices()
  SearchRetainers()
  HistoryAverage()
  CloseSearch()
end

if is_check_for_hq then
  hq = GetNodeText("RetainerSell",18)
  hq = string.gsub(hq,"%g","")
  hq = string.gsub(hq,"%s","")
  if string.len(hq)==3 then
    is_hq = true
    debug("High quality!")
  else
    is_hq = false
    debug("Normal quality.")
  end
end

::PricingLogic::
if is_price_sanity_checking and target_price < prices_list_length then
  if prices_list[target_price] == 1 then
    target_price = target_price + 1
    goto PricingLogic
  end
  if prices_list[target_price] <= (history_trimmed_mean // 2) then
    target_price = target_price + 1
    goto PricingLogic
  end
  debug("Price sanity checking results:")
  debug("target_price "..target_price)
  debug("prices_list[target_price] "..prices_list[target_price])
end
if is_check_for_hq and is_hq and target_price < prices_list_length then
  debug("Checking listing "..target_price.." for HQ...")
  if target_price==1 then
    node_hq = 4
  else
    node_hq = target_price + 40999
  end
  --if not IsNodeVisible("ItemSearchResult", 5, target_price, 13) then
  if not IsNodeVisible("ItemSearchResult", 1, 26, node_hq, 2, 3) then
    debug(target_price.." not HQ")
    target_price = target_price + 1
    goto PricingLogic
  end
end
if is_dont_undercut_my_retainers then
  for _, retainer_test in pairs(my_retainers) do
    if retainer_test == search_retainers[target_price] then
      au = 0
      debug("Matching price with own retainer: "..retainer_test)
      break
    end
  end
end
price = prices_list[target_price] - au
ItemOverride()
if is_override_report and is_price_overridden then
  override_items_count = override_items_count + 1
  if is_multimode then
    override_report[override_items_count] = open_item.." on "..GetCharacterName().." set: "..price..". Low: "..prices_list[1]
  else
    override_report[override_items_count] = open_item.." set: "..price..". Low: "..prices_list[1]
  end
elseif price <= 1 then
  echo("Should probably vendor this crap instead of setting it to 1. Since this script isn't *that* good yet, I'm just going to set it to...69. That's a nice number. You can deal with it yourself.")
  price = 69
  if is_postrun_one_gil_report then
    one_gil_items_count = one_gil_items_count + 1
    if is_multimode then
      one_gil_report[one_gil_items_count] = open_item.." on "..GetCharacterName()
    else
      one_gil_report[one_gil_items_count] = open_item
    end
  end
elseif is_postrun_sanity_report and target_price ~= 1 then
  sanity_items_count = sanity_items_count + 1
  if is_multimode then
    sanity_report[sanity_items_count] = open_item.." on "..GetCharacterName().." set: "..price..". Low: "..prices_list[1]
  else
    sanity_report[sanity_items_count] = open_item.." set: "..price..". Low: "..prices_list[1]
  end
end

::Apply::
if price ~= tonumber(string.gsub(GetNodeText("RetainerSell",6),"%D","")) then
  SetPrice(price)
end
CloseSales()

::Loop::
if helper_mode then
  yield("/wait 1")
  goto Helper
elseif is_single_item_mode then
  yield("/pcraft stop")
elseif not (tonumber(item_count) <= target_sale_slot) then
  target_sale_slot = target_sale_slot + 1
  goto NextItem
elseif is_single_retainer_mode then
  goto EndOfScript
elseif is_single_retainer_mode==false then
  CloseRetainer()
  goto NextRetainer
end

::MultiMode::
if is_multimode then
  while IsAddonVisible("RetainerList") do
    yield("/callback RetainerList true -1")
    yield("/wait 1")
  end
  NextCharacter()
  if not next_character then goto AfterMulti end
  Relog(next_character)
  if OpenBell()==false then goto MultiMode end
  goto Startup
else
  goto EndOfScript
end

::AfterMulti::
yield("/wait 3")
if string.find(after_multi, "logout") then
  yield("/logout")
  yield("/waitaddon SelectYesno")
  yield("/wait 0.5")
  yield("/callback SelectYesno true 0")
  while GetCharacterCondition(1) do
    yield("/wait 1.1")
  end
elseif wait_until then
  if is_autoretainer_while_waiting then
    yield("/ays multi e")
    while GetCharacterCondition(1, false) do
      yield("/wait 10.1")
    end
  end
  while os.time() < wait_until do
    yield("/wait 12")
  end
  if is_autoretainer_while_waiting then
    WaitARFinish()
    yield("/ays multi d")
  end
  goto MultiWait
elseif type(after_multi) == "number" then
  Relog(my_characters[after_multi])
end

if string.find(after_multi, "wait logout") then
  if is_autoretainer_while_waiting then
    yield("/ays multi e")
    while GetCharacterCondition(1, false) do
      yield("/wait 10.2")
    end
  end
  WaitARFinish()
  if is_autoretainer_while_waiting then yield("/ays multi d") end
  goto MultiWait
end

if GetCharacterCondition(50, false) and multimode_ending_command then
  yield("/wait 3")
  yield(multimode_ending_command)
end

::EndOfScript::
while IsAddonVisible("RecommendList") do
  yield("/callback RecommendList true -1")
  yield("/wait 0.1")
end
echo("---------------------")
echo("MarketBotty finished!")
echo("---------------------")
if is_override_report and override_items_count ~= 0 then
  echo("Items that triggered override: "..override_items_count)
  for i = 1, override_items_count do
    echo(override_report[i])
  end
  echo("---------------------")
end
if is_postrun_one_gil_report and one_gil_items_count ~= 0 then
  echo("Items that triggered 1 gil check: "..one_gil_items_count)
  for i = 1, one_gil_items_count do
    echo(one_gil_report[i])
  end
  echo("---------------------")
end
if is_postrun_sanity_report and sanity_items_count ~= 0 then
  echo("Items that triggered sanity check: "..sanity_items_count)
  for i = 1, sanity_items_count do
    echo(sanity_report[i])
  end
  echo("---------------------")
end
yield("/pcraft stop")
yield("/pcraft stop")
yield("/pcraft stop")
