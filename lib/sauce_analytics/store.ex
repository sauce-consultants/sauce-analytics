defmodule SauceAnalytics.Store do
  @moduledoc """
  [ETS](https://www.erlang.org/doc/man/ets.html) store for tracking view and event sequence per user session.

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

  @type entry() ::
          {session_id :: reference(), view_sequence :: integer(),
           event_sequence :: integer(), last_modified :: integer()}

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
  Creates a new entry in the Store.
  """
  @spec new_entry(session_id :: reference()) ::
          {:ok, SauceAnalytics.Store.Entry.t()}
  def new_entry(session_id) do
    GenServer.call(
      __MODULE__,
      {:new_entry, session_id}
    )
  end

  @doc """
  Returns an entry in the Store.
  """
  @spec lookup_entry(session_id :: reference()) ::
          {:ok, SauceAnalytics.Store.Entry.t()} | {:error, :not_found}
  def lookup_entry(session_id) do
    GenServer.call(__MODULE__, {:lookup_session, session_id})
  end

  @doc """
  Returns true if an entry associated with the given session_id in the Store, false otherwise. 
  """
  @spec entry_exists?(session_id :: reference()) :: boolean()
  def entry_exists?(session_id) do
    GenServer.call(__MODULE__, {:entry_exists?, session_id})
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
  If an entry with the given session ID does not exist in the store, a new entry is created.
  """
  @spec maybe_restore_entry(session_id :: reference()) ::
          SauceAnalytics.Store.Entry.t() | nil
  def maybe_restore_entry(session_id) do
    unless entry_exists?(session_id) do
      new_entry(session_id)
    end
  end

  @doc """
  Returns the state/configuration of the `SauceAnalytics.Store` GenServer.
  """
  @spec get_state() :: State.t()
  def get_state() do
    GenServer.call(__MODULE__, {:get_state})
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
  def handle_call({:new_entry, session_id}, _from, state) do
    # {session_id, view_sequence, event_sequence, last_modified}
    entry = {session_id, 0, 0, now()}
    :ets.insert(state.table_name, entry)

    {:reply, {:ok, entry_to_struct(entry)}, state}
  end

  @impl true
  def handle_call({:lookup_session, session_id}, _from, state) do
    if entry_exists?(session_id) do
      [entry] = :ets.lookup(state.table_name, session_id)

      {:reply, {:ok, entry_to_struct(entry)}, state}
    else
      {:reply, {:error, :not_found}}
    end
  end

  @impl true
  def handle_call({:inc_sequence, session_id, type}, _from, state) do
    if :ets.member(state.table_name, session_id) do
      pos =
        case type do
          :view -> 2
          :event -> 3
        end

      :ets.update_counter(state.table_name, session_id, {pos, 1})

      {:reply, :ok, state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:entry_exists?, sid}, _from, state) do
    {:reply, :ets.member(state.table_name, sid), state}
  end

  @impl true
  def handle_info(:clean, state) do
    q = [
      {
        {:_, :_, :_, :"$1"},
        [{:<, {:+, :"$1", state.session_max_age}, now()}],
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

  defp entry_to_struct(
         {session_id, view_sequence, event_sequence, last_modified}
       ) do
    %SauceAnalytics.Store.Entry{
      sid: session_id,
      view_sequence: view_sequence,
      event_sequence: event_sequence,
      last_modified: last_modified
    }
  end

  defp now(), do: DateTime.utc_now() |> DateTime.to_unix()
end
