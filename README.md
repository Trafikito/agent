# Trafikito.com agent for Linux machines
POSIX agent which is running on client's machine. 

Once per minute agent get commands to execute from Trafikito API by server configuration, 
executes them on server and sends outputs back to Trafikito. 
Trafikito does all the parsing, UI and notifications related actions.

Agent can be installed anywhere on Linux machine. Default location is `/opt/trafikito` 

# Structure

>For agent details - check readme file at agent_template directory

### install.sh
This file is used only during installation. It tries to execute default commands to 
gather all basic information. Sends it to Trafikito API to get agent files + generate 
default settings for this specific server.

Installation downloads agent files, adds agent to *crontab* and removes itself.

# Security
All commands must have `trafikito_` prefix. E.g: 
- trafikito_free (alias for `free`)
- trafikito_uptime (alias for `uptime`)
- trafikito_df (alias for `df`)

To add new command first step is to edit file at `/opt/trafikito/available_commands.sh`
Location may be different if installed on custom path.