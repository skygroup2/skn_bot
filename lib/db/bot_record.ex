defmodule Skn.DB.Bot do
  require Skn.Bot.Repo
  require Logger

  @doc """
    id   : integer
    uid  : string / integer for indexing in case check and block other robot
    config:
      - uuid_meta : list of key and type of unique [{:uuid, :uuid}, {:mac, :mac}, {:android_id, :uuid/:android}]
      - index_meta: list of key from id1 -> id3 for indexing
      - persistent_meta : list of persistent key default [:cc, :device]
  """

  def update_id() do
    keys = :mnesia.dirty_all_keys(:bot_record)
    keys = Enum.filter keys, fn x -> is_integer(x) end
    if length(keys) > 0 do
      Skn.Config.reset_id(:bot_id_seq, Enum.max(keys))
    else
      Skn.Config.reset_id(:bot_id_seq, 0)
    end
  end

  def format_android_id(device, uuid) do
    case device do
      :ios ->
        String.upcase(uuid)
      :android ->
        uuid
    end
  end

  def gen_uuid({key, :android}) do
    id = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    case Skn.DB.UUID.get({key, id}) do
      {:ok, %{status: 1}} ->
        gen_uuid({key, :android})
      _ ->
        case Skn.DB.UUID.update(%{id: {key, id}, status: 1}) do
          :ok ->
            id
          _ ->
            gen_uuid({key, :android})
        end
    end
  end

  def gen_uuid({key, :UUID}) do
    gen_uuid({key, :uuid}) |> String.upcase()
  end
  def gen_uuid({key, :uuid}) do
    uuid = UUID.uuid4()
    case Skn.DB.UUID.get({key, uuid}) do
      {:ok, %{status: 1}} ->
        gen_uuid({key, :uuid})
      _ ->
        case Skn.DB.UUID.update(%{id: {key, uuid}, status: 1}) do
          :ok ->
            uuid
          _ ->
            gen_uuid({key, :uuid})
        end
    end
  end

  def gen_uuid({key, :mac, vendors}) do
    uuid = gen_mac_by_vendor(vendors)
    case Skn.DB.UUID.get({key, uuid}) do
      {:ok, %{status: 1}} ->
        gen_uuid({key, :mac, vendors})
      _ ->
        case Skn.DB.UUID.update(%{id: {key, uuid}, status: 1}) do
          :ok ->
            uuid
          _ ->
            gen_uuid({key, :mac, vendors})
        end
    end
  end

  def gen_player_name(min_len \\ 5, max_len \\ 9, mix_num \\ false, start_number\\ false) do
    alg = Enum.random([:exs64, :exsplus, :exsp, :exs1024, :exs1024s, :exrop])
    alg_seed = {System.system_time(:millisecond), :erlang.phash2(self()), :erlang.phash2(:crypto.strong_rand_bytes(max_len))}
    :rand.seed(alg, alg_seed)
    letter_low = 97..122
    letter_up = 65..90
    digit = 48..57

    l = Enum.random(min_len..(max_len - 1))
    fc = if start_number == true do
      Enum.random(Enum.random([letter_low, letter_up, digit]))
    else
      Enum.random(Enum.random([letter_up, letter_low]))
    end
    rs = if mix_num == true, do: Enum.random([letter_low, digit]), else: letter_low
    <<fc>> <> ((Enum.map 0..l, fn (_) ->
      Enum.random(rs)
    end) |> :binary.list_to_bin)
  end

  def gen_mac_by_vendor(vendors) do
    vendors = if List.wrap(vendors) == [], do: ["8C8EF2", "8C8FE9", "5C969D", "5C97F3", "5C8D4E"], else: vendors
    Base.decode16!(String.upcase(Enum.random(vendors))) <> :crypto.strong_rand_bytes(3)
      |> :erlang.binary_to_list
      |> Enum.map(&(Base.encode16(<<&1>>, case: :lower)))
      |> Enum.join(":")
  end

  def hash_mac(device, mac) do
    case device do
      :android  ->
        "c248c629af1fe0a8c46b95668064c1d2952a9e91d207bc0cc3c5d584c2f7553a"
      :ios ->
        "6732911bfeee56d409a806ff136cd80596c2cf220c737f3435f2ad037952f50f"
      _ ->
        :crypto.hash(:sha256, mac) |> Base.encode16(case: :lower)
    end
  end


  defp init_conf(device, uuid_meta, config) do
    Enum.reduce(uuid_meta, config, fn x, acc ->
      name = elem(x, 0)
      value = gen_uuid(x)
      if name in [:androidId, :android_id] do
        Map.put(acc, name, format_android_id(device, value))
      else
        Map.put(acc, name, value)
      end
    end)
  end

  def new_conf(_id, config) do
    case config do
      %{device: device, uuid_meta: uuid_meta, persistent_meta: _} ->
        init_conf(device, uuid_meta, config)
      _ ->
        nil
    end
  end

  def create(table, id, new_config) do
    do_write_conf(table, id, new_config)
    get(table, id)
  end

  def set_index(table, id, name, value) do
    case :mnesia.dirty_read(table, id) do
      [r | _] ->
        pos = index2pos(name)
        obj = put_elem(r, pos - 1, value)
        :mnesia.dirty_write(table, obj)
        get(table, id)
      _ ->
        nil
    end
  end

  defp index2pos(name) do
    case name do
      :id1 -> 4
      :id2 -> 5
      :id3 -> 6
    end
  end

  def index_get(table, name, value) do
    pos = index2pos(name)
    :mnesia.dirty_index_read(table, value, pos)
    |> Enum.map(fn x -> to_map(x) end)
  end

  def get(table, id) do
    case :mnesia.dirty_read(table, id) do
      [r] ->
        to_map(r)
      [] ->
        nil
    end
  end

  defp to_map(r) do
    %{
      id: Skn.Bot.Repo.bot_record(r, :id),
      config: Skn.Bot.Repo.bot_record(r, :config),
      id3: Skn.Bot.Repo.bot_record(r, :id3),
      id2: Skn.Bot.Repo.bot_record(r, :id2),
      id1: Skn.Bot.Repo.bot_record(r, :id1),
    }
  end

  def delete(table, id) do
    :mnesia.dirty_delete(table, id)
  end

  def get_conf!(table, id) do
    case get_conf(table, id) do
      {:ok, config} ->
        config
      _ ->
        throw({:error, :no_exist})
    end
  end

  def get_conf(table, id) do
    do_get_conf(table, id)
  end

  def update_conf(table, id, config) do
    do_update_conf(table, id, config)
  end

  def write_conf(table, id, config) do
    do_write_conf(table, id, config)
  end

  defp get_index_from_config(config, id_name, default \\ nil) do
    index_meta = Map.get(config, :index_meta, [])
    {^id_name, id_key} = List.keyfind(index_meta, id_name, 0, {id_name, id_name})
    Map.get(config, id_key, default)
  end

  defp do_write_conf(table, id, config) do
    id = if id == nil, do: Skn.Config.gen_id(:bot_id_seq), else: id
    id1 = get_index_from_config(config, :id1, id)
    id2 = get_index_from_config(config, :id2)
    id3 = get_index_from_config(config, :id3)
    obj = Skn.Bot.Repo.bot_record(id: id, id1: id1, id2: id2, id3: id3, config: config)
    :mnesia.dirty_write(table, obj)
    id
  end

  def do_update_conf(table, id, data) do
    case :mnesia.dirty_read(table, id) do
      [r | _] ->
        id1 = get_index_from_config(data, :id1, Skn.Bot.Repo.bot_record(r, :id1))
        id2 = get_index_from_config(data, :id2, Skn.Bot.Repo.bot_record(r, :id2))
        id3 = get_index_from_config(data, :id3, Skn.Bot.Repo.bot_record(r, :id3))
        obj = Skn.Bot.Repo.bot_record(r, id1: id1, id2: id2, id3: id3, config: data)
        :mnesia.dirty_write(table, obj)
      [] ->
        id1 = get_index_from_config(data, :id1, id)
        id2 = get_index_from_config(data, :id2)
        id3 = get_index_from_config(data, :id3)
        obj = Skn.Bot.Repo.bot_record(id: id, id1: id1, id2: id2, id3: id3, config: data)
        :mnesia.dirty_write(table, obj)
    end
  end

  defp do_get_conf(table, id) do
    case :mnesia.dirty_read(table, id) do
      [r | _] ->
        {:ok, Skn.Bot.Repo.bot_record(r, :config)}
      [] ->
        nil
    end
  end

end