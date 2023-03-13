defmodule SauceAnalytics.Store do
  @moduledoc """
  Session store for analytics information, uses an [ETS](https://www.erlang.org/doc/man/ets.html)
  as a backend for the data.

  ## Options

  * `:table_name` - The name of the table that the ETS will use. Defaults to `:sauce_analytic_session_table`
  * `:session_max_age` - The number of seconds before a session in the Store is considered expired. Defaults to `3600` (1 hour)
  * `:clean_interval` - The number of seconds that specify the period of time between each clean up of expired sessions. Defaults to `5400` (1.5 hours)
  """
  require Logger
  use GenServer

  @default_opts [
    table_name: :sauce_analytics_session_table,
    session_max_age: 3600,
    clean_interval: 5400
  ]

  defmodule State do
    @moduledoc "The state of the `SauceAnalytics.Store` GenServer"

    @keys ~w(table_name session_max_age clean_interval)a
    @enforce_keys @keys
    defstruct @keys

    @type t() :: %__MODULE__{
            table_name: atom(),
            session_max_age: integer(),
            clean_interval: integer()
          }
  end

  @type session() ::
          {session_id :: reference(), user_agent :: String.t(), view_sequence :: integer(),
           event_sequence :: integer(), user_id :: String.t(), last_modified :: integer()}

  @doc """
  Starts the Store GenServer with the given `opts`.

  Use this in your application supervision tree.
  """
  @type opts ::
          {:table_name, atom()} | {:session_max_age, integer()} | {:clean_interval, integer()}
  @spec start_link([opts]) :: GenServer.on_start()
  def start_link(opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a new session in the Store.
  """
  @spec new_session(session_id :: reference(), user_agent :: String.t()) :: :ok
  def new_session(session_id, user_agent) do
    GenServer.call(
      __MODULE__,
      {:new_session, session_id, user_agent}
    )
  end

  @doc """
  Returns a session in the Store.
  """
  @spec lookup_session(session_id :: reference()) ::
          {:ok, SauceAnalytics.Store.Session.t()} | {:error, :not_found}
  def(lookup_session(session_id)) do
    GenServer.call(__MODULE__, {:lookup_session, session_id})
  end

  @doc """
  Revives a previously expired and deleted session in the Store.

  Given a `SauceAnalytics.ReviveSession` struct a session can be generated which
  contains the same session_id that the client expects.
  """
  @spec revive_session(revive_session :: SauceAnalytics.ReviveSession.t()) ::
          SauceAnalytics.Store.Session.t()
  def revive_session(%SauceAnalytics.ReviveSession{} = revive_session) do
    GenServer.call(__MODULE__, {:revive_session, revive_session})
  end

  @doc """
  Returns true if a session exists in the Store, false otherwise. 
  """
  @spec session_exists?(session_id :: reference()) :: boolean()
  def session_exists?(session_id) do
    GenServer.call(__MODULE__, {:session_exists?, session_id})
  end

  @doc """
  Assigns a user to a session in the Store.
  """
  @spec assign_user(session_id :: reference(), user_id :: String.t()) ::
          :ok | {:error, :not_found}
  def assign_user(session_id, user_id) do
    GenServer.call(__MODULE__, {:assign_user, session_id, user_id})
  end

  @doc """
  Increments view_sequence or event_sequence on a session in the Store.

  `type` can either be `:view` or `:event`
  """
  @spec inc_sequence(session_id :: reference(), type :: :view | :event) ::
          :ok | {:error, :not_found}
  def inc_sequence(session_id, type) when type in [:view, :event] do
    GenServer.call(__MODULE__, {:inc_sequence, session_id, type})
  end

  @doc """
  Returns the state/configuration of the `SauceAnalytics.Store` GenServer.
  """
  @spec get_state() :: State.t()
  def get_state() do
    GenServer.call(__MODULE__, {:get_state})
  end

  @doc """
  If the session referenced in `revive_session` does not exist, the session will be revived.
  """
  @spec maybe_revive_session(revive_session :: SauceAnalytics.ReviveSession.t()) ::
          SauceAnalytics.Store.Session.t()
  def maybe_revive_session(%SauceAnalytics.ReviveSession{} = revive_session) do
    unless session_exists?(revive_session.sid) do
      revive_session(revive_session)
    end
  end

  @impl true
  def init(opts) do
    state = %State{
      table_name: opts[:table_name],
      session_max_age: opts[:session_max_age],
      clean_interval: opts[:clean_interval]
    }

    :ets.new(state.table_name, [:set, :named_table, :public])
    clean_tick(state.clean_interval)

    {:ok, state}
  end

  @impl true
  def handle_call({:new_session, session_id, user_agent}, _from, state) do
    # {session_id, user_agent, view_sequence, event_sequence, user_id, last_modified}
    :ets.insert(state.table_name, {
      session_id,
      user_agent,
      0,
      0,
      nil,
      DateTime.utc_now() |> DateTime.to_unix()
    })

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:lookup_session, session_id}, _from, state) do
    if :ets.member(state.table_name, session_id) do
      [session] = :ets.lookup(state.table_name, session_id)

      {:reply, {:ok, session_to_struct(session)}, state}
    else
      {:reply, {:error, :not_found}}
    end
  end

  @impl true
  def handle_call({:assign_user, sid, uid}, _from, state) do
    if :ets.update_element(state.table_name, sid, {5, uid}) do
      {:reply, :ok, state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:inc_sequence, session_id, type}, _from, state) do
    if :ets.member(state.table_name, session_id) do
      pos =
        case type do
          :view -> 3
          :event -> 4
        end

      :ets.update_counter(state.table_name, session_id, {pos, 1})

      {:reply, :ok, state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(
        {:revive_session, %SauceAnalytics.ReviveSession{} = session},
        _from,
        state
      ) do
    new_session =
      {session.sid, session.user_agent, 0, 0, session.uid,
       DateTime.utc_now() |> DateTime.to_unix()}

    :ets.insert(state.table_name, new_session)
    {:reply, session_to_struct(new_session), state}
  end

  @impl true
  def handle_call({:session_exists?, sid}, _from, state) do
    {:reply, :ets.member(state.table_name, sid), state}
  end

  @impl true
  def handle_info(:clean, state) do
    unix_now =
      DateTime.utc_now()
      |> DateTime.to_unix()

    q = [
      {
        {:_, :_, :_, :_, :_, :"$1"},
        [{:<, {:+, :"$1", state.session_max_age}, unix_now}],
        [true]
      }
    ]

    _total_deleted = :ets.select_delete(state.table_name, q)
    clean_tick(state.clean_interval)
    {:noreply, state}
  end

  @impl true
  def handle_call({:get_state}, _from, state) do
    {:reply, state, state}
  end

  defp clean_tick(interval_seconds) do
    Process.send_after(self(), :clean, interval_seconds * 1000)
  end

  defp session_to_struct(
         {session_id, user_agent, view_sequence, event_sequence, user_id, last_modified}
       ) do
    %SauceAnalytics.Store.Session{
      sid: session_id,
      user_agent: user_agent,
      view_sequence: view_sequence,
      event_sequence: event_sequence,
      uid: user_id,
      last_modified: last_modified
    }
  end
end
