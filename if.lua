require "mix"

-- Rulebook functions
----------------------------------------

Rulebook = behavior()

function Rulebook.on_become(obj)
   obj.rules = obj.rules or {}
end

-- A rule is a function that takes a command, and if that rule
-- applies to that command, then changes the game state some
-- and returns a message to be shown to the player.
function Rulebook.methods.add(rulebook, rule)
   table.insert(rulebook.rules, 1, rule)
   return rulebook
end

-- Call every rule in the book, with the command, returning
-- the last non-nil return value. (ideally only one rule will
-- return non-nil)
function Rulebook.methods.handle(rulebook, command)
   local message = nil

   for _, rule in ipairs(rulebook.rules) do
	  message = rule(rulebook, command) or message
   end

   return message
end

-- Room functions
----------------------------------------

Room = behavior()

function Room.find_by_name(_, name)
   return Room.all:select(function(room) return room.name == name end)[1]
end

setmetatable(Room, {__index = Room.find_by_name})

function Room.new(attrs)
   return new(attrs, Room, Rulebook)
end

function Room.methods.describe(room)
   local str = room.name .. "\n\n" .. room.description

   local items = Prop.find_by_container(room)
   if #items > 0 then
	  str = str .. "\n\nThere is " .. table.to_sentence(items) .. " here."
   end

   return str
end

function Room.methods.room_in_dir(room, dir)
   return Room[room.exits[dir]]
end

function table.to_sentence(items)
   local strs = items:map(function(i) return i.article .. " " .. i.name end)

   if #strs == 0 then return ""
   elseif #strs == 1 then return strs[1]
   else
	  return table.concat(strs, ", ", 1, #strs - 1) .. " and " .. strs[#strs]
   end
end

-- Prop functions
----------------------------------------

Prop = behavior()

Prop.methods.article = "a"

function Prop.new(name, container)
   return new({ name = name, container = container }, Rulebook, Prop)
end

function Prop.find_by_name(_, name)
   return Prop.all:select(function(p) return p.name == name end)[1]
end

function Prop.find_by_container(container)
   return Prop.all:select(function(p) return p.container == container end)
end

setmetatable(Prop, {__index = Prop.find_by_name})

function Prop.methods.handle(prop, command)
   local resp = Rulebook.methods.handle(prop, command)

   if resp then return resp
   elseif prop[command.verb] then
	  return prop[command.verb](prop, command)
   else
	  return nil
   end
end

-- Game functions
----------------------------------------

Game = behavior()

-- The game has several different layers of rulebooks:
--
-- system_rules: for things like save / load / exit, to
-- keep them being overridden by anything.
--
-- global_rules: conditions that affect the whole game,
-- like darkness.
--
-- current_room: conditions for the current room, like
-- Zork's echo room.
--
-- prop: the command's subject has a rulebook and a table
-- of verb -> function
--
-- last_chance_rules: for handling commands that fell
-- through everything else. Mainly a chance to give better
-- error messages.

function Game.on_become(obj)
   obj.system_rules = new(nil, Rulebook)
   obj.global_rules = new(nil, Rulebook)
   obj.last_chance_rules = new(nil, Rulebook)
   obj.inventory = table.new()
   obj.current_room = nil
end

function Game.methods.input(game, str)
   return game:handle(game:parse(str))
end

function Game.methods.handle(game, command)
   local prop, message

   -- Now, if there's a subject, and it's a prop in this room, find it
   if Prop[command.subject] and
	  Prop[command.subject].container == game.current_room then
	  prop = Prop[command.subject]
   end

   -- Try all the global rules, then the room, then the prop, then a default
   message = game.system_rules:handle(command)
   if message then return message end

   if game.current_room then
	  message = game.current_room:handle(command)
	  if message then return message end
   end

   message = game.global_rules:handle(command)
   if message then return message end

   if prop then
	  message = prop:handle(command)
	  if message then return message end
   end

   message = game.last_chance_rules:handle(command)
   if message then return message end

   return "Sorry, I didn't understand that"
end

Game.preposition_list = {
   'aboard', 'about', 'above', 'across', 'after',
   'against', 'along', 'amid', 'among', 'anti',
   'around', 'as', 'at', 'before', 'behind',
   'below', 'beneath', 'beside', 'besides', 'between',
   'beyond', 'but', 'by', 'concerning', 'considering',
   'despite', 'down', 'during', 'except', 'excepting',
   'excluding', 'following', 'for', 'from', 'in',
   'inside', 'into', 'like', 'minus', 'near',
   'of', 'off', 'on', 'onto', 'opposite',
   'outside', 'over', 'past', 'per', 'plus',
   'regarding', 'round', 'save', 'since', 'than',
   'through', 'to', 'toward', 'towards', 'under',
   'underneath', 'unlike', 'until', 'unto', 'up',
   'upon', 'versus', 'via', 'with', 'within',
   'without' }

Game.prepositions = {} -- A map from word to word, for everything in preposition_list
for _, w in ipairs(Game.preposition_list) do Game.prepositions[w] = w end

-- Turn a string into a command
--
-- The parser recognizes a somewhat stilted form of English, and then relies on
-- Rulebook (and global rewrite rules) to make itself understood. We recognize
-- tuples with four fields:
--
-- A verb, first. Single word, always in the first position, not optional.
--
-- A subject. This is in the second position, can be multiple words, and ends
-- with a preposition.
--
-- A preposition. This is guaranteed to be a word in Game.prepositions
--
-- An object. This is the last term.
--
-- Examples:
--
-- jump ==> {verb='jump'}
-- eat fruit ==> {verb='eat', subject='fruit'}
-- give gold coin to troll ==> {verb='give', subject='gold coin', preposition='to', object='troll'}
-- turn lamp on ==> {verb='turn', subject='lamp', preposition='on'}
-- turn on conveyor belt ==> {verb='turn', subject=nil, preposition='on', object='conveyor belt'}
-- (we would have a rewrite rule for this; nil subject means use object as subject)

function Game.methods.parse(game, str)
   str = str:lower()
   local words, term = table.new(), nil
   for word in str:gmatch("%w+") do words:insert(word) end
   local command = {game = game, verb = words:remove(1)}

   for i, word in ipairs(words) do
	  if Game.prepositions[word] then
		 command.preposition = word
		 command.subject = term
		 term = nil
	  elseif term then
		 term = term .. " " .. word
	  else
		 term = word
	  end
   end

   if command.preposition then
	  command.object = term
   else
	  command.subject = term
   end

   return command
end

