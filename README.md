# Trafikito.com agent for Linux machines
POSIX agent which is running on client's machine. 

Once per minute agent get commands to execute from Trafikito API by server configuration, 
executes them on server and sends outputs back to Trafikito. 
Trafikito does all the parsing, UI and notifications related actions.

Agent can be installed anywhere on Linux machine.
Default location is `/opt/trafikito` and in what follows it is assumed that Trafikito 
is installed in the default location.

### trafikito_agent_install.sh
This file is used only during installation. It tries to execute default commands to 
gather all basic information. Sends it to Trafikito API to get agent files + generate 
default settings for this specific server.

Installation downloads agent files, configure startup method and removes itself.


# Agent

### /opt/trafikito
The Trafikito controller:

### /opt/trafikito/available_commands.sh
Template file which will have initial list of commands after installation. This file will be appended with lines similar to:

```$xslt
trafikito_uptime="uptime"
trafikito_total_ram="/usr/sbin/sysctl hw.memsize"
trafikito_df="df -hl"
```

To add a new command first step is to edit file at `/opt/trafikito/available_commands.sh`
Location may be different if installed on custom path.

All commands must have `trafikito_` prefix. E.g: 
- trafikito_free (alias for `free`)
- trafikito_uptime (alias for `uptime`)
- trafikito_df (alias for `df`)

### /opt/trafikito/etc/trafikito.cfg
The static configuration file for Trafikito.

### /opt/trafikito/etc/trafikito.app
The dynamic configuration file for Trafikito.

### /opt/trafikito/lib/trafikito_wrapper.sh
A wrapper to run the real agent /opt/trafikito/lib/trafikito_agent.sh

### /opt/trafikito/lib/trafikito_agent.sh
The real Trafikito agent.

### /opt/trafikito/var/trafikito.log
Trafikito log file.

### /opt/trafikito/var/trafikito.tmp
Temporary file used by Trafikito.

tmp/trafikito/
├── available_commands.sh
├── etc
│   └── trafikito.cfg
├── lib
│   └── trafikito_agent.sh
│   └── trafikito_wrapper.sh
├── trafikito
└── var
    trafikito.log
    trafikito.tmp

3 directories, 5 files
##### agent.sh
Main file which runs all the agent. All other files supports execution of agent.sh.

Each cycle of data collection runs once per minute. Agent calls Trafikito API with API key
and server ID. If last data was received 1+ minute ago Trafikito API responses with CSV:

```$xslt
63e374bd-92be-4275-a985-ba2b8d2a953d,trafikito_uptime,trafikito_total_ram
```

First argument is unique call token and then are commands to be executed.

Agent splits this CSV and executes each command, saves all outputs to temporary file and when all done - sends to 
Trafikito API together with call token. Trafikito backend does the rest - parse output, send notifications etc.etc.

Together with output of commands agent on each cycle sends available commands from `/opt/trafikito/available_commands.sh`

##### available_commands.sh

##### trafikito.conf
Environment configuration for agent.

- api_key
- server_id
- tmp_file
- url_output = https://api.trafikito.com/v1/agent/output
- url_get_config = https://api.trafikito.com/v1/agent/get
- random_number

All values inside pair of curly braces will be replaced during installation


##### functions/collect_available_commands.sh

On each cycle available commands from `/opt/trafikito/available_commands.sh` are sent
to Trafikito API. This is helper function to read this file.

##### functions/execute_all_commands.sh

Helper file which takes commands to run output from Trafikito API. Splits 1st argument as
`call_token` (unique for each cycle & used to save output to Trafikito) and uses all following
comma separated values as inputs for `functions/execute_trafikito_cmd.sh`

##### functions/execute_trafikito_cmd.sh

Takes one command at a time and executes. Prints output to temporary file.

##### functions/get_config_value.sh

Takes value from config file

##### functions/send_output.sh

Sends `$tmp_file` contents to Trafikito API together with `$call_token` and `$api_key` 

##### functions/set_commands_to_run.sh

Makes request to Trafikito API to get `commands_to_run`. Output may be error, so this file handles it or
it is something like this:

```$xslt
63e374bd-92be-4275-a985-ba2b8d2a953d,trafikito_uptime,trafikito_total_ram
```

##### functions/set_environment.sh

Sets some global variables:

- agent_version
- config_file
- lock_file
- api_key
- server_id
- tmp_file
- random_number
- url_output
- url_get_config

##### functions/set_os.sh

Sets some global variables:

- os
- os_codename
- os_release
- centos_flavor

