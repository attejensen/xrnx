--[[============================================================================
main.lua
============================================================================]]--

-- Placeholder for the dialog
local dialog = nil

-- Placeholder to expose the ViewBuilder outside the show_dialog() function
local vb = nil

-- Reload the script whenever this file is saved. 
-- Additionally, execute the attached function.
_AUTO_RELOAD_DEBUG = function()
  
end

-- Read from the manifest.xml file.
class "RenoiseScriptingTool" (renoise.Document.DocumentNode)
  function RenoiseScriptingTool:__init()    
    renoise.Document.DocumentNode.__init(self) 
    self:add_property("Name", "Untitled Tool")
    self:add_property("Id", "Unknown Id")
  end

local manifest = RenoiseScriptingTool()
local ok,err = manifest:load_from("manifest.xml")
local tool_name = manifest:property("Name").value
local tool_id = manifest:property("Id").value


local function get_notes_in_song()
   local notes = {}
   for pos, line in renoise.song().pattern_iterator:lines_in_song() do
      if not line.is_empty then
	 for _,column in pairs(line.note_columns) do
	    if not column.is_empty then
	       local instrument = column.instrument_value + 1
	       local note = column.note_value
	       local volume = column.volume_value
	       if volume == 128 or volume == 255 then
		  volume = 127
	       end
	       if notes[instrument] == nil then
		  notes[instrument] = {[note] = {[volume] = true}}
	       else
		  if notes[instrument][note] == nil then
		     notes[instrument][note] = {[volume] = true}
		  else
		     if notes[instrument][note][volume] == nil then
			notes[instrument][note][volume] = true
		     end
		  end
	       end
	    end
	 end
      end
   end
   return notes
end

local function instrument_is_empty(instrument)
   return #instrument.samples == 0
end

local function keys(table)
   local keyset={}
   local n=0
   
   for k,v in pairs(table) do
      n=n+1
      keyset[n]=k
   end
   --table.sort(keyset)
   return keyset
end

local function map_in(instrument_index,map,notes)
   if notes[instrument_index] == nil then
      return false
   end

   local note_used = false
   
   for note_played,vels in pairs(notes[instrument_index]) do
      if note_played >= map.note_range[1] and note_played <= map.note_range[2] then
	 for vel_played,_ in pairs(vels) do
	    if vel_played >= map.velocity_range[1] and vel_played <= map.velocity_range[2] then
	       note_used = true
	       break
	    end
	 end
	 if note_used then
	    break
	 end
      end
   end

   if not note_used then
      return false
   end


   return true
end

local function delete_unused_samples(instrument_nb, instrument, notes_in_song)
   local deleted = 0

   if instrument_is_empty(instrument) then
      return 0
   end


   for i, map in pairs(instrument.sample_mappings) do
      if #map > 0 then
	 for j,one_map in pairs(map) do
	    if not one_map.read_only then
	       if not map_in(instrument_nb,one_map,notes_in_song) and one_map.sample.sample_buffer.has_sample_data then
		  one_map.sample:clear()
		  deleted = deleted + 1
		  --renoise.song().instruments:delete_sample_mapping_at('LAYER_NOTE_ON', i)
	       end
	    end
	 end
      end
   end
   
   return deleted
end


local function count(table)
   local count = 0
   for _ in pairs(table) do
      count = count + 1
   end
   return count
end

local function report(deleted)
   if dialog and dialog.visible then
      dialog:show()
      return
   end
   
   vb = renoise.ViewBuilder()
   
   local text_to_show = 'All samples used, none deleted...'

   if deleted ~= nil and count(deleted) > 0 then
      text_to_show = 'The following number of unused samples were deleted:\n'
      for instrument_name, nb_samples in pairs(deleted) do
	 text_to_show = text_to_show..instrument_name..': '..tostring(nb_samples)..'\n'
      end
   end
   

   local content = vb:column {
      margin = 10,
      vb:text {
	 text = text_to_show
      }
   } 
   
   
   local buttons = {"OK"}
   local choice = renoise.app():show_custom_prompt(
      tool_name, 
      content, 
      buttons
   )  
end



local function delete_all_unused_samples()
   local deleted = {}
   local nb_deleted
   --local start_time
   --start_time = os.clock()
   local notes_in_song = get_notes_in_song()
   --print(os.clock() - start_time)
   
   
   --start_time = os.clock()
   for i, instrument in pairs(renoise.song().instruments) do
      nb_deleted = delete_unused_samples(i,instrument,notes_in_song)
      if nb_deleted > 0 then
	 deleted[string.format("%02d",i-1)..' '..instrument.name] = nb_deleted
      end
   end
   --print(os.clock() - start_time)

   report(deleted)
end
--------------------------------------------------------------------------------
-- Menu entries
--------------------------------------------------------------------------------

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:"..tool_name.."...",
  invoke = delete_all_unused_samples
}


--------------------------------------------------------------------------------
-- Key Binding
--------------------------------------------------------------------------------

--[[
renoise.tool():add_keybinding {
  name = "Global:Tools:" .. tool_name.."...",
  invoke = show_dialog
}
--]]


--------------------------------------------------------------------------------
-- MIDI Mapping
--------------------------------------------------------------------------------

--[[
renoise.tool():add_midi_mapping {
  name = tool_id..":Show Dialog...",
  invoke = show_dialog
}
--]]
