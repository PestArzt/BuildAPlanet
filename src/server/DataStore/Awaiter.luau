local Awaiter = {}
Awaiter.job = {}
Awaiter.__index = Awaiter.job

Awaiter.Situations = {
	Running = 'Running',
	Succeed = 'Succeed',
	Failed = 'Failed',
	Stopped = 'Stopped'
}

local function packParams(...)
	local paramsSize = select('#', ...)
	return paramsSize, { ... }
end

local function callJob(job, ...)
	local argsLength, args = packParams(...)

	local JobBody = function()
		return job(unpack(args, 1, argsLength))
	end

	local resultLength, result = packParams(xpcall(JobBody, debug.traceback))
	
	return resultLength, result
end

local function createNextJob(job, success)
	return function(...)
		local paramsSize, params = callJob(job, ...)
		
		success(unpack(params, 2, paramsSize))
	end
end

function Awaiter.run(job)
	local self = {
		_situation = Awaiter.Situations.Running,

		["AwaiterJob"] = true,

		_results = nil,

		_resultsSize = 0,

		_linedUpSuccess = {},
		_linedUpFailure = {},
		_linedUpOnEnd = {}
	}

	setmetatable(self, Awaiter)

	local function succeed(...)
		self:successHandle(...)
	end

	local function failure(...)
		self:failureHandle(...)
	end

	local leng, result = callJob(job, succeed, failure)

	return self
end





function Awaiter.desync(job)
	return Awaiter.run(function(...)
		local params = {...}
		local paramsLength = select("#", params)

		local desyncConnection
		desyncConnection = game:GetService("RunService").Heartbeat:Connect(function()
			desyncConnection:Disconnect()
			job(unpack(params, 1, paramsLength))
		end)
	end)
end

function Awaiter.isAwaiterJob(subject)
	if type(subject) ~= "table" then return false end
	return subject["AwaiterJob"] == true
end

function Awaiter.job:doNext(successHandler, failureHandler)
	return Awaiter.run(function(succeed, failure)

		local successJob = succeed
		if successHandler then successJob = createNextJob(successHandler, succeed) end

		local failureJob = failure
		if failureHandler then failureJob = createNextJob(failureHandler, failure) end

		if self._situation == Awaiter.Situations.Running then
			table.insert(self._linedUpSuccess, successJob)
			table.insert(self._linedUpFailure, failureJob)
		elseif self._situation == Awaiter.Situations.Succeed then
			successJob(unpack(self._results, 1, self._resultsSize))
		end
	end)
end

function Awaiter.job:stop(finalHandler)
	if self._situation ~= Awaiter.Situations.Running then
		return
	else
		self._situation = Awaiter.Situations.Stopped
	end
end

function Awaiter.job:ending(finalHandler)
	return Awaiter.run(function(succeed, failure)
		local finalJob = succeed
		if finalHandler then finalJob = createNextJob(finalHandler, succeed, failure) end

		table.insert(self._linedUpOnEnd, finalJob)

		--self._situation = Awaiter.Situations.Succeed
	end)
end

function Awaiter.job:waitFor(finalHandler)
	if self._situation == Awaiter.Situations.Running then
		repeat task.wait() until self._situation ~= Awaiter.Situations.Running
	end

	if self._situation == Awaiter.Situations.Stopped then
		return
	elseif self._situation ~= Awaiter.Situations.Running then
		return self._situation, unpack(self._results, 1, self._resultsSize)
	end

end


function Awaiter.job:successHandle(...)
	if Awaiter.isAwaiterJob((...)) then
		local awaiterJob = (...):doNext(
			function(...) 
				self:successHandle(...) 
			end,
			function(...) 
				self.failureHandle(...) 
			end)
		return
	end

	self._resultsSize, self._results = packParams(...)
	self._situation = Awaiter.Situations.Succeed

	for _, job in ipairs(self._linedUpSuccess) do
		job(...)
	end

	self:finalizeJob()
end

function Awaiter.job:failureHandle(...)
	self._resultsSize, self._results = packParams(...)

	for _, job in ipairs(self._linedUpFailure) do
		job(...)
	end

	self._situation = Awaiter.Situations.Failed

	self:finalizeJob()
end

function Awaiter.job:finalizeJob()
	for _, job in ipairs(self._linedUpOnEnd) do
		job()
	end
end


function Awaiter.all(jobs)
	return Awaiter.run(function(succeed, failure)
		if type(jobs) ~= "table" then
			failure("Awaiter.all expects a table of jobs.")
			return
		end

		local jobCount = #jobs
		local completedCount = 0
		local hasFailed = false
		if jobCount == 0 then
			succeed()
			return
		end
		for i, job in ipairs(jobs) do
			if not Awaiter.isAwaiterJob(job) then
				if not hasFailed then
					hasFailed = true
					failure("Awaiter.all received a non-awaiter job in the table at index " .. i)
				end
				return 
			end
			job:doNext(
				function()
					if hasFailed then return end 

					completedCount = completedCount + 1


					if completedCount == jobCount then
						succeed()
					end
				end,
				function(...)
					if hasFailed then return end 

					hasFailed = true
					failure(...)
				end
			)
		end
	end)
end


return Awaiter
