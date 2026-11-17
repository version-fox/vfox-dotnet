-- Copyright 2026 Han Li and contributors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local test = require("vfox.test")
test.load()
local util = require("util")

local cases = 0

-- What a user version means: a bare major keeps the channel at the major so
-- a later minor can be found, while two or three numbers name a channel.
local function parse(input, major, minor, patch, channel, release)
    local got = util:parseVersion(input)
    assert(got.major == major, tostring(input) .. ": major " .. tostring(got.major))
    assert(got.minor == minor, tostring(input) .. ": minor " .. tostring(got.minor))
    assert(got.patch == patch, tostring(input) .. ": patch " .. tostring(got.patch))
    assert(got.channelVersion == channel, tostring(input) .. ": channel " .. tostring(got.channelVersion))
    assert(got.releaseVersion == release, tostring(input) .. ": release " .. tostring(got.releaseVersion))
    cases = cases + 1
end

parse("9", 9, 0, 0, "9.0", "9.0.0")
parse("8", 8, 0, 0, "8.0", "8.0.0")
parse("9.1", 9, 1, 0, "9.1", "9.1.0")
parse("8.0", 8, 0, 0, "8.0", "8.0.0")
parse("9.0.12", 9, 0, 12, "9.0", "9.0.12")
parse("8.0.428", 8, 0, 428, "8.0", "8.0.428")
-- An empty or missing version is an all-zero release rather than an error;
-- callers decide what to do with it.
parse(nil, 0, 0, 0, "0.0", "0.0.0")
parse("", 0, 0, 0, "0.0", "0.0.0")
-- Non-numeric parts are ignored, so an early-access label does not break the
-- numeric lookup that follows.
parse("10.0.0-preview.1", 10, 0, 0, "10.0", "10.0.0")

print("PASS: " .. cases .. " parseVersion cases")
