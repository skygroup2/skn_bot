defmodule RWSerializer do
    @moduledoc false
    use GenServer
    require Logger
    @name :rwserializer

    def move(from, to) do
        m = Enum.map from..to, fn x ->
            RWSerializer.read(x)
        end
        m = Enum.filter m, fn x -> is_map(x) end
        Enum.each m, fn x ->
            RWSerializer.write2({x[:id], x[:config]})
        end
        :ok
    end

    def read(id) do
        GenServer.call @name, {:read, id}, 60000
    end

    def write(data) do
        GenServer.call @name, {:write, data}, 60000
    end

    def update(id, config) do
        GenServer.call @name, {:update, id, config}, 60000
    end

    def remove(id) do
        GenServer.call @name, {:remove, id}, 60000
    end

    def delete(id) do
        GenServer.call @name, {:delete, id}, 60000
    end

    def instance() do
        GenServer.call @name, :instance, 60000
    end

    ## BOT RECORD2
    def read2(id) do
        GenServer.call @name, {:read2, id}, 60000
    end

    def write2(data) do
        GenServer.call @name, {:write2, data}, 60000
    end

    def read_index(id) do
        GenServer.call @name, {:read_index, id}, 60000
    end

    def update2(id, config) do
        GenServer.call @name, {:update2, id, config}, 60000
    end

    def remove2(id) do
        GenServer.call @name, {:remove2, id}, 60000
    end

    def delete2(id) do
        GenServer.call @name, {:delete2, id}, 60000
    end

    def start_link(args, opts \\ []) do
        GenServer.start_link(__MODULE__, args, opts ++ [name: @name])
    end

    def init(_) do
        {:ok, nil}
    end

    def handle_call({:delete, id}, _from, state) do
        try do
            data = Skn.DB.Bot.get id
            master = Skn.Config.get(:master, :farmer1@erlnode1)
            cc = if is_map(data) do
                config = Map.get data, :config
                GenServer.cast {@name, master}, {:delete, {:android, config[:androidId]}, {:mac, config[:mac]}, {:uuid, config[:uuid]}}
                config[:cc]
            else
                nil
            end
            device = Skn.Config.get(:bot_device, :android)
            c = if master == node() do
                Skn.DB.Bot.bot_default()
            else
                GenServer.call {@name, master}, :instance, 10000
            end
            Skn.DB.Bot.delete(id)
            r = Skn.DB.Bot.create(id, Map.merge(c, %{cc: cc, device: device}))
            {:reply, r, state}
        catch
        _, _ ->
            {:reply, nil, state}
        end
    end

    def handle_call({:read, id}, _from, state) do
        r = Skn.DB.Bot.get id
        {:reply, r, state}
    end

    def handle_call({:remove, id}, _from, state) do
        r = Skn.DB.Bot.get id
        Skn.DB.Bot.delete id
        {:reply, r, state}
    end

    def handle_call({:update, id, config}, _from, state) do
        Skn.DB.Bot.bot_update_conf(id, config)
        r = Skn.DB.Bot.get id
        {:reply, r, state}
    end

    def handle_call({:write, data}, _from, state) do
        try do
            master = Skn.Config.get(:master, :farmer1@erlnode1)
            {i, c} = case data do
            nil ->
                if master == node() do
                    {nil, Skn.DB.Bot.bot_default()}
                else
                    {nil, GenServer.call({@name, master}, :instance, 10000)}
                end
            {id, nil} ->
                if master == node() do
                    {id, Skn.DB.Bot.bot_default()}
                else
                    {id, GenServer.call({@name, master}, :instance, 10000)}
                end
            {id, config} ->
                {id, config}
            end
            r = Skn.DB.Bot.create(i, c)
            {:reply, r, state}
        catch
        _, _ ->
#            IO.inspect System.stacktrace()
            {:reply, nil, state}
        end
    end

    # BOT RECORD 2 API
    def handle_call({:delete2, id}, _from, state) do
        try do
            data = Skn.DB.Bot.get2 id
            master = Skn.Config.get(:master, :farmer1@erlnode1)
            cc= if is_map(data) do
                config = Map.get data, :config
                GenServer.cast {@name, master}, {:delete, {:android, config[:androidId]}, {:mac, config[:mac]}, {:uuid, config[:uuid]}}
                config[:cc]
            else
                nil
            end
            device = Skn.Config.get(:bot_device, :android)
            c = if master == node() do
                Skn.DB.Bot.bot_default()
            else
                GenServer.call {@name, master}, :instance, 10000
            end
            Skn.DB.Bot.delete2(id)
            r = Skn.DB.Bot.create2(id, Map.merge(c, %{cc: cc, device: device}))
            {:reply, r, state}
        catch
        _, _ ->
            {:reply, nil, state}
        end
    end

    def handle_call({:write2, data}, _from, state) do
        try do
            master = Skn.Config.get(:master, :farmer1@erlnode1)
            {i, c} = case data do
            nil ->
                if master == node() do
                    {nil, Skn.DB.Bot.bot_default()}
                else
                    {nil, GenServer.call({@name, master}, :instance, 10000)}
                end
            {id, nil} ->
                if master == node() do
                    {id, Skn.DB.Bot.bot_default()}
                else
                    {id, GenServer.call({@name, master}, :instance, 10000)}
                end
            {id, config} ->
                {id, config}
            end
            r = Skn.DB.Bot.create2(i, c)
            {:reply, r, state}
        catch
        _, _ ->
#            IO.inspect System.stacktrace()
            {:reply, nil, state}
        end
    end

    def handle_call({:read_index, id}, _from, state) do
        r = Skn.DB.Bot.get_index2 id
        {:reply, r, state}
    end

    def handle_call({:read2, id}, _from, state) do
        r = Skn.DB.Bot.get2 id
        {:reply, r, state}
    end

    def handle_call({:remove2, id}, _from, state) do
        r = Skn.DB.Bot.get2 id
        Skn.DB.Bot.delete2 id
        {:reply, r, state}
    end

    def handle_call({:update2, id, config}, _from, state) do
        Skn.DB.Bot.bot_update_conf2(id, config)
        r = Skn.DB.Bot.get2 id
        {:reply, r, state}
    end

    @doc """
        GEN API
    """
    def handle_call(:instance, _from, state) do
        r = Skn.DB.Bot.bot_default()
        {:reply, r, state}
    end

    def handle_cast({:delete, android, mac, uuid}, state) do
        Skn.DB.UUID.delete android
        Skn.DB.UUID.delete mac
        Skn.DB.UUID.delete uuid
        {:noreply, state}
    end

    def terminate(reason, _state) do
        Logger.debug "stop by #{inspect reason}"
        :ok
    end
end
