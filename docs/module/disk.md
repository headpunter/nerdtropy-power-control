# disk API Documentation

The `disk` API enables interaction with disk drives. Functions work with locally attached drives (by side) or remote drives (by name like `drive_0`).

## Functions

### isPresent(name) → boolean
Determines if any item occupies the disk drive.

### getLabel(name) → string | nil
Retrieves the label of media in the drive.

### setLabel(name, label)
Changes the label of media in the drive.
**Parameters:** `label` (string | nil)

### hasData(name) → boolean
Checks if the disk provides a mountable filesystem (disks/computers, not records).

### getMountPath(name) → string | nil
Returns the directory path where mounted disk contents are accessible.

### hasAudio(name) → boolean
Determines if the disk is a music record.

### getAudioTitle(name) → string | false | nil
Retrieves the track title. Returns false if no record, nil if no drive.

### playAudio(name)
Begins playback of a music record.

### stopAudio(name)
Halts playback started via `playAudio()`.

### eject(name)
Removes and drops the item from the drive.

### getID(name) → string | nil
Returns a unique identifier for floppy disks (not other media types).
