defmodule Q3BspCauldron.BSPMonitor do
  use GenServer
  require Logger

  defstruct [:table, :known_files, :baseq3_path, :watcher_pid]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_pk3_for_bsp(name) do
    bsp_name = name <> ".bsp"

    case :ets.lookup(:bsp_to_pk3, bsp_name) do
      [{^bsp_name, pk3_file}] -> {:ok, pk3_file}
      [] -> {:error, :not_found}
    end
  end

  def list_all_bsps do
    :ets.tab2list(:bsp_to_pk3)
  end

  def force_rescan do
    GenServer.call(__MODULE__, :force_rescan)
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    baseq3_path =
      System.get_env("QUAKE3_BASEQ3_PATH") ||
        raise "QUAKE3_BASEQ3_PATH environment variable is required"

    # Create or reuse existing ETS table
    table =
      case :ets.whereis(:bsp_to_pk3) do
        :undefined -> :ets.new(:bsp_to_pk3, [:set, :public, :named_table])
        existing -> existing
      end

    state = %__MODULE__{
      table: table,
      known_files: MapSet.new(),
      baseq3_path: baseq3_path,
      watcher_pid: nil
    }

    # Do initial scan
    {:ok, state, {:continue, :initial_scan}}
  end

  @impl true
  def handle_continue(:initial_scan, state) do
    Logger.info("Starting initial BSP map scan...")
    new_state = perform_full_scan(state)

    # Start filesystem watcher
    {:ok, watcher_pid} = FileSystem.start_link(dirs: [new_state.baseq3_path])
    FileSystem.subscribe(watcher_pid)

    Logger.info("Initial scan complete. Found #{MapSet.size(new_state.known_files)} PK3 files")
    Logger.info("Filesystem watcher started for #{new_state.baseq3_path}")

    {:noreply, %{new_state | watcher_pid: watcher_pid}}
  end

  @impl true
  def handle_call(:force_rescan, _from, state) do
    Logger.info("Forcing full rescan...")
    new_state = perform_full_scan(state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info({:file_event, watcher_pid, {path, events}}, %{watcher_pid: watcher_pid} = state) do
    if is_pk3_file?(path) and not is_base_pak_file?(Path.basename(path)) do
      Logger.info("Filesystem event for #{path}: #{inspect(events)}")
      new_state = handle_file_event(path, events, state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:file_event, watcher_pid, :stop}, %{watcher_pid: watcher_pid} = state) do
    Logger.warning("Filesystem watcher stopped")
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private functions

  defp handle_file_event(path, events, state) do
    filename = Path.basename(path)

    cond do
      # File is complete and ready to be processed
      :modified in events and :closed in events ->
        Logger.info("Processing completed file: #{filename}")
        process_pk3_file(filename, state.baseq3_path, state.table)
        %{state | known_files: MapSet.put(state.known_files, filename)}

      # File was either deleted or moved
      :deleted in events or :moved_from in events ->
        Logger.info("Removing entries for deleted file: #{filename}")
        remove_pk3_entries(filename, state.table)
        %{state | known_files: MapSet.delete(state.known_files, filename)}

      # File was moved to the directory
      :moved_to in events ->
        Logger.info("Processing moved file: #{filename}")
        process_pk3_file(filename, state.baseq3_path, state.table)
        %{state | known_files: MapSet.put(state.known_files, filename)}

      true ->
        # Ignore :created, :modified (without :closed), and other events
        state
    end
  end

  defp is_pk3_file?(path) do
    String.ends_with?(String.downcase(path), ".pk3")
  end

  defp perform_full_scan(state) do
    start_time = System.monotonic_time(:millisecond)

    result =
      case list_pk3_files(state.baseq3_path) do
        {:ok, files} ->
          :ets.delete_all_objects(state.table)

          Enum.each(files, fn file ->
            process_pk3_file(file, state.baseq3_path, state.table)
          end)

          %{state | known_files: MapSet.new(files)}

        {:error, reason} ->
          Logger.error("Failed to scan directory: #{reason}")
          state
      end

    duration = System.monotonic_time(:millisecond) - start_time
    Logger.info("Full scan completed in #{duration} ms")

    result
  end

  defp list_pk3_files(baseq3_path) do
    case File.ls(baseq3_path) do
      {:ok, files} ->
        pk3_files =
          files
          |> Enum.filter(fn file -> String.ends_with?(file, ".pk3") end)
          |> Enum.reject(&is_base_pak_file?/1)

        {:ok, pk3_files}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ignore base pk3 files (pak0.pk3 to pak8.pk3)
  defp is_base_pak_file?(filename) do
    String.match?(String.downcase(filename), ~r/^pak[0-8]\.pk3$/)
  end

  defp process_pk3_file(file, baseq3_path, table) do
    full_path = Path.join(baseq3_path, file)
    charlist_path = String.to_charlist(full_path)

    case :zip.list_dir(charlist_path) do
      {:ok, file_list} ->
        file_list
        |> Enum.each(fn
          {:zip_file, path, _file_info, _extra, _compressed_size, _uncompressed_size} ->
            path_str = to_string(path)

            if String.ends_with?(path_str, ".bsp") do
              bsp_name = Path.basename(path_str)
              :ets.insert(table, {bsp_name, file})
            end

          _ ->
            :ok
        end)

      {:error, reason} ->
        Logger.error("Error reading #{file}: #{reason}")
    end
  end

  defp remove_pk3_entries(pk3_file, table) do
    entries_to_remove =
      :ets.tab2list(table)
      |> Enum.filter(fn {_bsp, pk3} -> pk3 == pk3_file end)
      |> Enum.map(fn {bsp, _pk3} -> bsp end)

    Enum.each(entries_to_remove, fn bsp ->
      :ets.delete(table, bsp)
    end)
  end
end
