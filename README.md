# docker-deluge
An Alpine Linux Docker container for Deluge 2.0.3

# IMPORTANT INFO

This image is designed to be run in my stack 'steve'. It may not work correctly as a standalone container as I do not test it in that capacity. The stack's docker-compose.yaml is available on GitHub boredazfcuk/steve

The purpose of the stack is to manage all of your media, provide a central database for metadata, allow remote access to your collection while also providing security and anonymity.

The stack requires a Private Internet Access subscription, a Usenet provider and Let's Encrypt certificates.

### ENVIRONMENT VARIABLES

**stack_user**: This is name of the user account that you wish to create within the container. This can be anything you choose, but ideally you would set this to match the name of the user on the host system which has access to your storage.

**user_id**: This is the User ID number of the above user account. This can be any number that isn't already in use. Ideally, you should set this to be the same ID number as the USER's ID on the host system. This will avoid permissions issues on the host system.

**deluge_group**: This is name of the group account that you wish to create within the container. This can be anything you choose, but ideally you would set this to match the name of the user's primary group on the host system.

**deluge_group_id**: This is the Group ID number of the above group. This can be any number that isn't already in use. Ideally, you should set this to be the same Group ID number as the user's primary group on the host system.

**movie_complete_dir**: /storage/downloads/complete/movie/

**music_complete_dir**: /storage/downloads/complete/music/

**tv_complete_dir**: /storage/downloads/complete/tv/

**other_complete_dir**: /storage/downloads/complete/other/

**deluge_watch_dir**: /storage/downloads/watch/deluge/

**deluge_file_backup_dir**: /storage/downloads/backup/deluge/

**deluge_incoming_dir**: /storage/downloads/incoming/deluge/

**download_complete_dir**: /storage/downloads/complete/

### VOLUME CONFIGURATION

This container requires a named volume mapped to /config/ which is where it stores the Deluge configuration, database and logs. If this isn't created as a named volume, then you risk losing your DB and config when recreating the container.

This container also requires a bind mount, in which your movies are stored, and it should be mapped to /storage/

### CREATING A CONTAINER

To create this container, download the docker-compose.yaml for my stack 'steve' and just 'up' it.
