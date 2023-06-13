defmodule Skn.Bot.Sup do
  use Supervisor
  @name :skn_bot_sup

  def start_link(), do: start_link([])
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: @name)
  end

  def init(_args) do
    children = [
      Skn.Bot
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule Skn.Bot do
  @moduledoc false
  use GenServer
  require Logger
  @name :skn_bot_serializer
#  @default_metadata %{device: :android, uuid_meta: [{:uuid, :uuid}, {:androidId, :android}], persistent_meta: [:cc, :device]}

  def q_correlation_id(type, id) do
    cond do
      type == :farmer -> "FM.#{id}"
      type in [:search, :auction] -> "AH.#{id}"
      true -> "#{id}"
    end
  end

  ## BOT_RECORD : FARMER
  def read(id) do
    GenServer.call @name, {:read, :bot_record, id}, 60000
  end

  def dirty_read(id) do
    Skn.DB.Bot.get(:bot_record, id)
  end

  def dirty_index_read(idx_name, idx_val) do
    Skn.DB.Bot.index_get(:bot_record, idx_name, idx_val)
  end

  def write(data) do
    GenServer.call @name, {:write, :bot_record, data}, 60000
  end

  def dirty_write(data) do
    try do
      case data do
        {id, config} when is_map(config) ->
          Skn.DB.Bot.write_conf(:bot_record, id, config)
          Skn.DB.Bot.get(:bot_record, id)
        {id, id1, config} when is_map(config) ->
          Skn.DB.Bot.write_conf(:bot_record, id, Map.put(config, :id1, id1))
          Skn.DB.Bot.get(:bot_record, id)
        _ ->
          nil
      end
    catch
      _, _ ->
        nil
    end
  end

  def update(id, config) do
    GenServer.call @name, {:update, :bot_record, id, config}, 60000
  end

  def dirty_update(id, config) do
    Skn.DB.Bot.update_conf(:bot_record, id, config)
  end

  def dirty_set_index(id, name, value) do
    Skn.DB.Bot.set_index(:bot_record, id, name, value)
  end

  def remove(id) do
    GenServer.call @name, {:remove, :bot_record, id}, 60000
  end

  def dirty_remove(id) do
    Skn.DB.Bot.delete(:bot_record, id)
  end

  def delete(id, meta) when is_map(meta) do
    GenServer.call @name, {:delete, :bot_record, id, meta}, 60000
  end

  def add_uuid(metadata) do
    GenServer.cast(@name, {:add_uuid, metadata})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @name)
  end

  def init(_args) do
    {:ok, %{}}
  end

  def handle_call({:delete, table, id, meta}, _from, state) do
    try do
      config = Skn.DB.Bot.get(table, id)[:config]
      config = if is_map(config), do: Map.merge(config, meta), else: meta
      r =
        case config do
          %{device: device, uuid_meta: uuid_meta, persistent_meta: persistent_meta} ->
            master = Skn.Config.get(:master, :"msm@node1.skn")
            del_meta = Enum.map(uuid_meta, fn x ->
              name = elem(x, 0)
              {name, Map.get(config, name, nil)}
            end)
            meta2 = %{device: device, uuid_meta: uuid_meta, persistent_meta: persistent_meta}
            new_meta = Enum.reduce(persistent_meta, meta2, fn (x, acc) ->
              v = Map.get(config, x, nil)
              if v != nil, do: Map.put(acc, x, v), else: acc
            end)
            GenServer.cast {@name, master}, {:delete_uuid, del_meta}
            # Alloc new bot config via from master
            new_config =
              if master == node() do
                Skn.DB.Bot.new_conf(id, new_meta)
              else
                GenServer.call({@name, master}, {:instance, id, new_meta}, 10000)
              end
            # write new bot config to db
            if new_config != nil do
              Skn.DB.Bot.delete(table, id)
              Skn.DB.Bot.create(table, id, new_config)
            else
              nil
            end
          _ ->
            nil
        end
      {:reply, r, state}
    catch
      _, _ ->
        {:reply, nil, state}
    end
  end

  def handle_call({:read, table, id}, _from, state) do
    r = Skn.DB.Bot.get(table, id)
    {:reply, r, state}
  end

  def handle_call({:remove, table, id}, _from, state) do
    r = Skn.DB.Bot.get(table, id)
    Skn.DB.Bot.delete(table, id)
    {:reply, r, state}
  end

  def handle_call({:update, table, id, config}, _from, state) do
    Skn.DB.Bot.update_conf(table, id, config)
    r = Skn.DB.Bot.get(table, id)
    {:reply, r, state}
  end

  def handle_call({:write, table, data}, _from, state) do
    try do
      case data do
        {id, config} when is_map(config) ->
          Skn.DB.Bot.write_conf(table, id, config)
          r = Skn.DB.Bot.get(table, id)
          {:reply, r, state}
        {id, id1, config} when is_map(config) ->
          Skn.DB.Bot.write_conf(table, id, Map.put(config, :id1, id1))
          r = Skn.DB.Bot.get(table, id)
          {:reply, r, state}
        _ ->
          {:reply, nil, state}
      end
    catch
      _, _ ->
        # IO.inspect System.stacktrace()
        {:reply, nil, state}
    end
  end

  @doc """
  CRUD op
  """
  def handle_call({:instance, id, new_meta}, _from, state) do
    r = Skn.DB.Bot.new_conf(id, new_meta)
    {:reply, r, state}
  end

  def handle_call(msg, _from, state) do
    Logger.error("drop #{inspect msg}")
    {:reply, false, state}
  end

  def handle_cast({:add_uuid, metadata}, state) do
    Enum.each metadata, fn x ->
      Skn.DB.UUID.update(%{id: x, status: 1})
    end
    {:noreply, state}
  end

  def handle_cast({:delete_uuid, metadata}, state) do
    if Skn.Config.get(:bot_keep_uuid, true) == false do
      Enum.each metadata, fn x ->
        Skn.DB.UUID.delete(x)
      end
    end
    {:noreply, state}
  end

  def handle_cast(msg, state) do
    Logger.error("drop #{inspect msg}")
    {:noreply, state}
  end

  def handle_info(info, state) do
    Logger.error("drop #{inspect info}")
    {:noreply, state}
  end

  def code_change(_vsn, state, _extra) do
    {:ok, state}
  end

  def terminate(reason, _state) do
    Logger.debug("stop by #{inspect reason}")
    :ok
  end
end