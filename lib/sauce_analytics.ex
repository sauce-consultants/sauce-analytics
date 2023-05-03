defmodule SauceAnalytics do
  @moduledoc """
  GenServer which is responsible for managing client state and sending requests to the Analytics API.

  The plug `SauceAnalytics.Plug.MaintainSession` is required to run before any function invocations in this module
  because it depends on keys created in `Plug.Session`.

  ## Options

  * `:app_info` - `SauceAnalytics.AppInfo` which idenfies the app on the analytics API, ensure the name of the app is unique. Required.
  * `:api_url` - The URL of the Sauce Analytics API which will be used for visit and event requests. Required.
  * `:session_id_name` - The name of the key which will be used in the `Plug.Session` for storing the session's id. Defaults to `:sauce_analytics_session_id`.
  * `:revive_session_name` - The name of the key which will be used in the `Plug.Session` and `socket.assigns` for storing the `SauceAnalytics.ReviveSession` struct. Defaults to `:sauce_analytics_session_revive_info`. 
  * `:revive_session_cookie_name` - The name of the cookie used for storing the `SauceAnalytics.ReviveSession` struct. Defaults to `"sauce_analytics_session_revive_info"`.
  """
  require Logger
  use GenServer

  import Plug.Conn

  @default_opts [
    session_name: :sauce_analytics_session,
    session_cookie_name: "sauce_analytics_session"
  ]

  defmodule State do
    @moduledoc "The state of the `SauceAnalytics` GenServer"

    @keys ~w(app_info api_url session_name session_cookie_name)a
    @enforce_keys @keys
    defstruct @keys

    @type t() :: %__MODULE__{
            app_info: SauceAnalytics.AppInfo.t(),
            api_url: String.t(),
            session_name: atom(),
            session_cookie_name: String.t()
          }
  end

  @doc """
  Starts the `SauceAnalytics` GenServer with the given `opts`

  Use this in your application supervision tree.
  """
  @type opts ::
          {:session_name, atom()}
          | {:session_cookie_name, String.t()}
          | {:app_info, SauceAnalytics.AppInfo.t()}
          | {:api_url, String.t()}
  @spec start_link([opts]) :: GenServer.on_start()
  def start_link(opts) when is_list(opts),
    do: Keyword.merge(@default_opts, opts) |> Enum.into(%{}) |> do_start_link()

  defp do_start_link(%{app_info: _, api_url: _} = opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Given a `conn`, The `uid` in the store is updated with given `user_id` and
  the `uid` in `revive_session` stored in the `Plug.Session` is updated with
  the given `user_id`.

  `user_id` can be nil.
  """
  @spec assign_user(conn :: Plug.Conn.t(), user_id :: String.t() | nil) :: Plug.Conn.t()
  def assign_user(conn, user_id) do
    state = get_state()

    session =
      conn
      |> fetch_session()
      |> get_session(state.session_name)

    conn
    |> put_session(state.session_name, %{session | uid: user_id})
  end

  @doc """
  Given a `conn` or a `socket` with session information.
  A visit request is sent to the Analytics API.

  ## Example

  Originally intended for Ember, the arguments would be:
  * `name` - A full URL including route/query params (e.g. `"/list/users?sortBy=title"`)
  * `title` - A unique string to represent the route the user has visited (e.g. `"internal.list.users"`)

  However there is no concept of routes in Phoenix so this would be sufficient:
  * `name` - A full URL including query params (e.g `"/list/users?sortBy=title"`)
  * `title` - A full URL without query params (e.g `"/list/users"`)
  """
  @spec track_visit(
          conn_or_socket :: Plug.Conn.t() | Phoenix.LiveView.Socket.t(),
          name :: String.t(),
          title :: String.t()
        ) :: Plug.Conn.t() | Phoenix.LiveView.Socket.t()
  def track_visit(%module{} = conn_or_socket, name, title)
      when module in [Plug.Conn, Phoenix.LiveView.Socket] do
    state = get_state()

    session = get_analytics_session(conn_or_socket, state.session_name)
    SauceAnalytics.Store.maybe_restore_entry(session.sid)

    GenServer.cast(
      __MODULE__,
      {:visit, session, name, title}
    )

    conn_or_socket
  end

  @doc """
  Given a `conn` or a `socket` with session information.
  An event request is sent to the Analytics API.

  ## Example
  Originally intended for Ember, the arguments would be:
  * `name` - A unique string to represent the event (e.g `"users.search"`)
  * `title` -A unique string to represent the route the user has visited (e.g `"internal.list.users"`)
  * `data` - A JSON object containing any data related to the event (e.g `{"term": "John", results: [...]}`)

  However there is no concept of routes in Phoenix so this would be sufficient:
  * `name` - A unique string to represent the event (e.g `"users.search"`)
  * `title` - A full URL without query params (e.g `"/list/users"`)
  * `data` - A map with string keys containing any data related to the event (e.g `%{"term" => "John", "results" => [...]`)

  ### LiveView
  ```
  defmodule MyApp.Live.ListUsers do
    use MyApp, :live_view

    # required for any analytics calls in a LiveView
    on_mount(SauceAnalytics.Live.SetupAssigns)

    def mount(...), do: ...

    def handle_event("search", data, socket) do
      ...

      {:noreply,
      socket
      |> SauceAnalytics.track_event("/users/list", "users.list.search",
        %{"count" => length(data.results),
          "results" => data.results}
      )}
    end
  end
  ```
  """
  @spec track_event(
          conn_or_socket :: Plug.Conn.t() | Phoenix.LiveView.Socket.t(),
          name :: String.t(),
          title :: String.t(),
          data :: map() | nil
        ) :: Plug.Conn.t() | Phoenix.LiveView.Socket.t()
  def track_event(%module{} = conn_or_socket, name, title, data \\ nil)
      when module in [Plug.Conn, Phoenix.LiveView.Socket] do
    state = get_state()

    session = get_analytics_session(conn_or_socket, state.session_cookie_name, true)
    SauceAnalytics.Store.maybe_restore_entry(session.sid)

    GenServer.cast(
      __MODULE__,
      {:event, session, name, title, data}
    )

    conn_or_socket
  end

  @doc """
  Returns the state/configuration of the `SauceAnalytics` GenServer.
  """
  @spec get_state() :: State.t()
  def get_state() do
    GenServer.call(__MODULE__, {:get_state})
  end

  @impl true
  def init(opts) do
    state = %State{
      app_info: opts[:app_info],
      api_url: opts[:api_url],
      session_name: opts[:session_name],
      session_cookie_name: opts[:session_cookie_name]
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:visit, session, name, title}, state) do
    :ok = SauceAnalytics.Store.inc_sequence(session.sid, :view)

    {:ok, entry} = SauceAnalytics.Store.lookup_entry(session.sid)

    request = %SauceAnalytics.HTTP.Request{
      type: :visit,
      name: name,
      title: title,
      view_sequence: entry.view_sequence,
      event_sequence: entry.event_sequence,
      user_agent: session.user_agent,
      session_id: session.sid,
      user_id: session.uid,
      client_ip: session.client_ip,
      data: nil
    }

    http_task(state.app_info, state.api_url, request)

    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:event, %SauceAnalytics.Session{} = session, name, title, data},
        state
      ) do
    SauceAnalytics.Store.inc_sequence(session.sid, :event)

    {:ok, entry} = SauceAnalytics.Store.lookup_entry(session.sid)

    request = %SauceAnalytics.HTTP.Request{
      type: :event,
      name: name,
      title: title,
      view_sequence: entry.view_sequence,
      event_sequence: entry.event_sequence,
      user_agent: session.user_agent,
      session_id: session.sid,
      user_id: session.uid,
      data: data,
      client_ip: session.client_ip
    }

    http_task(state.app_info, state.api_url, request)

    {:noreply, state}
  end

  @impl true
  def handle_call({:get_state}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:handle_http_result, result}, state) do
    Logger.debug("Recieved response from Sauce Analytics: #{inspect(result)}")
    {:noreply, state}
  end

  defp http_task(app_info, api_url, request) do
    Task.start(fn ->
      result = SauceAnalytics.HTTP.post(app_info, api_url, request)
      GenServer.cast(__MODULE__, {:handle_http_result, result})
    end)
  end

  defp get_analytics_session(conn_or_socket, key, cookie \\ false)
  defp get_analytics_session(%Plug.Conn{} = conn, key, cookie) do
    if cookie do
      conn =
        conn
        |> fetch_cookies(signed: String.to_atom(key))

      conn.cookies[key]
    else
    conn =
      conn
      |> fetch_session()
    
      get_session(conn, key)
    end
  end

  defp get_analytics_session(%Phoenix.LiveView.Socket{} = socket, key, _cookie) do 
    socket.assigns[key]
  end
end
