-- =============================================================================
--  bJobManager
--    by: BurstBiscuit
-- =============================================================================

require "math"
require "table"
require "unicode"
require "lib/lib_Callback2"
require "lib/lib_ChatLib"
require "lib/lib_Debug"
require "lib/lib_Slash"

Debug.EnableLogging(false)


-- =============================================================================
--  Variables
-- =============================================================================

local g_ArcCompleted = false
local g_ArcId = 0
local g_ArcRepeat = false
local g_Debug = false
local c_HelpText = [[/bjm <cancel|debug|restart|start|status|toggle>
	cancel - Cancels the current job
	debug - Enables or disables the debug mode
	restart - Restarts the current job
	start arc_id - Tries to start the job with the corresponding arc_id
	status - Returns some information about the current job and addon state
	toggle - Enables or disables the repetition of jobs]]


-- =============================================================================
--  Functions
-- =============================================================================

function Notification(message)
    ChatLib.Notification({text = "[bJobManager] " .. tostring(message)})
end

function GetJobStatus()
    local stateText = function(state) if (state) then return "enabled" else return "disabled" end end
    local jobStatus = Player.GetJobStatus()

    Debug.Table("GetJobStatus()", jobStatus)

    if (jobStatus and jobStatus.completion_percent and jobStatus.job and jobStatus.job.arc_id) then
        Debug.Table("jobStatus", jobStatus)
        Notification("Current job info:\n\tID: " .. jobStatus.job.arc_id ..
                "\n\tName: " .. jobStatus.job.name ..
                "\n\tCompletion: " .. math.ceil(jobStatus.completion_percent * 100) .. "%")
    else
        Notification("Unable to get job info: no job status was found")
    end

    Notification("Repetition of current job is " .. stateText(g_ArcRepeat))
end

function RequestCancelArc()
    local jobStatus = Player.GetJobStatus()

    Debug.Table("RequestCancelArc()", jobStatus)

    if (jobStatus and jobStatus.job and jobStatus.job.arc_id) then
        Notification("Canceling job " .. jobStatus.job.arc_id .. ": " .. jobStatus.job.name)
        Game.RequestCancelArc(jobStatus.job.arc_id)
    else
        Notification("Unable to cancel current job: no job info was found")
    end
end

function RequestStartArc(arcId)
    if (Player.GetJobStatus()) then
        RequestCancelArc()
    end

    Notification("Trying to start job with id " .. arcId .. " in 3 seconds")
    Callback2.FireAndForget(Game.RequestStartArc, arcId, 3)
end

function RestartArc()
    local jobStatus = Player.GetJobStatus()

    if (jobStatus and jobStatus.job and jobStatus.job.arc_id) then
        RequestStartArc(jobStatus.job.arc_id)
    else
        Notification("Unable to restart current job: no job info was found")
    end
end

function ToggleDebug()
    local stateText = function(state) if (state) then return "enabled" else return "disabled" end end
    g_Debug = not g_Debug

    Debug.EnableLogging(g_Debug)
    Notification("Debug mode " .. stateText(g_Debug))
end

function ToggleRepetition()
    local stateText = function(state) if (state) then return "enabled" else return "disabled" end end
    g_ArcRepeat = not g_ArcRepeat

    Notification("Repetition of current job " .. stateText(g_ArcRepeat))
end

function OnSlashCommand(args)
    if (args[1]) then
        if (args[1] == "cancel") then
            RequestCancelArc()
        elseif (args[1] == "debug") then
            ToggleDebug()
        elseif (args[1] == "restart") then
            RestartArc()
        elseif (args[1] == "start") then
            if (args[2] and unicode.match(args[2], "^%d+$")) then
                RequestStartArc(args[2])
            else
                Notification("/bjm start arc_id\n\tarc_id must be an integer > 0")
            end
        elseif (args[1] == "status") then
            GetJobStatus()
        elseif (args[1] == "toggle") then
            ToggleRepetition()
        else
            Notification(c_HelpText)
        end
    else
        Notification(c_HelpText)
    end
end


-- =============================================================================
--  Events
-- =============================================================================

function OnComponentLoad()
    LIB_SLASH.BindCallback({
        slash_list = "bjobmanager, bjm",
        description = "bJobManager",
        func = OnSlashCommand
    })
end

function OnArcAcknowledge(args)
    Debug.Table("OnArcAcknowledge()", args)
    g_ArcCompleted = false
end

function OnArcStatusChanged(args)
    Debug.Table("OnArcStatusChanged()", args)

    if (g_ArcRepeat) then
        if (args.percent_complete and args.percent_complete == 100) then
            Debug.Log("percent_complete is 100, waiting for ON_ARC_STATUS_CHANGED event")
            g_ArcCompleted = true
            g_ArcId = args.arc
        elseif (g_ArcCompleted and g_ArcId > 0) then
            Debug.Log("percent_complete is 100, ON_ARC_STATUS_CHANGED event received, restarting job")
            RequestStartArc(g_ArcId)
        end
    end
end
