-- Behaviors:
-- A Behavior is a table containing a list of objects ("all"),
-- a table of methods ("methods"), and functions that are called
-- when an object becomes or resigns the behavior.

function behavior()
   local b = { all = table.new(),
			   methods = table.new(),
			   on_become = function(obj, behavior) end,
			   on_resign = function(obj, behavior) end }
   return b
end

-- Adding a few utilities to table

table.__index = table

function table.new()
   local t = {}
   setmetatable(t, table)
   return t
end

function table.map(list, fn)
   local new_list = {}
   setmetatable(new_list, table)

   for k,v in pairs(list) do
	  new_list[k] = fn(v, k)
   end

   return new_list
end

function table.delete(haystack, needle)
   local idx = table.find(haystack, needle)
   if idx then table.remove(haystack, idx) end
   return haystack
end

function table.reject(haystack, filter)
   local t = {}
   setmetatable(t, table)

   for k,v in ipairs(haystack) do
	  if not filter(v, k) then table.insert(t, v) end
   end

   return t
end

function table.find(haystack, needle)
   for k, v in pairs(haystack) do
	  if v == needle then
		 return k
	  end
   end

   return nil
end

function table.select(haystack, filter)
   local t = {}
   setmetatable(t, table)

   for k,v in pairs(haystack) do
	  if filter(v, k) then t:insert(v) end
   end

   return t
end

-- A couple basic behaviors:
-- Object is the basic behavior everything starts out with, with
-- functions to handle becoming and resigning behaviors.

Object = behavior()

-- Object's methods:
-- Any object can become a behavior, or it can
-- resign a behavior.

function Object.methods.become(obj, behavior)
   local m = getmetatable(obj)
   
   table.insert(m.behaviors, 1, behavior)
   behavior.all[obj] = obj
   behavior.on_become(obj, behavior)

   return obj
end

function Object.methods.resign(obj, behavior)
   local m = getmetatable(obj)

   behavior.on_resign(obj, behavior)
   behavior.all[obj] = nil
   table.delete(m.behaviors, behavior)

   return obj
end

-- This is how all methods get found. We search the stack of
-- behaviors (most recent to earliest) for the first method
-- called that.

function Object.dispatch(obj, message_name)
   local m = getmetatable(obj)
   if not m then return nil end

   for _, behavior in ipairs(m.behaviors) do
	  if behavior.methods[message_name] then return behavior.methods[message_name] end
   end
   
   return nil
end

-- Creates a new object: An object has a metatable with a
-- behaviors stack and Object.dispatch as its __index. So
-- make one of those and let it become an Object. We can
-- alse pass in a varargs list of different behaviors to
-- become.

function new(obj, ...)
   obj = obj or {}
   setmetatable(obj,
				{ behaviors={}, __index=Object.dispatch })

   Object.methods.become(obj, Object)

   for _, behavior in ipairs(arg) do
	  obj:become(behavior)
   end

   return obj
end

----------------------------------------

A = behavior()

function A.methods.foo(self, x) return self.x * x end
function A.on_become(self) self.x = 10 end

o = new(nil, A)

print(o:foo(9), 90)
print(o.x, 10)

print(A.all[o], o)

o:resign(A)

print(o.foo, nil)
print(A.all[o], nil)