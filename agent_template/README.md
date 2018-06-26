# Files

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
Template file which will have initial list of commands after installation. This file will be appended with lines similar to:

```$xslt
trafikito_uptime="uptime"
trafikito_total_ram="/usr/sbin/sysctl hw.memsize"
trafikito_df="df -hl"
```

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

