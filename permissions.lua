-- The evidence admin panel (/evidenceadmin): who can open it, and what officers can do before anyone has been set up
-- in it. Officers still need the job and grade from config.lua; the panel decides which parts of the script each of
-- them gets on top of that. The booking terminal is open to every officer and isn't controlled here.
-- This file is only read by the server, so the licences aren't sent to players.
return {
    -- false: every officer with the job can use everything, as before (the panel still opens, but changes do nothing)
    enabled = true,

    -- Who can open the admin panel, by Rockstar licence. Find one in txAdmin, or in the "License" field of this
    -- script's Discord logs.
    admins = {
        -- "license:0123456789abcdef0123456789abcdef01234567",
    },

    -- What an officer can do when the panel doesn't say otherwise. "Everyone" in the panel starts from these and
    -- can change them; each officer can then be allowed or denied each one on their own.
    defaults = {
        laptop = false,         -- log in to an evidence laptop, and place or pick one up
        app_citizens = true,    -- laptop apps, for officers allowed on the laptop
        app_firearms = true,
        app_evidence = true,
        app_cases = true,
        app_wiretap = false,
        microscope = false,     -- the forensics lab at the microscopes, and placing or picking one up
        collect = true,         -- collect evidence with a forensic kit
        swab = true,            -- DNA swabs and gunshot residue tests (swab kit or forensic kit)
        fingerprints = true,    -- take fingerprints from someone, and use the fingerprint scanner
        uv_flashlight = true,   -- switch the UV flashlight's beam on
        uv_lamps = true,        -- place and pick up UV lamps
        markers = true,         -- place and pick up evidence markers
        lockers = true          -- open evidence lockers and their logs
    }
}
