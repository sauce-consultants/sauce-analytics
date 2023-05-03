defmodule SauceAnalyticsTest do
  use ExUnit.Case, async: true
  use Plug.Test
  import Plug.Test
  
  doctest SauceAnalytics

  describe "start_link/1" do
    test "state should be match the passed in opts" do
      app_info = %SauceAnalytics.AppInfo{
        environment: "test",
        hash: "ffffff",
        name: "SauceAnalytics Test",
        version: "0.1.0",
      }

      opts = [
        app_info: app_info,
        api_url: "http://localhost:4000",
        session_name: :session_id,
        session_cookie_name: "session_cookie"
      ]

      {:ok, _pid} = SauceAnalytics.start_link(opts)

      assert %SauceAnalytics.State{
        app_info: %SauceAnalytics.AppInfo{
          environment: "test",
          hash: "ffffff",
          name: "SauceAnalytics Test",
          version: "0.1.0",
        },
        api_url: "http://localhost:4000",
        session_name: :session_id,
        session_cookie_name: "session_cookie"
      } == :sys.get_state(SauceAnalytics)
    end

    test "state should have default values for some options if options are not provided" do
      app_info = %SauceAnalytics.AppInfo{
        environment: "test",
        hash: "ffffff",
        name: "SauceAnalytics Test",
        version: "0.1.0",
      }

      opts = [
        app_info: app_info,
        api_url: "http://localhost:4000",
      ]

      {:ok, _pid} = SauceAnalytics.start_link(opts)

      assert %SauceAnalytics.State{
        app_info: %SauceAnalytics.AppInfo{
          environment: "test",
          hash: "ffffff",
          name: "SauceAnalytics Test",
          version: "0.1.0",
         },
        api_url: "http://localhost:4000",
        session_name: :sauce_analytics_session,
        session_cookie_name: "sauce_analytics_session"
      } == :sys.get_state(SauceAnalytics)
    end

    test "should throw error if required options are not provided" do
      opts = []

      assert_raise FunctionClauseError, fn ->
        {:ok, _pid} = SauceAnalytics.start_link(opts)
      end
    end
  end

  describe "assign_user/2" do
    setup [:start_genservers, :setup_conn]

    @tag path: "/"
    test "should assign a user to a conn", context do
      conn = context[:conn]
      |> plug_maintain_session()
      |> SauceAnalytics.assign_user("1")

      session = conn
      |> fetch_session()
      |> get_session(:sauce_analytics_session)

      assert "1" == session.uid
    end

    @tag path: "/"
    test "nil user_id should unassign a user from the conn", context do
      conn = context[:conn]
      |> plug_maintain_session()
      |> SauceAnalytics.assign_user("2")

      session = conn
      |> fetch_session()
      |> get_session(:sauce_analytics_session)

      assert "2" ==  session.uid
      
      session = conn
      |> SauceAnalytics.assign_user(nil)
      |> fetch_session()
      |> get_session(:sauce_analytics_session)

      assert nil == session.uid
    end
  end

  describe "track_visit/3" do
    setup [:start_genservers, :setup_conn]

    @tag path: "/"
    test "should track a visit using a conn", context do
      conn = context[:conn]
      |> plug_maintain_session()

      SauceAnalytics.track_visit(conn, "what", "what")
      IO.inspect(MockResponse.get_resp_or_wait(), label: "response!!")
    end
  end

  defp plug_maintain_session(conn) do
    conn |> SauceAnalytics.Plug.MaintainSession.call(%{})
  end

  defp setup_conn(%{path: path}) do
    [conn: conn(:get, path) |> init_test_session(%{})]
  end

  defp start_genservers(_context) do
    app_info = %SauceAnalytics.AppInfo{
      environment: "test",
      hash: "ffffff",
      name: "SauceAnalytics Tests",
      version: "0.1.0",
    }

    opts = [
      app_info: app_info,
      api_url: "http://localhost:8081",
    ]

    start_supervised({SauceAnalytics, opts})
    start_supervised(SauceAnalytics.Store)

    :ok
  end
end
