defmodule Pish do
  @moduledoc """
  # Pish: Programmaticable Interactive Shell

  ## Config struc

  ```elixir
  %{
    timeout: 5000,
    close_onerror: true,
    user:
      %{
        prompt: "ogin:",  # (:string | :regex)
        username: <string>
      }
    pass: nil,
      %{
        prompt: "assword:", # (:string | :regex)
        password: <string>
      }
    intents: 1,
    superuser: nil,
      %{
        prompt: ">", # (:string | :regex)
        cmd: "enable",
        pass_prompt: <string> # if nil does not wait to send `password`
        password: <string>
      }
    common: %{
      prompt: "#", # (:string | :regex)
    },
    continue: %{
      prompt: ~r/(Press|More)/, # (:string | :regex),
      key: " "
    },
    line: %{
      prompt: "\n", # (:string | :regex),
    },
    cmd_exit: "exit"
  }
  ```

  ## Command struc

  ```elixir
    %{
      prompt: <string>
          # Before send command wait for the "prompt". If nil or not set does not wait.
      until_prompt: <string>
          # After send command wait for "until_prompt" to complete data collect. If not set wait for config.common.prompt-
      match_regex: <string>
          # Expresion regular que evalúa la respuesta. Las expresiones entre paréntesis
          # permiten extraer trozos de la respuesta. El orden de los paréntesis determina el índice en el arreglo
          # a menos que se defina :map para mapear cada uno de esos índice a un nombre.
      map: <string>
          # Permite que la respuesta almacene los valores extraidos con :match_regex en índices alfanuméricos en vez
          # los índices númericos secuenciales.
      id: <string>
          # Permite que el resultado del comando se almacene en resultado[:id] en vez del índice númerico que
          # le correspondería en función del índice numerico del comando dentro del arreglo $cmds pasado a la función.
      run_if: <string>
          Permite decidir si un comando se ejecutará dependiendo de una expresión lógica con sintaxis Elixir. El <string>
          se evalúa con Code.eval_string, si da "false" se saltea. <string> permite macrosustituciones como las que están explicadas
          en "cmd" (ver abajo).
      error_regex: <string>
          # Expresión regular que permite decidir si lo que devolvió el comando es un error o no. Toda la cadena que
          # coincida será devuelta en $resultados[n]['error_message'] y en $resultados[n]['error'] vendrá el valor -1.
      error_abort: <boolean>
          # Si "error_regexp" tiene coincidencia y "error_abort" está en "true" la secuencia de ejecución de comandos se aborta
          # y se devuelve en $resultados todo lo ejecutado hasta este momento.
      cmd: "<string>"
          # Acepta macro sustituciones de la forma \#{a_b_c} donde "a" es el índice que identifica el resultado,
          # "b" es el indice de la coincidencia (ver "regexp" más abajo) si el "scope" está seteado a EXP_GLOBAL
          # o el número de línea que concidio con "regexp" si "scope" está en modo EXP_LINE. En este último caso
          # donde "b" es el número de línea, "c" es el nombre de la columna (si se utliza "map", ver adelante) o
          # índice numérico de considencia dentro de esa línea.
          # Ej1: "show cable modem {2.5.3}" -> busca la respuesta al 2do comando, la línea 5 que coincidió con el
          #      "regexp" de ese comando, y la columna con índice 3 ($resultado[2][5][3]). El comando 2do debe tener
          #      "scope" en EXP_LINE.
          # Ej2: "show cable modem {2.5.mac}" -> busca la respuesta al 2do comando, la línea 5 que coincidió con el
          #      "regexp" de ese comando, y la columna con nombre "mac" ($resultado[2][5]['mac']). El comando 2do debe tener
          #      "scope" en EXP_LINE.
          # Ej3: "show cable modem {2.*.mac}" -> igual que el anterior solo que este comando se expande a N comandos
          #      donde N es la cantidad de líneas contenidas en $resultado[2].
          # Ej4: "show cable modem {2.3}" o "show cable modem {2.mac}" -> en este caso el resultado del 2do comando tiene
          #      "scope" en EXP_GLOBAL, por ende no devuelve líneas, sino las considencias de "regexp" planas.
    }
  ```
  """

  @default_config %{
    echo_output: true,
    echo_input: false,
    timeout: 5000,
    close_onerror: true,
    user: nil,
      # %{
      #   prompt: "ogin:", (:string | :regex)
      #   username: <string>
      # }
    pass: nil,
      # %{
      #   prompt: "assword:", (:string | :regex)
      #   password: <string>
      # }
    intents: 1,
    superuser: nil,
      # %{
      #   prompt: ">", (:string | :regex)
      #   cmd: "enable",
      #   pass_prompt: <string> // if nil does not wait to send `password`
      #   password: <string>
      # }
    common: %{
      prompt: "#", # (:string | :regex)
    },
    continue: %{
      prompt: ~r/(Press|More)/, # (:string | :regex),
      key: " "
    },
    automatic_responses: nil, # can bo a list. Each item has the format of continue (%{prompt: _, key: _})
    line: %{
      prompt: "\n", # (:string | :regex),
    },
    cmd_exit: "exit"
  }

  defmodule Command do
    @enforce_keys [:cmd]
    defstruct [
      :until_prompt, #
      :prompt, #
      :match_regex, #
      :map, #
      :id, #
      :run_if, #
      :delay, #
      :timeout, #
      :error_regex, #
      :cmd, #
      nowait_prompt: false, #
      nomatch_abort: true, #
      error_abort: true #
    ]
  end

  import Pish.Helpers

  alias Porcelain.Process, as: Proc
  alias Porcelain.Result

  def open(shell_command, config \\ @default_config) do
    config = Map.merge(@default_config, config)

    # I need to save "config.echo_input" because "config" is not available when this value is required
    Process.put(:echo_input, config.echo_input)

    parent_pid = self()
    output_receiver_pid = spawn_link(fn -> receive_data(parent_pid, config) end)
    process = Porcelain.spawn_shell(shell_command, [ in: :receive, out: {:send, output_receiver_pid}, err: :out ])
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
            []
          end
      ] |> List.flatten()

      case run({process, config}, commands) do
        {:ok, _} -> {:ok, {process, config}}
        error -> error
      end

    else
      {:error, "Error opening shell!"}
    end

  end

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
              {:eval_error, e} -> {:abort, {:eval_error, e}}
              false -> {:next, accum}
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

  def send_command(conn, commands, accum) when is_list(commands), do: run(conn, commands, accum)
  def send_command({process, %{timeout: global_timeout, common: %{prompt: global_prompt}} = config} = conn, %Command{
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
                        case result  do
                          [] ->
                            nomatch_abort && {:abort, %{} } || {:next, %{} }

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
                accum[id] == nil ->
                  {next_or_abort, Map.put(accum, id, accum_item) }
                is_list(accum[id]) ->
                  {next_or_abort, Map.put(accum, id, accum[id] ++ [ accum_item ]) }
                true ->
                  {next_or_abort, Map.put(accum, id, [accum[id], accum_item ]) }
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

  def close({process, config}) do
    if (is_binary(config[:cmd_exit])) do
      send_input(process, config[:cmd_exit])
      :timer.sleep(350)
    end
    flush()
    Process.exit(config.output_receiver_pid, :normal)
    Proc.stop(process)
  end

  def alive?({process, _}), do: Proc.alive?(process)

  def last_error, do: Process.get(:last_error, "")

  def default_config, do: @default_config

  #######################################################################################################
  ## Private tools
  #######################################################################################################


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

  def apply_replaces(cmd, %{} = accum) do
    # first non wildcard replaces
    cmd = apply_replaces_simple(cmd, Regex.scan(~r/\{([^\*]+?)\}/, cmd), accum)
    # second wildcard replaces
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
    replaces = get_in(accum, [left]) |> Enum.map( &([ rpl  ,&1[right]]) )
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

  def send_input(process, inputs) when is_list(inputs) do
    inputs |> Enum.each(fn input -> send_input(process, input) end)
  end
  def send_input(process, input, newline \\ true) do
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

  def flush() do
    receive do
      {:data, _data} ->
        # if @echo_output, do: IO.write(data)
        flush()
      _ ->
        flush()
    after
      0 -> :ok
    end
  end

end
