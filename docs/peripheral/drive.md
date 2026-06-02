# Drive Peripheral Documentation

Interact with a floppy disk drive. Fires `disk` on insertion and `disk_eject` on removal.

## Methods

### isDiskPresent() → boolean
Checks if a disk is in the drive.

### getDiskLabel() → string | nil
Gets the disk's label.

### setDiskLabel([label])
Sets or clears the disk label. Throws if label can't be changed (e.g., records).

### hasData() → boolean
Whether a data disk is inserted.

### getMountPath() → string | nil
Gets the mount path for the disk (e.g., `/disk`).

### hasAudio() → boolean
Whether an audio disk is inserted.

### getAudioTitle() → string | nil | false
Gets audio track title. `false` if no disk, `nil` if no audio.

### playAudio()
Plays the audio disk.

### stopAudio()
Stops playing audio.

### ejectDisk()
Ejects the disk.

### getDiskID() → number | nil
Returns the disk's unique ID (floppy disks only).
