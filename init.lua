
------------
-- Constants
------------

local max_instructions = 10000 -- to avoid infinite loops
local arr_size = 30000
-- also numbers are 0-255


------------------
-- Execution logic
------------------

local possible_instructions = {">", "<", "+", "-", ".", ",", "[", "]"}
for num, instr in ipairs(possible_instructions) do
	possible_instructions[instr] = num
end

-- Parses brainfuck code to single instructions
-- returns an array of instructions
local function parse_brainfuck(code)
	local instructions = {}
	local instr_index = 1
	local jmps, jmps_count = {}, 0

	for i = 1, #code do
		local char = string.sub(code, i, i)

		local instr_num = possible_instructions[char]
		if instr_num then
			instructions[instr_index] = char

			if char == "[" then
				-- a jump forward
				jmps_count = jmps_count + 1
				jmps[jmps_count] = instr_index

			elseif char == "]" then
				-- a jump backward
				local forward_index
				if jmps_count > 0 then
					forward_index = jmps[jmps_count]
					instructions[forward_index] = "[" .. instr_index
					jmps[jmps_count] = nil
					jmps_count = jmps_count - 1
				else
					forward_index = 1 -- no opening brace, jump back to start
				end

				instructions[instr_index] = "]" .. forward_index
			end

			instr_index = instr_index + 1
		end
	end

	-- all other forward jumps jump to the end
	for i = jmps_count, 1, -1 do
		instructions[jmps[i]] = instr_index
	end

	return instructions
end

local function error_message(operation, pc, msg)
	-- (pc is already incremented)
	return string.format("Error: \"%s\" failed at %i: %s", operation, pc - 1, msg)
end

local function execute_brainfuck(code, input)
	-- parse
	local instructions = parse_brainfuck(code)
	local prog_end = #instructions

	-- init run-time stuff
	local arr = {0}
	local ptr = 1 -- pointer to arr (internal; external it begins with 0)
	local pc = 1 -- program counter
	local output = ""
	local input_ptr = 1
	local input_length = #input

	-- execute
	for executed_instructions = 0, max_instructions do
		if pc > prog_end then
			-- program ended
			return true, "Success: " .. output
		end

		local instr = instructions[pc]
		pc = pc + 1

		if instr == ">" then
			if ptr > arr_size then
				return false, error_message(">", pc, "max is " .. arr_size)
			end
			ptr = ptr + 1
			arr[ptr] = arr[ptr] or 0

		elseif instr == "<" then
			if ptr <= 1 then
				return false, error_message("<", pc, "min is 0")
			end
			ptr = ptr - 1

		elseif instr == "+" then
			arr[ptr] = (arr[ptr] + 1) % 256

		elseif instr == "-" then
			arr[ptr] = (arr[ptr] + 255) % 256

		elseif instr == "." then
			output = output .. string.char(arr[ptr])

		elseif instr == "," then
			--~ if input_ptr > input_length then
				--~ return false, error_message(",", pc, "input is too short")
			--~ end
			local num
			if input_ptr > input_length then
				num = 0
			else
				num = string.byte(input, input_ptr)
			end
			if not (num >= 0 and num < 256) then
				return false, error_message(",", pc, "input is not ASCII at " .. input_ptr)
			end
			input_ptr = input_ptr + 1
			arr[ptr] = num

		else -- "[1234" or "]1234"
			if instr:sub(1, 1) == "[" then
				-- jump over if 0
				if arr[ptr] == 0 then
					pc = tonumber(instr:sub(2))
				end
			else -- "]"
				-- jump back if not 0
				if arr[ptr] ~= 0 then
					pc = tonumber(instr:sub(2))
				end
			end
		end
	end

	return false, string.format("Error: Timed out at &i (\"%s\").", pc, instructions[pc])
end


---------------------------
-- Chatcommand registration
---------------------------

minetest.register_chatcommand("brainfuck", {
	params = "[input=\"<input>\" ]<brainfuck code>",
	description = "Executes given brainfuck code",
	privs = {},
	func = function(name, param)
		local input, code
		if param:sub(1, 7) == "input=\"" then
			local in_end = param:find("\" ", 8, false)
			if not in_end then
				return false, "Error: Could not find enclosing \" for input."
			end
			input = param:sub(8, in_end - 1)
			code = param:sub(in_end + 2)
		else
			input = ""
			code = param
		end
		return execute_brainfuck(code, input)
	end,
})
