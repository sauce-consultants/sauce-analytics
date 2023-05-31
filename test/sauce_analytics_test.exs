defmodule SauceAnalyticsTest do
  use ExUnit.Case, async: true
  use Plug.Test
  import Plug.Test
  
  doctest SauceAnalytics

  setup(context) do
    bypass = Bypass.open()

    app_info = %SauceAnalytics.AppInfo{
      environment: "test",
      hash: "ffffff",
      name: "SauceAnalytics Tests",
      version: "0.1.0",
    }

    opts = [
      app_info: app_info,
      api_url: "http://localhost:#{bypass.port}",
    ]

    opts =
      if context[:send_response] do
        pid = self()
        
        opts
        |> Keyword.put(:on_request_finish, fn resp -> send(pid, {:finish, resp}) end)
      else
        opts
      end


    unless context[:no_start] do
      start_supervised({SauceAnalytics, opts})
      start_supervised(SauceAnalytics.Store)
    end

    path =
      if context[:path] do
        context[:path]
      else
        "/"
      end
    
    {:ok, bypass: bypass, conn: conn(:get, path) |> init_test_session(%{})}
  end

  describe "start_link/1" do
    @tag :no_start
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
        session_cookie_name: "session_cookie",
        on_request_finish: &SauceAnalytics.default_on_finish/1
      } == :sys.get_state(SauceAnalytics)
    end
    
    @tag :no_start
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
        session_cookie_name: "sauce_analytics_session",
        on_request_finish: &SauceAnalytics.default_on_finish/1
      } == :sys.get_state(SauceAnalytics)
    end
    
    @tag :no_start
    test "should throw error if required options are not provided" do
      opts = []

      assert_raise FunctionClauseError, fn ->
        {:ok, _pid} = SauceAnalytics.start_link(opts)
      end
    end
  end

  describe "assign_user/2" do
    test "should assign a user to a conn", context do
      conn = context[:conn]
      |> plug_maintain_session()
      |> SauceAnalytics.assign_user("1")

      session = conn
      |> fetch_session()
      |> get_session(:sauce_analytics_session)

      assert "1" == session.uid
    end

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

  @tag :send_response
  describe "track_visit/3" do
    test "should track a visit using a conn", context do
      Bypass.expect_once(context[:bypass], "POST", "/visits", fn conn ->
        {:ok, body, _conn} = read_body(conn)
        
        conn
        |> resp(200, body)
      end)
      
      conn = context[:conn]
      |> plug_maintain_session()
      SauceAnalytics.track_visit(conn, "what", "what")

      {:ok, response} = receive do
        {:finish, resp} -> resp
      end

      {:ok, body} = Jason.decode(response.body)

      assert "ffffff" == body["appHash"]
      assert "SauceAnalytics Tests" == body["appName"]
      assert "0.1.0" == body["appVersion"]
      assert "test" == body["environment"]
      assert 1 == body["globalSequence"]
      assert "what" == body["name"]
      assert "what" == body["title"]
      assert 1 == body["viewSequence"]
    end
  end

  defp plug_maintain_session(conn) do
    conn |> SauceAnalytics.Plug.MaintainSession.call(%{})
  end
end
