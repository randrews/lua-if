require "if"

-- All the rooms
----------------------------------------

Room.new{
   name = "Kitchen",
   description = "A simple kitchen.",
   exits = { w = "Living Room" }
}

Room.new{
   name = "Living Room",
   description = "A well-appointed but cluttered living room.",
   exits = { e = "Kitchen", s = "Bedroom" }
}

Room.new{
   name = "Bedroom",
   description = "A comfortable bedroom with a well-thumbed book collection.",
   exits = { n = "Living Room" }
}

-- Some props
----------------------------------------

Prop.new("bed", Room.Bedroom)
Prop.new("bookcases", Room.Bedroom)
Prop.new("lamp", Room.Bedroom)

Prop.new("pillow", Prop.bed)
Prop.new("book", Prop.bookcases)

Prop.bookcases.article = "some"

Prop.lamp.turned_on = false

function Prop.lamp.turn(lamp, command)
   if command.preposition == "on" then
	  lamp.turned_on = true
	  return "You turn the lamp on."
   elseif command.preposition == "off" then
	  lamp.turned_on = false
	  return "You turn the lamp off."
   end
end

function Prop.lamp.examine(lamp, command)
   if lamp.turned_on then
	  return "The lamp is glowing brightly."
   else
	  return "The lamp is dark."
   end
end

-- Game object
----------------------------------------

game = new(nil, Game)
game.current_room = Room.Bedroom
