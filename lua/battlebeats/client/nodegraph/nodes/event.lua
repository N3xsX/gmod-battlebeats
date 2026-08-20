--MARK: ZONE
BATTLEBEATS.RegisterNode("event.ZONE", {
    category = "Events",
    title = "Zone Trigger",
    desc = "Fires when players interact with the specified zone. Provides outputs for entering, staying inside, and leaving the zone",

    args = {
        { id = "zone", type = "string", title = "Zone Name" }
    },

    outputs = {
        { id = "entered", type = "boolean", pulse = true },
        { id = "stay", type = "boolean" },
        { id = "exited",  type = "boolean", pulse = true }
    }
})
--MARK: RUNTIME START
BATTLEBEATS.RegisterNode("event.RUNTIME_START", {
    category = "Events",
    title = "Runtime Start",
    desc = "Fires when the runtime starts",

    outputs = {
        { id = "out", type = "boolean", pulse = true }
    }
})