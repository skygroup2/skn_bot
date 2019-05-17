defmodule Skn.Bot.Repo do
  require Record
  use Ecto.Repo,
    otp_app: :skn_bot,
    adapter: Ecto.Adapters.Postgres

  @bot_record_fields [id: :nil, config: %{}, uid: nil, idx1: 0, idx2: 0, idx3: 0, idx4: 0, idx5: 0]
  Record.defrecord :bot_record, @bot_record_fields

  @uuid_record_fields [id: 0, status: 0, updated: 0]
  Record.defrecord :uuid_record, @uuid_record_fields

  def fields(x) do
    Keyword.keys x
  end

  def create_table() do
    :mnesia.create_table(:bot_record,[disc_copies: [node()], record_name: :bot_record, index: [:uid], attributes: fields(@bot_record_fields)])
    :mnesia.create_table(:bot_record2,[disc_copies: [node()], record_name: :bot_record, index: [:uid], attributes: fields(@bot_record_fields)])
    :mnesia.create_table(:uuid_record,[disc_copies: [node()], record_name: :uuid_record, attributes: fields(@uuid_record_fields)])
  end

  def create_db() do
    :ets.new(:bot_session, [:public, :set, :named_table, {:read_concurrency, true}])
  end

  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, System.get_env("DATABASE_URL"))}
  end

end

defmodule Skn.Bot.Repo.Ban do
    use Ecto.Schema
    import Ecto.Changeset
    alias Skn.Bot.Repo.Ban

    schema "bot_ban" do
      field :app,     :string
      field :node,    :string
      field :bot,     :string
      field :info,    :map

      timestamps([type: :utc_datetime_usec])
    end

    def changeset(%Ban{} = card_info, attrs) do
      card_info
      |> cast(attrs, [:app, :node, :bot, :info])
      |> validate_required([:app, :node, :bot, :info])
    end
end

defmodule Skn.Bot.Repo.Info do
  use Ecto.Schema
  import Ecto.Changeset
  alias Skn.Bot.Repo.Info

  @primary_key {:uuid, :string, []}
  schema "bot_info" do
    field :app,     :string
    field :node,    :string
    field :data,    :binary
  end

  def changeset(%Info{} = bot_record, attrs) do
    bot_record
    |> cast(attrs, [:uuid, :app, :node, :data])
    |> validate_required([:uuid, :app, :node, :data])
  end
end

defmodule Skn.Bot.SqlApi do
  alias Skn.Bot.Repo
  alias Skn.Bot.Repo.Ban
  alias Skn.Bot.Repo.Info

  def save_ban(attrs) do
    %Ban{}
    |> Ban.changeset(attrs)
    |> Repo.insert()
  end

  def save_bot(attrs) do
    %Info{}
    |> Info.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing)
  end

end

