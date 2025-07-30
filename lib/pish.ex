defmodule Pish do
  @moduledoc """
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
    # `enable`). With the `superuser` parameter Pish can wait for a specific prompt and send a
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
    # `prompt`, Pish wait for it and then will send the command. If `prompt` is nil or not defined
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
    # results[index or :id][“error”]` will contain the value -1.
    error_regex: <regex>

    # You now know that if `error_regexp` has a match and `config.close_onerror` is `true` the sequence
    # is aborted and Pish return the data obtained until that moment. But if you need create an
    # exception to this behavior for one command, you can set `error_abort` in false.
    # In the same sense but inversed, you can set the default behavior like permisive
    # (config.close_onerror set in `false`) and create an exception to this behavior setting
    # `error_abort` as `true`. By default this parameter is `true`.
    error_abort: <boolean>

    # This is a string with the command to send.
    # You can do substitutions in the command using macros of the form {a.b.c}; this reference
    # will be replaced by results[a][b][c]. For more details you can see an example below in the
    # `Anex B`.
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
  When the running of the sequence of commands finish, an Elixir map is returned. In this case it will
  be something like this:

  ```elixir
  %{
    "0" => <map resulting of command index 0>,
    "1" => <map resulting of command index 1>,
    "recipe" => <map resulting of command index 2 with id: "recipe">,
    "3" => <map resulting of command index 1>,
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

  ## TODO

  A lot of testing and trials in various scenarios. Sorry, I don't have enough time, I'm happy as
  long as it works well for what I need it for right now.

  ## Installation

  If [available in Hex](https://hex.pm/docs/publish), the package can be installed
  by adding `pis_ex` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [
      {:pish_ex, "~> 0.2.0"}
    ]
  end
  ```

  Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
  and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
  be found at <https://hexdocs.pm/pish_ex>.

  """

  @default_config %{
    echo_output: false,
    echo_input: false,
    timeout: 5000,
    close_onerror: true,
    user: nil,
    pass: nil,
    intents: 1,
    superuser: nil,
    common: %{
      prompt: "#",
    },
    continue: %{
      prompt: ~r/(Press|More)/,
      key: " "
    },
    automatic_responses: nil, # can bo a list. Each item has the format of continue (%{prompt: _, key: _})
    line: %{
      prompt: "\n",
    },
    cmd_exit: "exit"
  }

  defmodule Command do
    @enforce_keys [:cmd]
    defstruct [
      :cmd,
      :until_prompt,
      :prompt,
      :match_regex,
      :map,
      :id,
      :run_if,
      :delay,
      :timeout,
      :error_regex,
      nowait_prompt: false,
      always_as_list: false,
      nomatch_abort: true,
      error_abort: true
    ]
  end

  @type connection() :: {process :: %Porcelain.Process{}, config :: map()}

  import Pish.Helpers

  alias Porcelain.Process, as: Proc
  alias Porcelain.Result

  ###############################################################################################
  ## Public API
  ###############################################################################################

  @doc """
  Example for open a bash interactive session:
  ```elixir
  {:ok, conn} = Pish.open("/bin/bash -i 2>&1")
  ```
  """
  @spec open(shell_command :: String.t(), config :: map())
    :: {:ok, conn :: connection()} | {:error, msg :: String.t()}
  def open(shell_command, config \\ %{}) do
    config = Map.merge(@default_config, config)

    # I need to save "config.echo_input" because "config" is not available when this value is required
    Process.put(:echo_input, config.echo_input)

    flush()
    parent_pid = self()
    output_receiver_pid = spawn_link(fn -> receive_data(parent_pid, config) end)
    process = Porcelain.spawn_shell(shell_command, [ in: :receive, out: {:send, output_receiver_pid}, err: {:send, output_receiver_pid} ])
    config = Map.put(config, :output_receiver_pid, output_receiver_pid)

    if Proc.alive?(process) do
      commands = [
          if (is_map(config[:user])) do
            %Command{
              cmd: Map.get(config[:user], :username, ""),
              prompt: Map.get(config[:user], :prompt, "ogin:"),
              nowait_prompt: true
            }
          else
            []
          end,
          if (is_map(config[:pass])) do
            %Command{
              cmd: Map.get(config[:pass], :password, ""),
              prompt: Map.get(config[:pass], :prompt, "assword:"),
              nowait_prompt: true
            }
          else
            []
          end,
          if (is_map(config[:superuser])) do
            [
              %Command{
                cmd: Map.get(config[:superuser], :cmd, "enable"),
                prompt: Map.get(config[:superuser], :prompt, ">"),
                nowait_prompt: config[:superuser][:pass_prompt] != nil
              },
              if (config[:superuser][:pass_prompt] != nil) do
                %Command{
                  cmd: Map.get(config[:superuser], :password, ""),
                  prompt: Map.get(config[:superuser], :pass_prompt, "assword:")
                }
              else
                []
              end
            ]
          else
            wait_for({process, config}, get_in(config, [:common, :prompt]), config[:timeout])
            []
          end
      ] |> List.flatten()

      case run({process, config}, commands) do
        {:ok, _} -> {:ok, {process, config}}
        error -> error
      end

    else
      Process.put(:last_error, "Error opening shell!")
      {:error, "Error opening shell!"}
    end

  end

  @doc """
  The 3rd parameter is by default a empty map; there will be stored the result of each command
  execution.
  """
  @spec run(conn :: connection(), commands :: list(%Command{}) | %Command{}, result :: map())
    :: {:ok, result :: map()} | {:error, msg :: String.t()}
  def run(conn, commands, accum \\ %{})
  def run(_, [], accum), do: {:ok, accum}
  def run({process, %{close_onerror: close_onerror} = config} = conn, [ %Command{delay: delay, run_if: run_if} = command | commands], accum) do
    if Proc.alive?(process) do

      # result :: {:process_exit, _} | {:timeout, _} | {:next, _} | {:abort, _}
      result =
          if run_if != nil do
            run? =
              try do
                elem(Code.eval_string(apply_replaces(run_if, accum)), 0)
              rescue
                e -> {:eval_error, e}
              end

            case run? do
              {:eval_error, e} ->
                {:abort, {:eval_error, e}}
              false ->
                {:next, accum}
              true ->
                if (is_integer(delay)), do: :timer.sleep(delay)
                send_command(conn, command, accum)
            end
          else
            if (is_integer(delay)), do: :timer.sleep(delay)
            send_command(conn, command, accum)
          end

      case result do
        {:process_exit, accum} ->
          close(conn)
          {:error, "Process exit on command: #{inspect(command, pretty: true)}\nAccum: #{inspect(accum, pretty: true)}"}

        {:timeout, accum} ->
          if close_onerror, do: close(conn)
          {:error, "Timeout on command: #{inspect(command, pretty: true)}\nAccum: #{inspect(accum, pretty: true)}"}

        {:abort, accum} ->
          if close_onerror, do: close(conn)
          {:error, "Abort on command: #{inspect(command, pretty: true)}\nAccum: #{inspect(accum, pretty: true)}"}

        {:nomatch_abort, accum} ->
          if close_onerror, do: close(conn)
          {:ok, accum}

        {:next, accum} ->
          run({process, config}, commands, accum)

        {:ok, accum} ->
          run({process, config}, commands, accum)

      end

    else
      close(conn)
      {:error, "Shell closed before send command: #{inspect(command, pretty: true)}"}
    end
  end

  defp send_command(conn, commands, accum) when is_list(commands), do: run(conn, commands, accum)
  defp send_command({process, %{timeout: global_timeout, common: %{prompt: global_prompt}} = config} = conn, %Command{
      cmd: cmd,
      prompt: prompt,
      until_prompt: until_prompt,
      nowait_prompt: nowait_prompt,
      timeout: timeout,
      match_regex: match_regex,
      nomatch_abort: nomatch_abort,
      error_regex: error_regex,
      error_abort: error_abort,
      id: id,
      map: map
  } = command, accum) do

    # IO.inspect({cmd, accum}, label: "CMD, ACCUM")
    cmd = apply_replaces(cmd, accum)
    if is_list(cmd) do
      # if cmd is converted to a list of cmds, we call run expanding %Command for each cmd
      run(conn, cmd |> Enum.map( &( %Command{command | cmd: &1} )), accum)
    else
      # if cmd is a string, just wait for prompt and call send_input
      wait_prompt =
        if (prompt != nil) do
          # it "wait_for" return an atom, there was some error before send the command (:process_exit or :timeout)
          wf = wait_for(conn, prompt, fnnv([timeout, global_timeout]))
          not is_atom(wf) &&  :ok || wf
        else
          :ok
        end

      if (wait_prompt == :ok) do
        send_input(process, cmd)

        if not nowait_prompt do
          case wait_for({process, config}, fnnv([until_prompt, global_prompt]), fnnv([timeout, global_timeout])) do
            # if it is an atom it was some error or problem after sending the command
            error when is_atom(error) -> ## (:process_exit or :timeout)
              { error, accum }

            # total data recollected, this is the moment of process it
            total_data ->
              id = fnnv([to_string(id), accum |> Enum.count() |> to_string]) # id is :id or next sequence number
              { next_or_abort, accum_item } = (
                  has_error? =
                      if regex?(error_regex) do
                        case { Regex.run(error_regex, total_data), error_abort } do
                          {nil, _} ->
                            :no_error

                          { match , true} ->
                            error_message = List.last(match)
                            Process.put(:last_error, error_message)
                            {:abort, {:error, error_message} }

                          { match , false} ->
                            error_message = List.last(match)
                            Process.put(:last_error, error_message)
                            {:next, {:error, error_message} }
                        end
                      else
                        :no_error
                      end

                  if has_error? == :no_error do
                      if regex?(match_regex) do
                        result = match_regex |> Regex.scan(total_data) |> Enum.map( fn ([_|t]) -> t end )
                        case result do
                          [] ->
                            # nomatch_abort && {:abort, %{} } || {:next, %{} }
                            nomatch_abort && {:nomatch_abort, [] } || {:next, %{} }

                          [ result ] ->
                            field_keys = fnnv([map, 0..(length(result)-1) |> Enum.into([])]) |> Enum.map(&to_string(&1))
                            {:next, Enum.zip(field_keys, result) |> Enum.into(%{}) }

                          [first_result | _] = results ->
                            field_keys = fnnv([map, 0..(length(first_result)-1) |> Enum.into([])]) |> Enum.map(&to_string(&1))
                            {:next, results |> Enum.map( fn res -> Enum.zip(field_keys, res)  |> Enum.into(%{}) end) }
                        end
                      else
                        {:next, total_data }
                      end
                  else
                    has_error?
                  end
              )
              cond do
                accum[id] == nil and command.always_as_list ->
                    {next_or_abort, Map.put(accum, id, List.flatten([accum_item])) }
                accum[id] == nil ->
                  {next_or_abort, Map.put(accum, id, accum_item) }
                is_list(accum[id]) ->
                  {next_or_abort, Map.put(accum, id, List.flatten(accum[id] ++ [ accum_item ])) }
                true ->
                  {next_or_abort, Map.put(accum, id, List.flatten([accum[id], accum_item ])) }
              end
          end
        else
          {:next, accum }
        end
      else
        {wait_prompt, accum}
      end
    end

  end

  @spec close(conn :: connection()) :: boolean()
  def close({process, config}) do
    if (is_binary(config[:cmd_exit])) do
      send_input(process, config[:cmd_exit])
      :timer.sleep(350)
    end
    flush()
    Process.exit(config.output_receiver_pid, :normal)
    Proc.stop(process)
  end

  #######################################################################################################
  ## Private tools
  #######################################################################################################

  # defp alive?({process, _}), do: Proc.alive?(process)

  # defp last_error, do: Process.get(:last_error, "")

  # defp default_config, do: @default_config

  defp wait_for(conn, prompt, timeout, data \\ "")
  defp wait_for({process, config} = conn, prompt, timeout, data) do
    receive do
      # Process failure
      {:exit, _} ->
        :process_exit

      :timeout ->
        :timeout

      {:data, newdata} ->
        match_automatic =
            if (is_list(config.automatic_responses)) do
              Enum.reduce_while(config.automatic_responses, false, fn (cnt,acc) ->
                String.match?(newdata, cnt.prompt) && {:halt, cnt} || {:cont, acc}
              end)
            else
              false
            end

        cond do
          (regex?(prompt) and String.match?(newdata, prompt)) ->
            data <> newdata

          (not regex?(prompt) and String.contains?(newdata, prompt)) ->
            data <> newdata

          config.continue.prompt != nil and String.match?(newdata, config.continue.prompt) ->
            send_input(process, config.continue.key, false)
            wait_for(conn, prompt, timeout, data <> newdata)

          match_automatic != false ->
            send_input(process, match_automatic.key, false)
            wait_for(conn, prompt, timeout, data <> newdata)

          true ->
            wait_for(conn, prompt, timeout, data <> newdata)
        end

      after
        timeout ->
          :timeout
    end
  end

  defp apply_replaces(cmd, %{} = accum) do
    # first, non wildcard replaces
    cmd = apply_replaces_simple(cmd, Regex.scan(~r/\{([^\*]+?)\}/, cmd), accum)
    # second, wildcard replaces
    result = apply_replaces_wildcard(cmd, Regex.scan(~r/\{(.+[\*].+?)\}/, cmd), accum)

    length(result) > 0 && result || cmd
  end
  defp apply_replaces_simple(cmd, [], _), do: cmd
  defp apply_replaces_simple(cmd, [[rpl, ptr] | tail], accum) do
    apply_replaces_simple(
      String.replace(cmd, rpl, get_in(accum, ptr |> String.split(".")), [global: true]),
      tail,
      accum
    )
  end

  defp apply_replaces_wildcard(_, [], _), do: []
  defp apply_replaces_wildcard(cmd, [[rpl, ptr] | tail], accum) do
    [ left, right ] = String.split(ptr, ".*.")
    replaces =
      case get_in(accum, [left]) do
        list when is_list(list) ->
          list |> List.flatten() |> Enum.map( &([rpl, &1[right]]) )
        _ ->
          []
      end
    apply_replaces_wildcard_h([], cmd, replaces) ++ apply_replaces_wildcard(cmd, tail, accum)
  end
  defp apply_replaces_wildcard_h(list, _, []), do: list
  defp apply_replaces_wildcard_h(list, cmd, [[rpl, ptr] | tail]) do
    apply_replaces_wildcard_h(
      list ++ [ String.replace(cmd, rpl, ptr, [global: true]) ],
      cmd,
      tail
    )
  end

  defp send_input(process, inputs) when is_list(inputs) do
    inputs |> Enum.each(fn input -> send_input(process, input) end)
  end
  defp send_input(process, input, newline \\ true) do
    inp = input <> (newline && "\n" || "")
    if Process.get(:echo_input, false), do: IO.write(inp)
    Proc.send_input(process, inp)
  end

  defp receive_data(pid, %{echo_output: echo_output} = config) do
    receive do
      {_, :data, :out, data} ->
        if echo_output, do: IO.write(data)
        send(pid, {:data, data})
        receive_data(pid, config)

      {_, :result, %Result{status: status}} ->
        if echo_output, do: IO.puts("=== END OF SHELL ===")
        send(pid, {:exit, status})
    end
  end

  defp flush() do
    receive do
      {:data, _data} ->
        # IO.write(data)
        flush()
      _ ->
        flush()
    after
      0 -> :ok
    end
  end

end
