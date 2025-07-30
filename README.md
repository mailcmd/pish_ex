# Pish: Programmable Interactive Shell
Pish is a module that allow to run interactive shell processes and interact with them mimicking a
human input/output interaction. It is designed and specially useful to automatize telnet/ssh
interactive sessions with routers, switch, CMTSs, OLTs and other devices.

## How to use 
Pish has 2 main config parameters: the **configuration** itself, that say to Pish how to behave and the
**commands** that say to Pish what to send to the process, what to expect as a result and what to do
with this result. The commands can be many and will be sent in sequence. Each command can use info
obtained in the previous commands. Although the normal flow is in sequence, it is possible to has
some control by skipping commands if specific conditions are met (see `run_if` parameter).
For details see **Anex A** and **Anex B** below.

### Configuration parameter
The configuration is a map with this format:

```elixir
%{
  # Just for debug
  echo_output: false,
  echo_input: false,

  # How long to wait for a response. Default is 5 secs.
  timeout: 5000,

  # if any error happens, the process is closed and return with the data obtained until that moment.
  # You must take in account that an error can be by evaluate a command as erronous (see
  # the parameter `error_regex` in %Command{} struct) or by an unexpected problem (timeout,
  # process freezing, etc).
  # Default is true.
  close_onerror: true,

  # Useful when the process is a telnet/ssh session. Pish will wait for the string/regex in `prompt`
  # and then will send the `username` parameter. If `user` is not defined, the sending of the
  # username will be skipped. Default is nil (undefined).
  user: %{
    prompt: "ogin:",  # (string | regex)
    username: <string>
  },

  # Same as `user`, useful when the process is a telnet/ssh session. Pish will wait for string/regex 
  # in `prompt` and then will send `password` parameter. If `pass` is not defined, the sending
  # of the password will be skipped. Default is nil (undefined).
  pass: %{
    prompt: "assword:", # (string | regex)
    password: <string>
  },

  # Usually this parameter is complementary to `user` and `pass` parameters. Some devices has
  # an admin mode that you can access with a special command (in cisco routers it is usually
  #nable`). With the `superuser` parameter Pish can wait for a specific prompt and send a
  # command. Optionally Pish can wait for another prompt (`pass_prompt`) and send a password
  # if it is needed. Default is nil (undefined).
  superuser: %{
    prompt: ">", # (string | regex)
    cmd: "enable",
    pass_prompt: <string> # if nil does not wait to send `password`
    password: <string>
  },

  # This parameter define the default prompt for the complete interaction after the login process. 
  # If the command has not defined its own prompt, this common prompt will be used. 
  # Default is "#".
  common: %{
    prompt: "#", # (string | regex)
  },

  # Some interactive commands or telnet/ssh session has a pager. With the `continue` parameter
  # you could lead with it. The `prompt` parameter will allow to identify the moment when the
  # pager ask for a key press; the `key` parameter will allow simulate the key press for continue.
  continue: %{
    prompt: ~r/(Press|More)/, # (string | regex),
    key: " " # spacebar
  },

  # The Pish parser need split the data received in lines. With this parameter you can define the
  # character or a regex to identify the end of the lines. The default is "\n".
  line: %{
    prompt: "\n", # (string | regex),
  },

  # You can use this parameter when the interactive shell need a command to finalize and close
  # the process. Deault is "exit".
  cmd_exit: "exit"
}
```

### Commands parameter
The `commands` parameter can be just a %Command{} struct or a list of %Command{} structs.

```elixir
%Command{
  # Wait <integer> ms before send the command.
  delay: <integer>

  # It is possible that you need wait for a specific string/regex before send the command. If you set
  #rompt`, Pish wait for it and then will send the command. If `prompt` is nil or not defined
  # Pish does not wait and directly will send the command.
  prompt: <string | regex>,

  # If you set `until_prompt`, Pish will wait for the string|regex after send the command to complete
  # the data collect. If is nil or not defined, Pish will wait for `config.common.prompt`
  until_prompt: <string | regex>,

  # If you need send a command and are not worry about the response, you can set `nowait_prompt`
  # in `true` for Pish send the command with no capture datas and pass to the next command.
  nowait_prompt: <boolean>,

  # If set `true`, regardless of whether there is one match or several, Pish will return a list.
  # See `Anex A` below for more details.
  always_as_list: <boolean>

  # This is the regex that evaluates the response. Expressions closed by parentheses allow you
  # to extract pieces of the response. The order of the parentheses determines the index in
  # the list unless :map is defined (see below) to map each of those indexes to a key.
  # For details about pieces extraction se `Anex A` below.
  # If this parameters is not defined, the command is sent and do not wait for any specific
  # prompt, just continue with the next command.
  match_regex: <regex>,

  # If this parameter is defined as `true` and the output of the command do not match `match_regex`
  # the sequence is aborted and Pish return the data obtained until that moment. If it is `false`,
  # Pish will continue even when the response does not match with `match_regex`.
  nomatch_abort: <boolean>,

  # Allows values extracted with `match_regex` from the response to be stored as key/value pairs
  # instead of sequential numeric indexes. If not defined Pish will use ["0", "1", ..., "n"].
  map: [ key1, key2, ..., keyn ],

  # Allows the result of this command to be stored in a key determined by `id` instead
  # of the numerical index that would correspond to it based on the numerical index of the command
  # within the commands list.
  id: <any>

  # This parameter allows to decide whether a command will be executed depending on a logical
  # expression with Elixir syntax. The <string> is evaluated using `Code.eval_string` function;
  # if the eval returns ‘false’, this command will be skipped.
  # Take in account that <string> allows macro substitutions such as those explained in `cmd`
  # parameter (see below).
  run_if: <string>

  # This regex allows to determine whether the return of the command is an error or not. The entire
  # matching string will be returned in `results[index or :id][“error_message”]`, and
  #esults[index or :id][“error”]` will contain the value -1.
  error_regex: <regex>

  # You now know that if `error_regexp` has a match and `config.close_onerror` is `true` the sequence
  # is aborted and Pish return the data obtained until that moment. But if you need create an
  # exception to this behavior for one command, you can set `error_abort` in false.
  # In the same sense but inversed, you can set the default behavior like permisive
  #onfig.close_onerror set in `false`) and create an exception to this behavior setting
  #rror_abort` as `true`. By default this parameter is `true`.
  error_abort: <boolean>

  # This is a string with the command to send.
  # You can do substitutions in the command using macros of the form {a.b.c}; this reference
  # will be replaced by results[a][b][c]. For more details you can see an example below in the
  #nex B`.
  cmd: <string>
}

```

## Anex A: Match regex pieces extraction
Suppose that you have a commands parameter like this:
```elixir
[
  %Command{...},  # command index 0
  %Command{...},  # command index 1
  %Command{       # command index 2
    ...
    cmd: "get recipe 177", # just a imaginary command thar return a recipe
    match_regex: ~r/\s*([0-9]+)\s*([^ ]+).+?\n/,
    map: [ "qty", "unit" ],
    id: "recipe",
    ...
  },
  %Command{...}   # command index 3
]
```
When a sequence of commands finish, an Elixir map is returned. In this case it will be something
like this:

```elixir
%{
  0 => <map resulting of command index 0>,
  1 => <map resulting of command index 1>,
  "recipe" => <map resulting of command index 2 with id: "recipe">,
  3 => <map resulting of command index 1>,
}
```

Now suppose that the response to 3rd command (get recipe...) is the text:

```
  2 cups milk
  1 cup white sugar
  3 tablespoons cornstarch
  4 teaspoon salt
  1 teaspoon vanilla extract
  1 tablespoon butter
```

After process this response the result will be:

```elixir
%{
  "0" => <map resulting of command index 0>,
  "1" => <map resulting of command index 1>,
  "recipe" => [
    %{"qty" => "2", "unit" => "cups"},
    %{"qty" => "1", "unit" => "cup"},
    %{"qty" => "3", "unit" => "tablespoons"},
    %{"qty" => "4", "unit" => "teaspoon"},
    %{"qty" => "1", "unit" => "teaspoon"},
    %{"qty" => "1", "unit" => "tablespoon"}
  ],
  "3" => <map resulting of command index 1>,
}
```

Now suppose this commands parameters:
```elixir
[
  %Command{...},  # command index 0
  %Command{...},  # command index 1
  %Command{       # command index 2
    ...
    cmd: "get recipe 177",
    match_regex: ~r/([0-9]+)\s+([^ ]+)\s+salt/,
    map: [ "qty", "unit" ],
    id: "ammount_of_salt",
    ...
  },
  %Command{...}   # command index 3
]
```

After process the same recipe the result will be:

```elixir
%{
  "0" => <map resulting of command index 0>,
  "1" => <map resulting of command index 1>,
  "ammount_of_salt" => %{"qty" => "4", "unit" => "teaspoon"},
  "3" => <map resulting of command index 1>,
}
```

Notice how in the first case you get a list and in the second one a map. Pish, if there is more
than one match for the regex, will return a list, if not, a map. If you want that Pish always
return a list just set in the command the `always_as_list` parameter in `true`.

## Anex B: Commands and macro sustitutions

Supose you want to get the status of some process:

```elixir
iex> commands = [
  %Pish.Command{
    cmd: "/usr/bin/ps ax",
    match_regex: ~r/([0-9]+)\s+(?:.+?)\/usr\/lib\/systemd\/systemd-journald/m,
    map: [ "pid" ],
    id: "systemd"
  },
  %Pish.Command{
    cmd: "/usr/bin/head -3 /proc/{systemd.pid}/status | /usr/bin/tail -1",
    match_regex: ~r/.+:\s+(.+)/m,
    map: [ "status" ],
    id: "journald"
  }
]

iex> {:ok, conn} = Pish.open("/bin/bash -i 2>&1")
iex> Pish.run(conn, commands)
{:ok,
  %{
    "systemd" => %{"pid" => "619"},
    "journald" => %{"status" => "S (sleeping)"}
  }
}
iex> Pish.close(conn)
true
```
As you can see, `{systemd.pid}` is used in the second command to obtain the status of the process
that we first obtained  with the first command.

Now supose that you want to get the statuses of many procceses:

```elixir
iex> commands = [
  %Pish.Command{
    cmd: "/usr/bin/ps ax",
    match_regex: ~r/([0-9]+)\s+(?:.+?)\/usr\/lib\/systemd\/systemd/m,
    map: [ "pid" ],
    id: "systemd"
  },
  %Pish.Command{
    cmd: "/usr/bin/head -3 /proc/{systemd.*.pid}/status | /usr/bin/tail -1",
    match_regex: ~r/.+:\s+(.+)/m,
    map: [ "status" ],
    id: "systemd-statuses"
  }
]

iex> {:ok, conn} = Pish.open("/bin/bash -i 2>&1")
iex> Pish.run(conn, commands)
{:ok,
%{
  "systemd" => [
    %{"pid" => "1"},
    %{"pid" => "619"},
    %{"pid" => "656"},
    %{"pid" => "1211"},
    %{"pid" => "1220"},
    %{"pid" => "1884"}
  ],
  "systemd-statuses" => [
    %{"status" => "S (sleeping)"},
    %{"status" => "S (sleeping)"},
    %{"status" => "S (sleeping)"},
    %{"status" => "S (sleeping)"},
    %{"status" => "S (sleeping)"},
    %{"status" => "S (sleeping)"}
  ]
}}

iex> Pish.close(conn)
true

```

In this case we use `{systemd.*.pid}` in the second command to expand every row obtained with the
first command (more than one process) and get the status of every one of them.


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `pis_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pish_ex, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/pish_ex>.

