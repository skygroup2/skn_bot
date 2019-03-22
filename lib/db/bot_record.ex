defmodule Skn.DB.Bot do
  require Skn.Bot.Repo
  require Logger

  def update_id() do
    keys = :mnesia.dirty_all_keys(:bot_record)
    keys = Enum.filter keys, fn x -> is_integer(x) end
    if length(keys) > 0 do
      Skn.Config.set(:bot_id_seq, Enum.max(keys))
    else
      Skn.Config.set(:bot_id_seq, 0)
    end
  end

  def gen_android_id(device) do
    :rand.seed :exs64, :os.timestamp
    id = case device do
      :ioscn ->
        UUID.uuid4()
        |> String.upcase()
      :ios ->
        UUID.uuid4()
        |> String.upcase()
      _ ->
        a = :crypto.strong_rand_bytes(8)
        a
        |> Base.encode16(case: :lower)
    end
    case Skn.DB.UUID.get({:android, id}) do
      {:ok, %{status: 1}} ->
        gen_android_id(device)
      _ ->
        case Skn.DB.UUID.update(%{id: {:android, id}, status: 1}) do
          :ok -> id
          _ -> gen_android_id(device)
        end
    end
  end

  def gen_player_name(min_len \\ 5, max_len \\ 9, mix_num \\ false, start_number\\ false) do
    is_gen_name = Skn.Config.get(:is_gen_name, true)
    if is_gen_name == true do
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
    else
      last = :ets.last(:mmorpg_names)
      first = 0
      i = Enum.random(Enum.shuffle(first..last))
      [{_, n}] = :ets.lookup(:mmorpg_names, i)
      n
    end
  end

  def gen_league_name() do
    l1 = Enum.random([3, 4, 5])
    l2 = Enum.random([1, 2])
    a1 = (Enum.map 0..l1, fn (_) -> Enum.random(97..122) end)
         |> :binary.list_to_bin
    a2 = (Enum.map 0..l2, fn (_) -> Enum.random(48..57) end)
         |> :binary.list_to_bin
    (a1 <> a2)
    |> String.capitalize
  end

  #If you are seeding random like this strong_rand_bytes is better to use
  #also this function can produce a multicast address:
  #  which is not a valid mac if you want your packets routed to dst
  def gen_mac_address2() do
    <<first :: 7, _ :: 1, mac :: 40>> = :crypto.strong_rand_bytes(6)
    mac = <<first :: 7, 0 :: 1, mac :: 40>>
    mac = (
      mac
      |> :erlang.binary_to_list
      |> Enum.map(&(Base.encode16(<<&1>>, case: :lower)))
      |> Enum.join(":"))
    case Skn.DB.UUID.get({:mac, mac}) do
      {:ok, %{status: 1}} ->
        gen_mac_address2()
      _ ->
        case Skn.DB.UUID.update(%{id: {:mac, mac}, status: 1}) do
          :ok -> mac
          _ -> gen_mac_address2()
        end
    end
  end

  def gen_uuid do
    uuid = UUID.uuid4
    case Skn.DB.UUID.get({:uuid, uuid}) do
      {:ok, %{status: 1}} ->
        gen_uuid()
      _ ->
        case Skn.DB.UUID.update(%{id: {:uuid, uuid}, status: 1}) do
          :ok -> uuid
          _ -> gen_uuid()
        end
    end
  end


  def bot_default() do
    uuid = gen_uuid()
    ts_now = System.system_time(:millisecond)
    seed = :rand.uniform(500000)
    app = Skn.Config.get(:app, "mm")
    device = Skn.Config.get(:bot_device, :android)
    if app in ["fm", "nm", "mm", "nma", "nmci", "nmca"] do
      mac = gen_mac_address2()
      hmac = cond do
        device == :androidcn or device == :androidcn18 ->
          "c248c629af1fe0a8c46b95668064c1d2952a9e91d207bc0cc3c5d584c2f7553a"
        device == :ioscn or device == :ioscn18 or device == :ios ->
          "6732911bfeee56d409a806ff136cd80596c2cf220c737f3435f2ad037952f50f"
        true ->
          # :crypto.hash(:sha256, mac) |> Base.encode16(case: :lower)
          "c248c629af1fe0a8c46b95668064c1d2952a9e91d207bc0cc3c5d584c2f7553a"
      end
      %{
        device: device,
        uuid: uuid,
        androidId: gen_android_id(device),
        mac: mac,
        macHash: hmac,
        seed: seed
      }
    else
      %{
        device: device,
        uuid: uuid,
        androidId: gen_android_id(device),
        seed: seed
      }
    end
  end

  def create(id \\ nil, config \\ nil) do
    {botid, fb} = case id do
      {:index, id1} ->
        {Skn.Config.gen_id(:bot_id_seq), id1}
      {id1, index} ->
        {id1, index}
      _ when is_integer(id) ->
        {id, id}
      _ when is_binary(id) ->
        {id, id}
      _ ->
        id1 = Skn.Config.gen_id(:bot_id_seq)
        {id1, id1}
    end
    config = if config == nil, do: bot_default(), else: config
    config = if is_integer(id), do: Map.put(config, :seed, id), else: config
    config = Map.put config, :id, botid
    obj = Skn.Bot.Repo.bot_record(id: botid, uid: fb, config: config, idx5: config[:created])
    :mnesia.dirty_write(:bot_record, obj)
    get(botid)
  end

  def get(botid) do
    case :mnesia.dirty_read(:bot_record, botid) do
      [r | _] ->
        %{
          id: Skn.Bot.Repo.bot_record(r, :id),
          config: Skn.Bot.Repo.bot_record(r, :config),
          idx5: Skn.Bot.Repo.bot_record(r, :idx5),
          idx4: Skn.Bot.Repo.bot_record(r, :idx4),
          idx3: Skn.Bot.Repo.bot_record(r, :idx3),
          idx2: Skn.Bot.Repo.bot_record(r, :idx2),
          idx1: Skn.Bot.Repo.bot_record(r, :idx1),
          uid: Skn.Bot.Repo.bot_record(r, :uid)
        }
      _ ->
        nil
    end
  end

  def delete(botid) do
    :mnesia.dirty_delete(:bot_record, botid)
  end

  def bot_get_conf!(botid) do
    case bot_get_conf(botid) do
      {:ok, config} -> config
      _ -> throw({:error, :no_exist})
    end
  end

  def bot_get_conf(botid) do
    case :mnesia.dirty_read(:bot_record, botid) do
      [r | _] ->
        {:ok, Skn.Bot.Repo.bot_record(r, :config)}
      _ ->
        # try to create it
        r = create(botid, nil)
        {:ok, r[:config]}
    end
  end

  def bot_update_conf(botid, data) do
    # remove temporary key
    data = Map.drop(
      data,
      [
        :proxy2,
        :proxy_auth2,
        :proxy,
        :proxy_auth,
        :proxy_auth_fun,
        :proxy_keep_alive,
        :eam_session,
        :code,
        :game_code,
        :eformula,
        :boot_time,
        :ah_time
      ]
    )
    case :mnesia.dirty_read(:bot_record, botid) do
      [r | _] ->
        obj = Skn.Bot.Repo.bot_record(r, config: data)
        :mnesia.dirty_write(:bot_record, obj)
      _ -> nil
    end
  end

  def list_account() do
    mh = {:bot_record2, :_, :_, {:'$1', :_}, :_, :_, :_, :_, :_}
    mg = [{:orelse, {:'==', :'$1', :google}, {:orelse, {:'==', :'$1', :facebook}, {:'==', :'$1', :apple}}}]
    mr = [:'$_']
    all = :mnesia.dirty_select(:bot_record2, [{mh, mg, mr}])
    for r <- all do
      %{
        id: Skn.Bot.Repo.bot_record(r, :id),
        config: Skn.Bot.Repo.bot_record(r, :config),
        idx5: Skn.Bot.Repo.bot_record(r, :idx5),
        idx4: Skn.Bot.Repo.bot_record(r, :idx4),
        idx3: Skn.Bot.Repo.bot_record(r, :idx3),
        idx2: Skn.Bot.Repo.bot_record(r, :idx2),
        idx1: Skn.Bot.Repo.bot_record(r, :idx1),
        uid: Skn.Bot.Repo.bot_record(r, :uid)
      }
    end
  end

  @doc """
      BOT_RECORD2 : store auction / search bot data
  """
  def bot_update_conf2(botid, data) do
    # remove temporary key
    data = Map.drop(
      data,
      [
        :proxy2,
        :proxy_auth2,
        :proxy,
        :proxy_auth,
        :proxy_auth_fun,
        :eam_session,
        :code,
        :game_code,
        :eformula,
        :boot_time,
        :ah_time
      ]
    )
    case :mnesia.dirty_read(:bot_record2, botid) do
      [r | _] ->
        obj = Skn.Bot.Repo.bot_record(r, config: data)
        :mnesia.dirty_write(:bot_record2, obj)
      _ -> nil
    end
  end

  def get_index2(fb) do
    case :mnesia.dirty_index_read(:bot_record2, fb, 4) do
      [r | _] ->
        %{
          id: Skn.Bot.Repo.bot_record(r, :id),
          config: Skn.Bot.Repo.bot_record(r, :config),
          idx5: Skn.Bot.Repo.bot_record(r, :idx5),
          idx4: Skn.Bot.Repo.bot_record(r, :idx4),
          idx3: Skn.Bot.Repo.bot_record(r, :idx3),
          idx2: Skn.Bot.Repo.bot_record(r, :idx2),
          idx1: Skn.Bot.Repo.bot_record(r, :idx1),
          uid: Skn.Bot.Repo.bot_record(r, :uid)
        }
      _ ->
        nil
    end
  end

  def create2(id \\ nil, config \\ nil) do
    {botid, fb} = case id do
      {:index, id1} ->
        {Skn.Config.gen_id(:bot_id_seq2), id1}
      {id1, index} ->
        {id1, index}
      _ when is_integer(id) ->
        {id, id}
      _ when is_binary(id) ->
        {id, id}
      _ ->
        id1 = Skn.Config.gen_id(:bot_id_seq2)
        {id1, id1}
    end
    config = if config == nil, do: bot_default(), else: config
    config = Map.put config, :id, botid
    obj = Skn.Bot.Repo.bot_record(id: botid, uid: fb, config: config, idx5: config[:created])
    :mnesia.dirty_write(:bot_record2, obj)
    get2(botid)
  end

  def get2(botid) do
    case :mnesia.dirty_read(:bot_record2, botid) do
      [r | _] ->
        %{
          id: Skn.Bot.Repo.bot_record(r, :id),
          config: Skn.Bot.Repo.bot_record(r, :config),
          idx5: Skn.Bot.Repo.bot_record(r, :idx5),
          idx4: Skn.Bot.Repo.bot_record(r, :idx4),
          idx3: Skn.Bot.Repo.bot_record(r, :idx3),
          idx2: Skn.Bot.Repo.bot_record(r, :idx2),
          idx1: Skn.Bot.Repo.bot_record(r, :idx1),
          uid: Skn.Bot.Repo.bot_record(r, :uid)
        }
      _ ->
        nil
    end
  end

  def delete2(botid) do
    :mnesia.dirty_delete(:bot_record2, botid)
  end
end